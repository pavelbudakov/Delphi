unit RunGenerator;

{
  ‘аза 1 внешней сортировки: генераци€ отсортированных серий (run-ов).

  »сходный файл делитс€ на NumWorkers смежных, не пересекающих строки
  областей (см. ComputeRegionBoundaries).  аждую область обрабатывает
  свой поток TRunGenWorker: читает еЄ последовательными чанками,
  укладывающимис€ в собственный бюджет пам€ти, дл€ каждого чанка
  строит массив ссылок на строки (TLineRef, без копировани€ байт),
  сортирует ссылки в пам€ти и пишет строки в пор€дке сортировки во
  временный run-файл.

  “ай-брейк при равенстве первых 50 байт - по смещению строки внутри
  чанка (см. CompareLineRefs), что даЄт детерминированный результат и
  сохран€ет исходный относительный пор€док строк внутри одного чанка.
}

interface

uses
  Classes, SysUtils, ExtSortTypes, ExtSortIO;

type
  TInt64Array = array of Int64;

  TRunGenWorker = class(TThread)
  private
    FSrcFile: string;
    FStartOffset, FEndOffset: Int64;
    FTempDir: string;
    FWorkerIdx: Integer;
    FByteBuf: array of Byte;
    FIndex: array of TLineRef;
    FByteBufSize, FIndexCapacity, FOutBufSize: Integer;
    FRunFiles: TStringList;
    FFatalError: string;
    procedure WriteRun(Count: Integer; RunSeq: Integer);
  protected
    procedure Execute; override;
  public
    constructor Create(const ASrcFile: string; AStart, AEnd: Int64;
      const ATempDir: string; AWorkerIdx, ANumWorkers: Integer);
    destructor Destroy; override;
    property RunFiles: TStringList read FRunFiles;
    property FatalError: string read FFatalError;
  end;

// —троит NumRegions+1 границ [0]..[NumRegions] по файлу так, чтобы
// внутренние границы (1..NumRegions-1) приходились точно на начало
// строки (сразу после ближайшего CRLF на/после номинальной позиции).
function ComputeRegionBoundaries(const AFileName: string; NumRegions: Integer;
  AFileSize: Int64): TInt64Array;

implementation

function FindCRLFAfter(const AFileName: string; StartPos, FileSize: Int64): Int64;
var
  f: TRawFile;
  buf: array[0..4095] of Byte;
  n, i: Integer;
  pos, found: Int64;
begin
  if StartPos >= FileSize then
  begin
    Result := FileSize;
    Exit;
  end;
  found := -1;
  f := TRawFile.OpenRead(AFileName);
  try
    pos := StartPos;
    f.Seek(pos);
    while (found < 0) and (pos < FileSize) do
    begin
      n := f.Read(buf, SizeOf(buf));
      if n <= 0 then Break;
      for i := 0 to n - 2 do
        if (buf[i] = 13) and (buf[i + 1] = 10) then
        begin
          found := pos + i + 2;
          Break;
        end;
      if found < 0 then
      begin
        if n = SizeOf(buf) then
        begin
          // возможен разрыв CRLF на границе чтени€ - перечитываем последний байт
          pos := pos + n - 1;
          f.Seek(pos);
        end
        else
          pos := pos + n;
      end;
    end;
  finally
    f.Free;
  end;
  if found >= 0 then
    Result := found
  else
    Result := FileSize;
end;

function ComputeRegionBoundaries(const AFileName: string; NumRegions: Integer;
  AFileSize: Int64): TInt64Array;
var
  i: Integer;
  nominal: Int64;
begin
  SetLength(Result, NumRegions + 1);
  Result[0] := 0;
  Result[NumRegions] := AFileSize;
  for i := 1 to NumRegions - 1 do
  begin
    nominal := (AFileSize * i) div NumRegions;
    Result[i] := FindCRLFAfter(AFileName, nominal, AFileSize);
    if Result[i] < Result[i - 1] then
      Result[i] := Result[i - 1];
    if Result[i] > AFileSize then
      Result[i] := AFileSize;
  end;
end;

function FindLastCRLFInBuf(const Buf: array of Byte; Len: Integer): Integer;
var
  i: Integer;
