// Клиентское приложение: ClientMain.dpr
program ClientMain;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Classes,
  SharedMemProtocol;

var
  hMapping: THandle;
  pSharedMem: PSharedMemoryLayout;
  SlotEventsC2S: array[0..SLOT_COUNT - 1] of THandle;
  SlotEventsS2C: array[0..SLOT_COUNT - 1] of THandle;
  SlotMutexes: array[0..SLOT_COUNT - 1] of THandle;
  GlobalFileID: Integer = 0;

// Освобождение всех ресурсов
procedure Cleanup;
var
  i: Integer;
begin
  for i := 0 to SLOT_COUNT - 1 do
  begin
    if SlotEventsC2S[i] <> 0 then
      CloseHandle(SlotEventsC2S[i]);
    if SlotEventsS2C[i] <> 0 then
      CloseHandle(SlotEventsS2C[i]);
    if SlotMutexes[i] <> 0 then
      CloseHandle(SlotMutexes[i]);
  end;
  if pSharedMem <> nil then
    UnmapViewOfFile(pSharedMem);
  if hMapping <> 0 then
    CloseHandle(hMapping);
end;

// Инициализация: открытие разделяемой памяти и синхронизирующих объектов
function Initialize: Boolean;
var
  i: Integer;
begin
  Result := False;
  hMapping := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, SHM_NAME);
  if hMapping = 0 then
  begin
    Writeln('Ошибка: сервер не запущен или разделяемая память не найдена.');
    Exit;
  end;

  pSharedMem := MapViewOfFile(hMapping, FILE_MAP_ALL_ACCESS, 0, 0, SHM_SIZE);
  if pSharedMem = nil then
  begin
    Writeln('Ошибка: не удалось отобразить разделяемую память.');
    Exit;
  end;

  // Проверка магического числа
  if pSharedMem.Magic <> $12345678 then
  begin
    Writeln('Ошибка: неверный формат разделяемой памяти.');
    Exit;
  end;

  // Открытие событий и мьютексов
  for i := 0 to SLOT_COUNT - 1 do
  begin
    SlotEventsC2S[i] := OpenEvent(EVENT_MODIFY_STATE, False, PChar(GetSlotEventName(True, i)));
    SlotEventsS2C[i] := OpenEvent(SYNCHRONIZE, False, PChar(GetSlotEventName(False, i)));
    SlotMutexes[i] := OpenMutex(MUTEX_ALL_ACCESS, False, PChar(GetSlotMutexName(i)));
    if (SlotEventsC2S[i] = 0) or (SlotEventsS2C[i] = 0) or (SlotMutexes[i] = 0) then
    begin
      Writeln('Ошибка: не удалось открыть синхронизирующие объекты.');
      Exit;
    end;
  end;

  Result := True;
end;

// Поиск свободного слота и его занятие (установка ssBusy)
function AcquireFreeSlot: Integer;
var
  i: Integer;
  dwWait: DWORD;
begin
  Result := -1;
  // Пытаемся найти свободный слот с таймаутом в 5 секунд
  dwWait := 5000;
  while dwWait > 0 do
  begin
    for i := 0 to SLOT_COUNT - 1 do
    begin
      WaitForSingleObject(SlotMutexes[i], INFINITE);
      try
        if pSharedMem.Slots[i].Header.State = Integer(ssFree) then
        begin
          pSharedMem.Slots[i].Header.State := Integer(ssBusy);
          Result := i;
          Exit;
        end;
      finally
        ReleaseMutex(SlotMutexes[i]);
      end;
    end;
    // Если не нашли, ждем 100 мс и повторяем
    Sleep(100);
    Dec(dwWait, 100);
  end;
  Writeln('Ошибка: нет свободных слотов для передачи.');
end;

// Освобождение слота
procedure ReleaseSlot(SlotIndex: Integer);
begin
  if (SlotIndex >= 0) and (SlotIndex < SLOT_COUNT) then
  begin
    WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
    try
      pSharedMem.Slots[SlotIndex].Header.State := Integer(ssFree);
    finally
      ReleaseMutex(SlotMutexes[SlotIndex]);
    end;
  end;
end;

// Передача одного файла
procedure SendFile(const FileName: string);
var
  SlotIndex: Integer;
  FileStream: TFileStream;
  Buffer: Pointer;
  BytesRead: Integer;
  BlockNumber: Integer;
  FileID: Integer;
  FileShortName: string;
