unit ServerMain;

interface

uses
  Windows, SysUtils, Classes, SharedMemProtocol;

type
  // Блок данных, помещаемый в очередь потока приёма
  PDataBlock = ^TDataBlock;
  TDataBlock = record
    Data: Pointer;
    Size: Integer;
    Flags: Integer;
  end;

  // Поток-приёмник для одного файла
  TReceiveThread = class(TThread)
  private
    FFileStream: TFileStream;
    FFileName: string;
    FFileID: Integer;
    FLastError: Integer;
    FDataQueue: TThreadList; // список блоков данных (указателей на память)
    FFinished: Boolean;
    function GetQueueCount: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AFileID: Integer; const AFileName: string);
    destructor Destroy; override;
    procedure AddData(Data: Pointer; Size: Integer; Flags: Integer);
    property LastError: Integer read FLastError;
    property Finished: Boolean read FFinished;
  end;

  // Главный класс сервера
  TSharedMemoryServer = class
  private
    FMapping: THandle;
    FSharedMem: PSharedMemoryLayout;
    FSlotEventsC2S: array[0..SLOT_COUNT - 1] of THandle;
    FSlotEventsS2C: array[0..SLOT_COUNT - 1] of THandle;
    FSlotMutexes: array[0..SLOT_COUNT - 1] of THandle;
    FReceiveThreads: TThreadList; // список активных TReceiveThread
    FStopRequested: Boolean;
    function CreateReceiveThread(FileID: Integer; const FileName: string): TReceiveThread;
    procedure CleanupSyncObjects;
    procedure CleanupMapping;
    procedure CreateSyncObjects;
    procedure DispatcherLoop;
    function FindReceiveThread(FileID: Integer): TReceiveThread;
    function FindOrCreateReceiveThread(FileID: Integer; const FileName: string): TReceiveThread;
    procedure RemoveFinishedThreads;
    procedure ProcessSlotData(SlotIndex: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Initialize: Boolean;
    procedure Run;
    procedure Stop;
  end;

implementation

{ TReceiveThread }

constructor TReceiveThread.Create(AFileID: Integer; const AFileName: string);
begin
  inherited Create(False); // сразу запускаем
  FFileID := AFileID;
  FFileName := AFileName;
  FLastError := 0;
  FFinished := False;
  FDataQueue := TThreadList.Create;
  FreeOnTerminate := False;
end;

destructor TReceiveThread.Destroy;
begin
  FDataQueue.Free;
  inherited Destroy;
end;

function TReceiveThread.GetQueueCount: Integer;
var
  List: TList;
begin
  List := FDataQueue.LockList;
  try
    Result := List.Count;
  finally
    FDataQueue.UnlockList;
  end;
end;

procedure TReceiveThread.AddData(Data: Pointer; Size: Integer; Flags: Integer);
var
  Block: PDataBlock;
begin
  // Выделяем память под блок и копируем данные
  New(Block);
  Block.Data := GetMemory(Size);
  Move(Data^, Block.Data^, Size);
  Block.Size := Size;
  Block.Flags := Flags;
  FDataQueue.Add(Block);
end;

procedure TReceiveThread.Execute;
var
  List: TList;
  Block: PDataBlock;
  NeedClose: Boolean;
begin
  try
    // Ожидаем появления данных в очереди
    while not Terminated do begin
      // Проверяем очередь
      if GetQueueCount > 0 then begin
        List := FDataQueue.LockList;
        try
          Block := PDataBlock(List.First);
          List.Delete(0);
        finally
          FDataQueue.UnlockList;
        end;

        if Assigned(Block) then begin
          try
            // Если файл ещё не открыт, открываем
            if FFileStream = nil then begin
              try
                FFileStream := TFileStream.Create(FFileName, fmCreate or fmShareDenyWrite);
              except
                on E: Exception do begin
                  FLastError := GetLastError; // или код ошибки
                  // Прерываем обработку, сообщаем об ошибке
                  Terminate;
                  Break;
                end;
              end;
            end;

            // Записываем данные
            if Assigned(FFileStream) then begin
              FFileStream.WriteBuffer(Block.Data^, Block.Size);
            end;

            // Проверяем флаг конца файла
            NeedClose := (Block.Flags and 1) <> 0;
          finally
            FreeMem(Block.Data, Block.Size);
            Dispose(Block);
          end;

          if NeedClose then begin
            // Закрываем файл и завершаем поток
            if Assigned(FFileStream) then begin
              FreeAndNil(FFileStream);
            end;
            FFinished := True;
            Break;
          end;
        end;
      end else begin
        // Нет данных, небольшая пауза
        Sleep(10);
      end;
    end;
  except
    on E: Exception do begin
      FLastError := GetLastError;
      if FLastError = 0
        then FLastError := ERROR_WRITE_FAULT;
    end;
  end;
end;

{ TSharedMemoryServer }

constructor TSharedMemoryServer.Create;
begin
  inherited;
  FMapping := 0;
  FSharedMem := nil;
  FReceiveThreads := TThreadList.Create;
  FStopRequested := False;
end;

destructor TSharedMemoryServer.Destroy;
begin
  Stop;
  CleanupSyncObjects;
  CleanupMapping;
  FReceiveThreads.Free;
  inherited Destroy;
end;

function TSharedMemoryServer.CreateReceiveThread(FileID: Integer; const FileName: string): TReceiveThread;
begin
  Result := TReceiveThread.Create(FileID, FileName);
  FReceiveThreads.Add(Result);
end;

procedure TSharedMemoryServer.CleanupSyncObjects;
var
  i: Integer;
begin
  for i := 0 to Pred(SLOT_COUNT) do begin
    if FSlotEventsC2S[i] <> 0
      then CloseHandle(FSlotEventsC2S[i]);
    if FSlotEventsS2C[i] <> 0
      then CloseHandle(FSlotEventsS2C[i]);
    if FSlotMutexes[i] <> 0
      then CloseHandle(FSlotMutexes[i]);
  end;
end;

procedure TSharedMemoryServer.CleanupMapping;
begin
  if FSharedMem <> nil then begin
    UnmapViewOfFile(FSharedMem);
    FSharedMem := nil;
  end;
  if FMapping <> 0 then begin
    CloseHandle(FMapping);
    FMapping := 0;
  end;
end;

procedure TSharedMemoryServer.CreateSyncObjects;
var
  i: Integer;
begin
  for i := 0 to Pred(SLOT_COUNT) do begin
    FSlotEventsC2S[i] := CreateEvent(nil, False, False, PChar(GetSlotEventName(True, i)));
    FSlotEventsS2C[i] := CreateEvent(nil, False, False, PChar(GetSlotEventName(False, i)));
    FSlotMutexes[i] := CreateMutex(nil, False, PChar(GetSlotMutexName(i)));
    if (FSlotEventsC2S[i] = 0) or (FSlotEventsS2C[i] = 0) or (FSlotMutexes[i] = 0) then
      raise Exception.Create('Не удалось создать синхронизирующие объекты');
  end;
end;

function TSharedMemoryServer.Initialize: Boolean;
var
  i: Integer;
begin
  Result := False;
  try
    // Создание разделяемой памяти
    FMapping := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, SHM_SIZE, SHM_NAME);
    if FMapping = 0 then
      raise Exception.Create('Не удалось создать разделяемую память');

    FSharedMem := MapViewOfFile(FMapping, FILE_MAP_ALL_ACCESS, 0, 0, SHM_SIZE);
    if FSharedMem = nil then
      raise Exception.Create('Не удалось отобразить разделяемую память');

    // Инициализация заголовка
    FSharedMem.Magic := $12345678;
    FSharedMem.Version := 1;
    FSharedMem.SlotCount := SLOT_COUNT;
    FSharedMem.SlotDataSize := SLOT_DATA_SIZE;

    // Инициализация слотов
    for i := 0 to Pred(SLOT_COUNT) do begin
      FSharedMem.Slots[i].Header.State := Integer(ssFree);
      FSharedMem.Slots[i].Header.DataSize := 0;
      FSharedMem.Slots[i].Header.FileID := 0;
      FSharedMem.Slots[i].Header.BlockNumber := 0;
      FSharedMem.Slots[i].Header.FileNameLength := 0;
      FSharedMem.Slots[i].Header.Flags := 0;
      FSharedMem.Slots[i].Header.ErrorCode := 0;
    end;

    // Создание синхронизирующих объектов
    CreateSyncObjects;

    Result := True;
  except
    on E: Exception do begin
      Writeln('Ошибка инициализации сервера: ', E.Message);
      CleanupSyncObjects;
      CleanupMapping;
    end;
  end;
