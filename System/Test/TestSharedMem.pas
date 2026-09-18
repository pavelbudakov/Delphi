// Модуль тестов: TestSharedMem.pas
unit TestSharedMem;

interface

uses
  TestFrameWork, Windows, SysUtils, Classes, SharedMemProtocol;

type
  TTestSharedMemory = class(TTestCase)
  private
    FTestMappingName: string;
    FTestMutexName: string;
    FTestEventName: string;
    // Вспомогательные методы для создания/открытия тестовых объектов
    function CreateTestMapping: THandle;
    function OpenTestMapping: THandle;
  published
    procedure TestEventNameGeneration;
    procedure TestMutexNameGeneration;
    procedure TestSharedMemoryCreation;
    procedure TestSharedMemoryInitialization;
    procedure TestSlotStateManagement;
    procedure TestSlotDataTransfer;
    procedure TestOpenNonExistentMapping;
  end;

implementation

{ TTestSharedMemory }

function TTestSharedMemory.CreateTestMapping: THandle;
begin
  FTestMappingName := 'Local\TestSharedMem_' + IntToStr(GetCurrentProcessId);
  Result := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, SHM_SIZE, PChar(FTestMappingName));
end;

function TTestSharedMemory.OpenTestMapping: THandle;
begin
  Result := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, PChar(FTestMappingName));
end;

procedure TTestSharedMemory.TestEventNameGeneration;
begin
  CheckEqualsString('Global\SHM_C2S_Slot0', GetSlotEventName(True, 0), 'C2S slot 0 name mismatch');
  CheckEqualsString('Global\SHM_S2C_Slot3', GetSlotEventName(False, 3), 'S2C slot 3 name mismatch');
  CheckEqualsString('Global\SHM_C2S_Slot7', GetSlotEventName(True, 7), 'C2S slot 7 name mismatch');
end;

procedure TTestSharedMemory.TestMutexNameGeneration;
begin
  CheckEqualsString('Global\SHM_Mutex_Slot0', GetSlotMutexName(0), 'Mutex slot 0 name mismatch');
  CheckEqualsString('Global\SHM_Mutex_Slot5', GetSlotMutexName(5), 'Mutex slot 5 name mismatch');
end;

procedure TTestSharedMemory.TestSharedMemoryCreation;
var
  hMapping: THandle;
begin
  hMapping := CreateTestMapping;
  Check(hMapping <> 0, 'CreateFileMapping failed');
  CloseHandle(hMapping);
end;

procedure TTestSharedMemory.TestSharedMemoryInitialization;
var
  hMapping: THandle;
  pMem: PSharedMemoryLayout;
  i: Integer;
begin
  hMapping := CreateTestMapping;
  Check(hMapping <> 0, 'CreateFileMapping failed');
  try
    pMem := MapViewOfFile(hMapping, FILE_MAP_ALL_ACCESS, 0, 0, SHM_SIZE);
    Check(pMem <> nil, 'MapViewOfFile failed');
    try
      // Инициализация как на сервере
      pMem.Magic := $12345678;
      pMem.Version := 1;
      pMem.SlotCount := SLOT_COUNT;
      pMem.SlotDataSize := SLOT_DATA_SIZE;
      for i := 0 to SLOT_COUNT - 1 do
        pMem.Slots[i].Header.State := Integer(ssFree);

      // Проверка
      CheckEquals(Integer($12345678), pMem.Magic, 'Magic mismatch');
      CheckEquals(1, pMem.Version, 'Version mismatch');
      CheckEquals(SLOT_COUNT, pMem.SlotCount, 'SlotCount mismatch');
      CheckEquals(SLOT_DATA_SIZE, pMem.SlotDataSize, 'SlotDataSize mismatch');
      for i := 0 to SLOT_COUNT - 1 do
        CheckEquals(Integer(ssFree), pMem.Slots[i].Header.State, 'Slot state not free');
    finally
      UnmapViewOfFile(pMem);
    end;
  finally
    CloseHandle(hMapping);
  end;
end;

procedure TTestSharedMemory.TestSlotStateManagement;
var
  hMapping: THandle;
  pMem: PSharedMemoryLayout;
  SlotIndex: Integer;
