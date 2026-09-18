unit KWayMerger;

{
  K-путевое сли€ние отсортированных run-файлов в один файл через
  бинарную min-кучу по головным строкам каждого потока.

  ѕор€док элементов массива RunFiles, переданного в TKWayMerger.Create,
  об€зан совпадать с исходным пор€дком run-ов в файле (см. RunGenerator
  и TExternalSorter) - при равенстве первых 50 байт тай-брейк идЄт по
  индексу в этом массиве (Less), что сохран€ет исходный пор€док строк.

  TMergeWorker - поток-обЄртка над TKWayMerger дл€ параллельного
  сли€ни€ независимых групп run-ов на фазе 2.
}

interface

uses
  Classes, SysUtils, ExtSortTypes, ExtSortIO;

type
  TKWayMerger = class
  private
    FReaders: array of TBufferedLineReader;
    FHeap: array of Integer;
    FHeapCount: Integer;
    function Less(a, b: Integer): Boolean;
    procedure Swap(i, j: Integer);
    procedure SiftUp(i: Integer);
    procedure SiftDown(i: Integer);
  public
    constructor Create(const RunFiles: array of string; InputBufSize: Integer);
    destructor Destroy; override;
    procedure MergeTo(const OutFileName: string; OutputBufSize: Integer);
  end;

  TMergeWorker = class(TThread)
  private
    FRunFiles: TStringList; // владеет списком, освобождает сам
    FOutFile: string;
    FInputBufSize, FOutputBufSize: Integer;
    FFatalError: string;
  protected
    procedure Execute; override;
  public
    constructor Create(ARunFiles: TStringList; const AOutFile: string;
      AInputBufSize, AOutputBufSize: Integer);
    destructor Destroy; override;
    property OutFile: string read FOutFile;
    property FatalError: string read FFatalError;
  end;

implementation

{ TKWayMerger }

constructor TKWayMerger.Create(const RunFiles: array of string; InputBufSize: Integer);
var
  i: Integer;
begin
  inherited Create;
  SetLength(FReaders, Length(RunFiles));
  SetLength(FHeap, Length(RunFiles));
  FHeapCount := 0;
  for i := 0 to Length(RunFiles) - 1 do
  begin
    FReaders[i] := TBufferedLineReader.Create(RunFiles[i], InputBufSize);
    if FReaders[i].Advance then
    begin
      FHeap[FHeapCount] := i;
      Inc(FHeapCount);
      SiftUp(FHeapCount - 1);
    end;
  end;
end;

destructor TKWayMerger.Destroy;
var
  i: Integer;
begin
  for i := 0 to Length(FReaders) - 1 do
    FReaders[i].Free;
  inherited;
end;

function TKWayMerger.Less(a, b: Integer): Boolean;
var
  c: Integer;
begin
  c := CompareKeyBytes(FReaders[a].CurLinePtr, 0, FReaders[a].CurLineLen,
                        FReaders[b].CurLinePtr, 0, FReaders[b].CurLineLen);
  if c <> 0 then
    Result := c < 0
  else
    Result := a < b;
end;

procedure TKWayMerger.Swap(i, j: Integer);
var
  tmp: Integer;
begin
  tmp := FHeap[i];
  FHeap[i] := FHeap[j];
  FHeap[j] := tmp;
end;

procedure TKWayMerger.SiftUp(i: Integer);
var
  parent: Integer;
begin
  while i > 0 do
  begin
    parent := (i - 1) shr 1;
    if Less(FHeap[i], FHeap[parent]) then
    begin
      Swap(i, parent);
      i := parent;
    end
    else
      Break;
  end;
end;

procedure TKWayMerger.SiftDown(i: Integer);
var
  l, r, smallest: Integer;
begin
  while True do
  begin
    l := i * 2 + 1;
    r := i * 2 + 2;
    smallest := i;
    if (l < FHeapCount) and Less(FHeap[l], FHeap[smallest]) then
      smallest := l;
    if (r < FHeapCount) and Less(FHeap[r], FHeap[smallest]) then
      smallest := r;
    if smallest = i then Break;
    Swap(i, smallest);
    i := smallest;
  end;
end;

procedure TKWayMerger.MergeTo(const OutFileName: string; OutputBufSize: Integer);
var
  writer: TBufferedLineWriter;
  top: Integer;
begin
  writer := TBufferedLineWriter.Create(OutFileName, OutputBufSize);
  try
    while FHeapCount > 0 do
    begin
      top := FHeap[0];
      writer.WriteLine(FReaders[top].CurLinePtr, FReaders[top].CurLineLen);
      if FReaders[top].Advance then
        SiftDown(0)
      else
      begin
        FHeap[0] := FHeap[FHeapCount - 1];
        Dec(FHeapCount);
        if FHeapCount > 0 then
          SiftDown(0);
      end;
    end;
  finally
    writer.Free;
  end;
end;

{ TMergeWorker }

constructor TMergeWorker.Create(ARunFiles: TStringList; const AOutFile: string;
  AInputBufSize, AOutputBufSize: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FRunFiles := ARunFiles;
  FOutFile := AOutFile;
  FInputBufSize := AInputBufSize;
  FOutputBufSize := AOutputBufSize;
  Resume;
end;

destructor TMergeWorker.Destroy;
begin
  FRunFiles.Free;
  inherited;
end;

procedure TMergeWorker.Execute;
var
  merger: TKWayMerger;
  arr: array of string;
  i: Integer;
begin
  try
    SetLength(arr, FRunFiles.Count);
    for i := 0 to FRunFiles.Count - 1 do
      arr[i] := FRunFiles[i];
    merger := TKWayMerger.Create(arr, FInputBufSize);
    try
      merger.MergeTo(FOutFile, FOutputBufSize);
    finally
      merger.Free;
    end;
  except
    on E: Exception do
      FFatalError := E.Message;
  end;
end;

end.