end;

function TSharedMemoryServer.FindReceiveThread(FileID: Integer): TReceiveThread;
var
  List: TList;
  i: Integer;
  Thread: TReceiveThread;
begin
  Result := nil;
  List := FReceiveThreads.LockList;
  try
    for i := 0 to Pred(List.Count) do begin
      Thread := TReceiveThread(List[i]);
      if (Thread.FFileID = FileID) and (not Thread.Finished) then begin
        Result := Thread;
        Break;
      end;
    end;
  finally
    FReceiveThreads.UnlockList;
  end;
end;

function TSharedMemoryServer.FindOrCreateReceiveThread(FileID: Integer; const FileName: string): TReceiveThread;
var
  List: TList;
  i: Integer;
  Thread: TReceiveThread;
begin
  Result := nil;
  List := FReceiveThreads.LockList;
  try
    // Ищем существующий поток с таким FileID
    for i := 0 to Pred(List.Count) do begin
      Thread := TReceiveThread(List[i]);
      if Thread.FFileID = FileID then begin
        Result := Thread;
        Break;
      end;
    end;

    // Если не найден, создаем новый
    if Result = nil then begin
      Result := TReceiveThread.Create(FileID, FileName);
      FReceiveThreads.Add(Result);
    end;
  finally
    FReceiveThreads.UnlockList;
  end;