begin
  for i := Len - 2 downto 0 do
    if (Buf[i] = 13) and (Buf[i + 1] = 10) then
    begin
      Result := i + 2;
      Exit;
    end;
  Result := 0;
end;

function ParseLines(const Buf: array of Byte; UsableLen: Integer;
  var Idx: array of TLineRef; Capacity: Integer; AllowTrailingNoCRLF: Boolean;
  out LineCount: Integer): Integer;
var
  i, lineStart: Integer;
begin
  LineCount := 0;
  lineStart := 0;
  i := 0;
  while i < UsableLen do
  begin
    if (i + 1 < UsableLen) and (Buf[i] = 13) and (Buf[i + 1] = 10) then
    begin
      if LineCount >= Capacity then
      begin
        Result := lineStart;
        Exit;
      end;
      Idx[LineCount].Offset := lineStart;
      Idx[LineCount].Len := i - lineStart;
      Inc(LineCount);
      i := i + 2;
      lineStart := i;
    end
    else
      Inc(i);
  end;
  if (lineStart < UsableLen) and AllowTrailingNoCRLF and (LineCount < Capacity) then
  begin
    Idx[LineCount].Offset := lineStart;
    Idx[LineCount].Len := UsableLen - lineStart;
    Inc(LineCount);
    lineStart := UsableLen;
  end;
  Result := lineStart;
end;

function CompareLineRefs(Buf: PByte; const A, B: TLineRef): Integer;
begin
  Result := CompareKeyBytes(Buf, A.Offset, A.Len, Buf, B.Offset, B.Len);
  if Result = 0 then
    Result := Integer(A.Offset) - Integer(B.Offset);
end;

procedure InsertionSortIndex(Buf: PByte; var Idx: array of TLineRef; Lo, Hi: Integer);
var
  i, j: Integer;
  key: TLineRef;
begin
  for i := Lo + 1 to Hi do
  begin
    key := Idx[i];
    j := i - 1;
    while (j >= Lo) and (CompareLineRefs(Buf, Idx[j], key) > 0) do
    begin
      Idx[j + 1] := Idx[j];
      Dec(j);
    end;
    Idx[j + 1] := key;
  end;
end;

procedure QuickSortIndex(Buf: PByte; var Idx: array of TLineRef; Lo, Hi: Integer);
var
  i, j, mid: Integer;
  pivot, tmp: TLineRef;
begin
  while Lo < Hi do
  begin
    if Hi - Lo < 12 then
    begin
      InsertionSortIndex(Buf, Idx, Lo, Hi);
      Exit;
    end;
    i := Lo;
    j := Hi;
    mid := (Lo + Hi) shr 1;
    if CompareLineRefs(Buf, Idx[mid], Idx[Lo]) < 0 then
    begin tmp := Idx[mid]; Idx[mid] := Idx[Lo]; Idx[Lo] := tmp; end;
    if CompareLineRefs(Buf, Idx[Hi], Idx[Lo]) < 0 then
    begin tmp := Idx[Hi]; Idx[Hi] := Idx[Lo]; Idx[Lo] := tmp; end;
    if CompareLineRefs(Buf, Idx[Hi], Idx[mid]) < 0 then
    begin tmp := Idx[Hi]; Idx[Hi] := Idx[mid]; Idx[mid] := tmp; end;
    pivot := Idx[mid];
    repeat
      while CompareLineRefs(Buf, Idx[i], pivot) < 0 do Inc(i);
      while CompareLineRefs(Buf, Idx[j], pivot) > 0 do Dec(j);
      if i <= j then
      begin
        if i <> j then
        begin
          tmp := Idx[i]; Idx[i] := Idx[j]; Idx[j] := tmp;
        end;
        Inc(i);
        Dec(j);
      end;
    until i > j;
    if j - Lo < Hi - i then
    begin
      if Lo < j then QuickSortIndex(Buf, Idx, Lo, j);
      Lo := i;
    end
    else
    begin
      if i < Hi then QuickSortIndex(Buf, Idx, i, Hi);
      Hi := j;
    end;
  end;
end;

