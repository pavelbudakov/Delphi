unit ExtSortIO;

{
  Файловый ввод-вывод на "сырых" WinAPI-вызовах (CreateFile/ReadFile/
  WriteFile/SetFilePointer), а не через TFileStream.

  Причина: у TStream/TFileStream в Delphi 7 свойства Position/Size
  имеют тип Longint (32 бита), что ограничивает работу файлами
  примерно 2 ГБ. При требовании поддержки файлов до 10 ГБ это
  недопустимо, поэтому позиционирование сделано вручную через
  SetFilePointer с раздельными младшим/старшим Longint (доступен
  в WinAPI с Windows NT/2000, есть в Windows.pas Delphi 7).
}

interface

uses
  Windows, SysUtils, ExtSortTypes;

type
  ERawFileError = class(Exception);

  TRawFile = class
  private
    FHandle: THandle;
    FFileName: string;
  public
    constructor OpenRead(const AFileName: string);
    constructor OpenCreate(const AFileName: string);
    destructor Destroy; override;
    procedure Seek(Offset: Int64);
    function GetSize: Int64;
    // возвращает число реально прочитанных байт (0 = конец файла)
    function Read(var Buf; Count: Integer): Integer;
    procedure Write(const Buf; Count: Integer);
  end;

  // Буферизованный построчный читатель CRLF-файла.
  // Возвращает указатель на текущую строку без завершающего CRLF.
  TBufferedLineReader = class
  private
    FFile: TRawFile;
    FBuf: array of Byte;
    FBufSize, FBufValid, FBufPos: Integer;
    FEOF: Boolean;
    FCurLine: array[0..MAX_LINE_LEN - 1] of Byte;
    FCurLineLen: Integer;
    FHasLine: Boolean;
    procedure FillBuffer;
    procedure AppendCurLine(SrcOffset, Count: Integer);
  public
    constructor Create(const AFileName: string; ABufSize: Integer);
    destructor Destroy; override;
    // читает следующую строку; False - строк больше нет
    function Advance: Boolean;
    function CurLinePtr: PByte;
    property CurLineLen: Integer read FCurLineLen;
    property HasLine: Boolean read FHasLine;
  end;

  // Буферизованный писатель: копит строки в буфере и сбрасывает пачками.
  TBufferedLineWriter = class
  private
    FFile: TRawFile;
    FBuf: array of Byte;
    FBufSize, FBufPos: Integer;
  public
    constructor Create(const AFileName: string; ABufSize: Integer);
    destructor Destroy; override;
    procedure WriteLine(P: PByte; Len: Integer);
    procedure Flush;
  end;

procedure ForceDirEx(const Dir: string);

implementation

{ ForceDirEx }

procedure ForceDirEx(const Dir: string);
var
  Parent: string;
begin
  if (Dir = '') or DirectoryExists(Dir) then Exit;
  Parent := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
  if (Parent <> '') and (Parent <> Dir) then
    ForceDirEx(Parent);
  CreateDirectory(PChar(Dir), nil);
end;

{ TRawFile }