end;

procedure TSharedMemoryServer.RemoveFinishedThreads;
var
  List: TList;
  i: Integer;
  Thread: TReceiveThread;
begin
  List := FReceiveThreads.LockList;
  try
    for i := Pred(List.Count) downto 0 do begin
      Thread := TReceiveThread(List[i]);
      if Thread.Finished then begin
        List.Delete(i);
        Thread.Free;
      end;
    end;
  finally
    FReceiveThreads.UnlockList;
  end;
end;

procedure TSharedMemoryServer.ProcessSlotData(SlotIndex: Integer);
var
  Header: TSlotHeader;
  DataCopy: Pointer;
  FileName: string;
  Thread: TReceiveThread;
  ErrorCode: Integer;
begin
  // Захватываем мьютекс слота
  WaitForSingleObject(FSlotMutexes[SlotIndex], INFINITE);
  try
    Header := FSharedMem.Slots[SlotIndex].Header;
    if Header.State = Integer(ssDataReady) then begin
      // Копируем данные из общей памяти
      DataCopy := GetMemory(Header.DataSize);
      Move(FSharedMem.Slots[SlotIndex].Data[0], DataCopy^, Header.DataSize);

      // Определяем имя файла, если это первый блок
      if Header.BlockNumber = 0 then begin
        SetLength(FileName, Header.FileNameLength);
        if Header.FileNameLength > 0 then
          Move(DataCopy^, FileName[1], Header.FileNameLength);
        // Если имя не передано, генерируем
        if FileName = '' then
          FileName := 'received_' + IntToStr(Header.FileID) + '.dat';
      end;

      if Header.BlockNumber = 0 then begin
        // Начало новой передачи – всегда создаём новый поток
        Thread := CreateReceiveThread(Header.FileID, FileName);
        // Поток не может быть nil, но на всякий случай проверим
        if Thread = nil then begin
          FSharedMem.Slots[SlotIndex].Header.State := Integer(ssError);
          FSharedMem.Slots[SlotIndex].Header.ErrorCode := ERROR_NOT_ENOUGH_MEMORY;
        end;
      end else begin
        // Продолжение передачи – ищем активный поток
        Thread := FindReceiveThread(Header.FileID);
        if Thread = nil then begin
          FSharedMem.Slots[SlotIndex].Header.State := Integer(ssError);
          FSharedMem.Slots[SlotIndex].Header.ErrorCode := ERROR_INVALID_HANDLE;
        end;
      end;
      
      // Если поток существует, добавляем данные
      if Thread <> nil then begin
        // Добавляем данные в поток
        Thread.AddData(DataCopy, Header.DataSize, Header.Flags);

        // Проверяем, не возникла ли ошибка в потоке
        ErrorCode := Thread.LastError;
        if ErrorCode <> 0 then begin
          FSharedMem.Slots[SlotIndex].Header.State := Integer(ssError);
          FSharedMem.Slots[SlotIndex].Header.ErrorCode := ErrorCode;
        end else begin
          FSharedMem.Slots[SlotIndex].Header.State := Integer(ssDone);
        end;
      end;

      // Освобождаем временный буфер
      FreeMem(DataCopy, Header.DataSize);
    end;
  finally
    ReleaseMutex(FSlotMutexes[SlotIndex]);
  end;

  // Сигналим клиенту о завершении обработки
  SetEvent(FSlotEventsS2C[SlotIndex]);

  // Периодически удаляем завершенные потоки
  RemoveFinishedThreads;
end;

procedure TSharedMemoryServer.DispatcherLoop;
var
  WaitResult: DWORD;
  SlotIndex: Integer;
begin
  while not FStopRequested do begin
    WaitResult := WaitForMultipleObjects(SLOT_COUNT, @FSlotEventsC2S[0], False, 100);
    if WaitResult = WAIT_TIMEOUT then
      Continue;

    if WaitResult >= WAIT_OBJECT_0 then begin
      SlotIndex := WaitResult - WAIT_OBJECT_0;
      ProcessSlotData(SlotIndex);
    end;
  end;
end;

procedure TSharedMemoryServer.Run;
begin
  if FSharedMem = nil then begin
    Writeln('Сервер не инициализирован.');
    Exit;
  end;
  Writeln('Сервер запущен. Для остановки нажмите Ctrl+C...');
  DispatcherLoop;
end;

procedure TSharedMemoryServer.Stop;
begin
  FStopRequested := True;
end;

end.