//  DataSize: Integer;
//  Header: TSlotHeader;
  dwWait: DWORD;
  ErrorCode: Integer;
begin
  // Проверка существования файла
  if not FileExists(FileName) then
  begin
    Writeln('Ошибка: файл не найден: ', FileName);
    Exit;
  end;

  // Получение короткого имени файла (без пути) для отправки
  FileShortName := ExtractFileName(FileName);
  if Length(FileShortName) > SLOT_DATA_SIZE then
  begin
    Writeln('Ошибка: имя файла слишком длинное.');
    Exit;
  end;

  // Поиск свободного слота
  SlotIndex := AcquireFreeSlot;
  if SlotIndex < 0 then
    Exit;

  try
    // Открытие файла для чтения
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      FileID := InterlockedIncrement(GlobalFileID); // Уникальный идентификатор передачи
//      FileID := Integer(GetCurrentThreadId);// Уникальный идентификатор передачи
      BlockNumber := 0;
      // Первый блок: передаем имя файла
      WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
      try
        // Заполняем заголовок
        pSharedMem.Slots[SlotIndex].Header.State := Integer(ssDataReady);
        pSharedMem.Slots[SlotIndex].Header.FileID := FileID;
        pSharedMem.Slots[SlotIndex].Header.BlockNumber := BlockNumber;
        pSharedMem.Slots[SlotIndex].Header.FileNameLength := Length(FileShortName);
        pSharedMem.Slots[SlotIndex].Header.Flags := 0; // пока не конец файла
        pSharedMem.Slots[SlotIndex].Header.ErrorCode := 0;
        pSharedMem.Slots[SlotIndex].Header.DataSize := Length(FileShortName);
        // Копируем имя файла в буфер данных
        Move(FileShortName[1], pSharedMem.Slots[SlotIndex].Data[0], Length(FileShortName));
      finally
        ReleaseMutex(SlotMutexes[SlotIndex]);
      end;

      // Сигналим серверу
      SetEvent(SlotEventsC2S[SlotIndex]);

      // Ждем подтверждения
      dwWait := WaitForSingleObject(SlotEventsS2C[SlotIndex], TIMEOUT_MS);
      if dwWait = WAIT_TIMEOUT then
        raise Exception.Create('Таймаут ожидания ответа от сервера.');

      // Проверяем состояние слота
      WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
      try
        if pSharedMem.Slots[SlotIndex].Header.State = Integer(ssError) then
        begin
          ErrorCode := pSharedMem.Slots[SlotIndex].Header.ErrorCode;
          raise Exception.CreateFmt('Сервер вернул ошибку (код %d).', [ErrorCode]);
        end
        else if pSharedMem.Slots[SlotIndex].Header.State <> Integer(ssDone) then
          raise Exception.Create('Неожиданное состояние слота после передачи.');
      finally
        ReleaseMutex(SlotMutexes[SlotIndex]);
      end;

      // Передача данных файла
      GetMem(Buffer, SLOT_DATA_SIZE);
      try
        repeat
          BytesRead := FileStream.Read(Buffer^, SLOT_DATA_SIZE);
          if BytesRead = 0 then
            Break;

          // Заполняем слот данными
          WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
          try
            pSharedMem.Slots[SlotIndex].Header.State := Integer(ssDataReady);
            pSharedMem.Slots[SlotIndex].Header.FileID := FileID;
            pSharedMem.Slots[SlotIndex].Header.BlockNumber := BlockNumber + 1;
            pSharedMem.Slots[SlotIndex].Header.FileNameLength := 0; // имя файла уже передано
            if BytesRead < SLOT_DATA_SIZE then
              pSharedMem.Slots[SlotIndex].Header.Flags := 1 // конец файла
            else
              pSharedMem.Slots[SlotIndex].Header.Flags := 0;
            pSharedMem.Slots[SlotIndex].Header.ErrorCode := 0;
            pSharedMem.Slots[SlotIndex].Header.DataSize := BytesRead;
            Move(Buffer^, pSharedMem.Slots[SlotIndex].Data[0], BytesRead);
          finally
            ReleaseMutex(SlotMutexes[SlotIndex]);
          end;

          // Сигналим серверу
          SetEvent(SlotEventsC2S[SlotIndex]);

          // Ждем подтверждения
          dwWait := WaitForSingleObject(SlotEventsS2C[SlotIndex], TIMEOUT_MS);
          if dwWait = WAIT_TIMEOUT then
            raise Exception.Create('Таймаут ожидания ответа от сервера.');

          // Проверяем состояние
          WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
          try
            if pSharedMem.Slots[SlotIndex].Header.State = Integer(ssError) then
            begin
              ErrorCode := pSharedMem.Slots[SlotIndex].Header.ErrorCode;
              raise Exception.CreateFmt('Сервер вернул ошибку (код %d).', [ErrorCode]);
            end
            else if pSharedMem.Slots[SlotIndex].Header.State <> Integer(ssDone) then
              raise Exception.Create('Неожиданное состояние слота после передачи.');
          finally
            ReleaseMutex(SlotMutexes[SlotIndex]);
          end;

          Inc(BlockNumber);
        until BytesRead < SLOT_DATA_SIZE; // последний блок

        // Если файл был пустой, то нужно отправить специальный блок с флагом конца
        if FileStream.Size = 0 then
        begin
          // Отправляем блок 0 с флагом конца (имя файла + конец)
          WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
          try
            pSharedMem.Slots[SlotIndex].Header.State := Integer(ssDataReady);
            pSharedMem.Slots[SlotIndex].Header.FileID := FileID;
            pSharedMem.Slots[SlotIndex].Header.BlockNumber := 0;
            pSharedMem.Slots[SlotIndex].Header.FileNameLength := Length(FileShortName);
            pSharedMem.Slots[SlotIndex].Header.Flags := 1; // конец файла
            pSharedMem.Slots[SlotIndex].Header.ErrorCode := 0;
            pSharedMem.Slots[SlotIndex].Header.DataSize := Length(FileShortName);
            Move(FileShortName[1], pSharedMem.Slots[SlotIndex].Data[0], Length(FileShortName));
          finally
            ReleaseMutex(SlotMutexes[SlotIndex]);
          end;

          SetEvent(SlotEventsC2S[SlotIndex]);
          dwWait := WaitForSingleObject(SlotEventsS2C[SlotIndex], TIMEOUT_MS);
          if dwWait = WAIT_TIMEOUT then
            raise Exception.Create('Таймаут ожидания ответа от сервера.');

          WaitForSingleObject(SlotMutexes[SlotIndex], INFINITE);
          try
            if pSharedMem.Slots[SlotIndex].Header.State = Integer(ssError) then
            begin
              ErrorCode := pSharedMem.Slots[SlotIndex].Header.ErrorCode;
              raise Exception.CreateFmt('Сервер вернул ошибку (код %d).', [ErrorCode]);
            end
            else if pSharedMem.Slots[SlotIndex].Header.State <> Integer(ssDone) then
              raise Exception.Create('Неожиданное состояние слота после передачи.');
          finally
            ReleaseMutex(SlotMutexes[SlotIndex]);
          end;
        end;
      finally
        FreeMem(Buffer, SLOT_DATA_SIZE);
      end;

      Writeln('Файл успешно передан: ', FileName);
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('Ошибка при передаче файла: ', E.Message);
    end;
  end;

  // Освобождение слота
  ReleaseSlot(SlotIndex);
end;

var
  i: Integer;
  FileName: string;
begin
  SetConsoleTitle('Shared Memory Client');
  SetConsoleCP(1251);
  SetConsoleOutputCP(1251);

  Writeln('Клиент разделяемой памяти.');

  if ParamCount < 1 then
  begin
    Writeln('Использование: ClientMain.exe <имя файла> [имя файла 2 ...]');
    Writeln('Нажмите Enter для выхода...');
    Readln;
    Exit;
  end;

  if not Initialize then
  begin
    Writeln('Нажмите Enter для выхода...');
    Readln;
    Exit;
  end;

  try
    // Передача каждого файла, указанного в командной строке
    for i := 1 to ParamCount do
    begin
      FileName := ParamStr(i);
      Writeln('Передача файла: ', FileName);
      SendFile(FileName);
    end;
  finally
    Cleanup;
  end;

  Writeln('Работа завершена. Нажмите Enter для выхода...');
  Readln;
end.