procedure SortLineIndex(const Buf: array of Byte; var Idx: array of TLineRef; Count: Integer);
begin
  if Count > 1 then
    QuickSortIndex(@Buf[0], Idx, 0, Count - 1);
end;

{ TRunGenWorker }

constructor TRunGenWorker.Create(const ASrcFile: string; AStart, AEnd: Int64;
  const ATempDir: string; AWorkerIdx, ANumWorkers: Integer);
var
  workerBudget: Integer;
  minByteBuf: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FSrcFile := ASrcFile;
  FStartOffset := AStart;
  FEndOffset := AEnd;
  FTempDir := ATempDir;
  FWorkerIdx := AWorkerIdx;
  FRunFiles := TStringList.Create;

  workerBudget := USABLE_BUDGET div ANumWorkers;
  FOutBufSize := GEN_OUTPUT_BUF_SIZE;
  if FOutBufSize > workerBudget div 4 then
    FOutBufSize := workerBudget div 4;
  Dec(workerBudget, FOutBufSize);

  FByteBufSize := (workerBudget * 85) div 100;
  FIndexCapacity := (workerBudget - FByteBufSize) div SizeOf(TLineRef);
  if FIndexCapacity < 4 then
    FIndexCapacity := 4;

  minByteBuf := (MAX_LINE_LEN + CRLF_LEN) * 4;
  if FByteBufSize < minByteBuf then
    FByteBufSize := minByteBuf;

  SetLength(FByteBuf, FByteBufSize);
  SetLength(FIndex, FIndexCapacity);

  Resume;
end;

destructor TRunGenWorker.Destroy;
begin
  FRunFiles.Free;
  inherited;
end;

procedure TRunGenWorker.WriteRun(Count: Integer; RunSeq: Integer);
var
  fileName: string;
  writer: TBufferedLineWriter;
  i: Integer;
begin
  fileName := FTempDir + Format('run_%.3d_%.6d.tmp', [FWorkerIdx, RunSeq]);
  writer := TBufferedLineWriter.Create(fileName, FOutBufSize);
  try
    for i := 0 to Count - 1 do
      writer.WriteLine(@FByteBuf[FIndex[i].Offset], FIndex[i].Len);
  finally
    writer.Free;
  end;
  FRunFiles.Add(fileName);
end;

procedure TRunGenWorker.Execute;
var
  f: TRawFile;
  pos, chunkStart: Int64;
  toRead, bytesRead, usable, lineCount, consumed: Integer;
  runSeq: Integer;
  atEOF: Boolean;
begin
  try
    f := TRawFile.OpenRead(FSrcFile);
    try
      pos := FStartOffset;
      f.Seek(pos);
      runSeq := 0;
      while pos < FEndOffset do
      begin
        chunkStart := pos;
        toRead := FByteBufSize;
        if pos + toRead > FEndOffset then
          toRead := FEndOffset - pos;
        bytesRead := f.Read(FByteBuf[0], toRead);
        if bytesRead <= 0 then Break;

        atEOF := (chunkStart + bytesRead >= FEndOffset);

        if atEOF then
          usable := bytesRead
        else
        begin
          usable := FindLastCRLFInBuf(FByteBuf, bytesRead);
          if usable = 0 then
            raise Exception.CreateFmt(
              'Ќе найден конец строки в чанке возле смещени€ %d ' +
              '(веро€тно, строка длиннее допустимых %d символов)',
              [chunkStart, MAX_LINE_LEN]);
        end;

        consumed := ParseLines(FByteBuf, usable, FIndex, FIndexCapacity,
          atEOF and (usable = bytesRead), lineCount);

        if lineCount > 0 then
        begin
          SortLineIndex(FByteBuf, FIndex, lineCount);
          WriteRun(lineCount, runSeq);
          Inc(runSeq);
        end
        else if consumed = 0 then
          raise Exception.Create('¬нутренн€€ ошибка: чанк не дал ни одной строки');

        pos := chunkStart + consumed;
        f.Seek(pos);
      end;
    finally
      f.Free;
    end;
  except
    on E: Exception do
      FFatalError := E.Message;
  end;
end;

end.