begin
  hMapping := CreateTestMapping;
  Check(hMapping <> 0, 'CreateFileMapping failed');
  try
    pMem := MapViewOfFile(hMapping, FILE_MAP_ALL_ACCESS, 0, 0, SHM_SIZE);
    Check(pMem <> nil, 'MapViewOfFile failed');
    try
      // Инициализация
      pMem.Magic := $12345678;
      pMem.Version := 1;
      pMem.SlotCount := SLOT_COUNT;
      pMem.SlotDataSize := SLOT_DATA_SIZE;
      for SlotIndex := 0 to SLOT_COUNT - 1 do
        pMem.Slots[SlotIndex].Header.State := Integer(ssFree);

      // Захват слота (имитация)
      SlotIndex := 0;
      pMem.Slots[SlotIndex].Header.State := Integer(ssBusy);
      CheckEquals(Integer(ssBusy), pMem.Slots[SlotIndex].Header.State, 'Slot not busy after acquire');

      // Освобождение слота
      pMem.Slots[SlotIndex].Header.State := Integer(ssFree);
      CheckEquals(Integer(ssFree), pMem.Slots[SlotIndex].Header.State, 'Slot not free after release');
    finally
      UnmapViewOfFile(pMem);
    end;
  finally
    CloseHandle(hMapping);
  end;
end;

procedure TTestSharedMemory.TestSlotDataTransfer;
var
  hMapping: THandle;
  pMem: PSharedMemoryLayout;
  SlotIndex: Integer;
  TestData: array[0..SLOT_DATA_SIZE-1] of Byte;
  TestData2: array[0..SLOT_DATA_SIZE-1] of Byte;
  i: Integer;
  DataSize: Integer;
  Header: TSlotHeader;
begin
  hMapping := CreateTestMapping;
  Check(hMapping <> 0, 'CreateFileMapping failed');
  try
    pMem := MapViewOfFile(hMapping, FILE_MAP_ALL_ACCESS, 0, 0, SHM_SIZE);
    Check(pMem <> nil, 'MapViewOfFile failed');
    try
      // Инициализация
      pMem.Magic := $12345678;
      pMem.Version := 1;
      pMem.SlotCount := SLOT_COUNT;
      pMem.SlotDataSize := SLOT_DATA_SIZE;
      for SlotIndex := 0 to SLOT_COUNT - 1 do
        pMem.Slots[SlotIndex].Header.State := Integer(ssFree);

      // Подготовка тестовых данных
      for i := 0 to SLOT_DATA_SIZE - 1 do
        TestData[i] := Byte(i mod 256);

      // Выбор слота
      SlotIndex := 2;
      // Заполнение слота (имитация клиента)
      pMem.Slots[SlotIndex].Header.State := Integer(ssDataReady);
      pMem.Slots[SlotIndex].Header.DataSize := SLOT_DATA_SIZE;
      pMem.Slots[SlotIndex].Header.FileID := 12345;
      pMem.Slots[SlotIndex].Header.BlockNumber := 0;
      pMem.Slots[SlotIndex].Header.FileNameLength := 0;
      pMem.Slots[SlotIndex].Header.Flags := 1; // конец файла
      pMem.Slots[SlotIndex].Header.ErrorCode := 0;
      Move(TestData[0], pMem.Slots[SlotIndex].Data[0], SLOT_DATA_SIZE);

      // Чтение данных (имитация сервера)
      Header := pMem.Slots[SlotIndex].Header;
      DataSize := Header.DataSize;
      CheckEquals(SLOT_DATA_SIZE, DataSize, 'Data size mismatch');
      Move(pMem.Slots[SlotIndex].Data[0], TestData2[0], DataSize);
      // Сравнение данных
      for i := 0 to DataSize - 1 do
        CheckEquals(TestData[i], TestData2[i], 'Data mismatch at index ' + IntToStr(i));
    finally
      UnmapViewOfFile(pMem);
    end;
  finally
    CloseHandle(hMapping);
  end;
end;

procedure TTestSharedMemory.TestOpenNonExistentMapping;
var
  hMapping: THandle;
begin
  hMapping := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, PChar('Local\NonExistentMapping_' + IntToStr(GetCurrentProcessId)));
  CheckEquals(0, hMapping, 'OpenFileMapping should fail for non-existent mapping');
end;

initialization
  TestFrameWork.RegisterTest(TTestSharedMemory.Suite);

end.