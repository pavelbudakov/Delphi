unit SharedMemProtocol;

interface

const
  SHM_NAME = 'Global\MySharedMemory_7F3A9C2E-4B1D-4F8E-9A2B-6C5D4E3F2A1B';
  SHM_SIZE = 256 * 1024;          // 256 КБ
  SLOT_COUNT = 8;
  SLOT_DATA_SIZE = 30 * 1024;     // 30 КБ на слот
  EVENT_CLIENT_TO_SERVER = 'Global\SHM_C2S_Slot%d';
  EVENT_SERVER_TO_CLIENT = 'Global\SHM_S2C_Slot%d';
  MUTEX_SLOT = 'Global\SHM_Mutex_Slot%d';
  TIMEOUT_MS = 10000;             // Таймаут ожидания

type
  // Состояния слота
  TSlotState = (
    ssFree = 0,        // слот свободен
    ssBusy = 1,        // клиент занял слот, готовит данные
    ssDataReady = 2,   // данные записаны, сервер должен обработать
    ssDone = 3,        // сервер обработал, клиент может писать следующий блок
    ssError = 4        // ошибка обработки
  );

  // Заголовок слота
  TSlotHeader = packed record
    State: Integer;                 // TSlotState
    DataSize: Integer;              // количество байт данных в буфере
    FileID: Integer;                // уникальный идентификатор передачи (например, handle потока клиента)
    BlockNumber: Integer;           // номер блока (0 – первый блок, содержит имя файла)
    FileNameLength: Integer;        // длина имени файла (только для BlockNumber = 0)
    Flags: Integer;                 // битовые флаги: 1 = конец файла (EndOfFile)
    ErrorCode: Integer;             // код ошибки (если State = ssError)
    Reserved: array[0..27] of Byte; // выравнивание
  end;

  // Полное описание слота
  TSlot = packed record
    Header: TSlotHeader;
    Data: array[0..SLOT_DATA_SIZE - 1] of Byte;
  end;

  // Структура всей разделяемой памяти
  TSharedMemoryLayout = packed record
    Magic: Integer;
    Version: Integer;
    SlotCount: Integer;
    SlotDataSize: Integer;
    Slots: array[0..SLOT_COUNT - 1] of TSlot;
  end;

  PSharedMemoryLayout = ^TSharedMemoryLayout;

// Вспомогательные функции для работы с событиями и мьютексами
function GetSlotEventName(ClientToServer: Boolean; SlotIndex: Integer): string;
function GetSlotMutexName(SlotIndex: Integer): string;

implementation

uses
  SysUtils;

function GetSlotEventName(ClientToServer: Boolean; SlotIndex: Integer): string;
begin
  if ClientToServer
    then Result := Format(EVENT_CLIENT_TO_SERVER, [SlotIndex])
    else Result := Format(EVENT_SERVER_TO_CLIENT, [SlotIndex]);
end;

function GetSlotMutexName(SlotIndex: Integer): string;
begin
  Result := Format(MUTEX_SLOT, [SlotIndex]);
end;

end.