constructor TRawFile.OpenRead(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FHandle := CreateFile(PChar(AFileName), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if FHandle = INVALID_HANDLE_VALUE then
    raise ERawFileError.CreateFmt('Не удалось открыть файл на чтение "%s" (код %d)',
      [AFileName, GetLastError]);
end;

constructor TRawFile.OpenCreate(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FHandle := CreateFile(PChar(AFileName), GENERIC_WRITE, 0, nil,
    CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if FHandle = INVALID_HANDLE_VALUE then
    raise ERawFileError.CreateFmt('Не удалось создать файл "%s" (код %d)',
      [AFileName, GetLastError]);
end;

destructor TRawFile.Destroy;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(FHandle);
  inherited;
end;

procedure TRawFile.Seek(Offset: Int64);
var
  lo, hi: LongInt;
begin
  lo := LongInt(Offset and $FFFFFFFF);
  hi := LongInt(Offset shr 32);
  lo := SetFilePointer(FHandle, lo, @hi, FILE_BEGIN);
  if (lo = -1) and (GetLastError <> 0) then
    raise ERawFileError.CreateFmt('Ошибка позиционирования в файле "%s" (код %d)',
      [FFileName, GetLastError]);
end;

function TRawFile.GetSize: Int64;
var
  lo, hi: DWORD;
begin
  lo := Windows.GetFileSize(FHandle, @hi);
  if (lo = $FFFFFFFF) and (GetLastError <> 0) then
    raise ERawFileError.CreateFmt('Не удалось получить размер файла "%s" (код %d)',
      [FFileName, GetLastError]);
  Result := (Int64(hi) shl 32) or Int64(lo);
end;

function TRawFile.Read(var Buf; Count: Integer): Integer;
var
  nRead: DWORD;
begin
  if not ReadFile(FHandle, Buf, Count, nRead, nil) then
    raise ERawFileError.CreateFmt('Ошибка чтения файла "%s" (код %d)',
      [FFileName, GetLastError]);
  Result := nRead;
end;

procedure TRawFile.Write(const Buf; Count: Integer);
var
  nWritten: DWORD;
begin
  if Count = 0 then Exit;
  if not WriteFile(FHandle, Buf, Count, nWritten, nil) or (Integer(nWritten) <> Count) then
    raise ERawFileError.CreateFmt('Ошибка записи файла "%s" (код %d)',
      [FFileName, GetLastError]);
end;

{ TBufferedLineReader }

constructor TBufferedLineReader.Create(const AFileName: string; ABufSize: Integer);
begin
  inherited Create;
  FFile := TRawFile.OpenRead(AFileName);
  FBufSize := ABufSize;
  SetLength(FBuf, FBufSize);
  FBufValid := 0;
  FBufPos := 0;
  FEOF := False;
  FHasLine := False;
end;

destructor TBufferedLineReader.Destroy;
begin
  FFile.Free;
  inherited;
end;

procedure TBufferedLineReader.FillBuffer;
var
  keep, nRead: Integer;
begin
  keep := FBufValid - FBufPos;
  if keep > 0 then
    Move(FBuf[FBufPos], FBuf[0], keep);
  nRead := FFile.Read(FBuf[keep], FBufSize - keep);
  FBufValid := keep + nRead;
  FBufPos := 0;
  if nRead = 0 then
    FEOF := True;
end;

procedure TBufferedLineReader.AppendCurLine(SrcOffset, Count: Integer);
begin
  if Count <= 0 then Exit;
  if FCurLineLen + Count > MAX_LINE_LEN then
    raise ERawFileError.CreateFmt(
      'Строка длиннее допустимых %d символов - нарушены исходные данные',
      [MAX_LINE_LEN]);
  Move(FBuf[SrcOffset], FCurLine[FCurLineLen], Count);
  Inc(FCurLineLen, Count);
end;

function TBufferedLineReader.Advance: Boolean;
var
  i, scanLimit: Integer;
begin
  FCurLineLen := 0;
  while True do
  begin
    if FBufPos >= FBufValid then
    begin
      if FEOF then
      begin
        if FCurLineLen > 0 then
          Break
        else
        begin
          FHasLine := False;
          Result := False;
          Exit;
        end;
      end;
      FillBuffer;
      Continue;
    end;

    scanLimit := FBufValid;
    if (not FEOF) and (FBuf[FBufValid - 1] = 13) then
      Dec(scanLimit);

    i := FBufPos;
    while i < scanLimit do
    begin
      if (i + 1 < FBufValid) and (FBuf[i] = 13) and (FBuf[i + 1] = 10) then
      begin
        AppendCurLine(FBufPos, i - FBufPos);
        FBufPos := i + 2;
        FHasLine := True;
        Result := True;
        Exit;
      end;
      Inc(i);
    end;

    AppendCurLine(FBufPos, i - FBufPos);
    FBufPos := i;
    // Если это EOF и буфер физически исчерпан - строк больше нет, останов.
    // Иначе (в т.ч. когда FBufPos < FBufValid из-за "зарезервированного"
    // хвостового CR, см. scanLimit выше) нужно дочитать данные - без этого
    // цикл никогда не продвинется дальше и зависнет.
    if FEOF and (FBufPos >= FBufValid) then
      Break
    else
      FillBuffer;
  end;
  FHasLine := FCurLineLen > 0;
  Result := FHasLine;
end;

function TBufferedLineReader.CurLinePtr: PByte;
begin
  Result := @FCurLine[0];
end;

{ TBufferedLineWriter }

constructor TBufferedLineWriter.Create(const AFileName: string; ABufSize: Integer);
begin
  inherited Create;
  FFile := TRawFile.OpenCreate(AFileName);
  FBufSize := ABufSize;
  SetLength(FBuf, FBufSize);
  FBufPos := 0;
end;

destructor TBufferedLineWriter.Destroy;
begin
  Flush;
  FFile.Free;
  inherited;
end;

procedure TBufferedLineWriter.Flush;
begin
  if FBufPos > 0 then
  begin
    FFile.Write(FBuf[0], FBufPos);
    FBufPos := 0;
  end;
end;

procedure TBufferedLineWriter.WriteLine(P: PByte; Len: Integer);
const
  CRLFBytes: array[0..1] of Byte = (13, 10);
begin
  if FBufPos + Len + CRLF_LEN > FBufSize then
    Flush;
  if Len + CRLF_LEN > FBufSize then
  begin
    // строка (с учётом CRLF) больше буфера целиком - пишем напрямую
    FFile.Write(P^, Len);
    FFile.Write(CRLFBytes, 2);
    Exit;
  end;
  Move(P^, FBuf[FBufPos], Len);
  Inc(FBufPos, Len);
  FBuf[FBufPos] := 13; Inc(FBufPos);
  FBuf[FBufPos] := 10; Inc(FBufPos);
end;

end.
