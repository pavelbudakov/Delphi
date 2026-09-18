unit ExternalSort;

{
  Точка входа во внешнюю сортировку большого CRLF-файла.

  Оркестрация:
    Фаза 1 (RunGenerator) - файл делится на N = min(4, ядра) смежных
      областей, каждая обрабатывается своим потоком: чанк за чанком
      строится и сортируется в памяти (в рамках бюджета USABLE_BUDGET/N),
      результат пишется во временные run-файлы.
    Фаза 2 (KWayMerger) - run-файлы сливаются проходами. За один проход
      список run-ов делится на смежные группы такого размера K, чтобы
      K потоков буферов чтения + буфер записи укладывались в бюджет на
      один поток слияния; группы сливаются параллельно (до 4 потоков),
      давая новый (меньший) список run-ов. Проходы повторяются, пока не
      останется одна группа - тогда финальное слияние пишет прямо в
      файл результата.

  Порядок run-ов в списках всегда соответствует исходному порядку строк
  в файле - это используется как тай-брейк при равенстве первых 50 байт
  (см. KWayMerger.Less), поэтому важно не переставлять элементы списков.
}

interface

uses
  Classes, SysUtils, Windows, ExtSortTypes, ExtSortIO, RunGenerator, KWayMerger;

type
  TProgressProc = procedure(const Msg: string);

  TExternalSorter = class
  public
    class procedure SortFile(const ASrcFile, ADstFile: string;
      ATempDir: string = ''; OnProgress: TProgressProc = nil);
  end;

implementation

function CeilDiv(a, b: Integer): Integer;
begin
  Result := (a + b - 1) div b;
end;

function GetFileSize64(const FileName: string): Int64;
var
  f: TRawFile;
begin
  f := TRawFile.OpenRead(FileName);
  try
    Result := f.GetSize;
  finally
    f.Free;
  end;
end;

procedure MoveOrCopyFile(const Src, Dst: string);
begin
  if not MoveFileEx(PChar(Src), PChar(Dst), MOVEFILE_REPLACE_EXISTING) then
  begin
    if not CopyFile(PChar(Src), PChar(Dst), False) then
      raise Exception.CreateFmt('Не удалось переместить/скопировать "%s" в "%s" (код %d)',
        [Src, Dst, GetLastError]);
    SysUtils.DeleteFile(Src);
  end;
end;

procedure DeleteRunFiles(List: TStringList);
var
  i: Integer;
begin
  for i := 0 to List.Count - 1 do
    SysUtils.DeleteFile(List[i]);
end;

procedure ExtractGroup(Source: TStringList; StartIdx, Count: Integer; Target: TStringList);
var
  i, last: Integer;
begin
  last := StartIdx + Count - 1;
  if last > Source.Count - 1 then
    last := Source.Count - 1;
  for i := StartIdx to last do
    Target.Add(Source[i]);
end;

procedure RunGroupsInBatches(RunList: TStringList; GroupSize, NumThreads: Integer;
  const TempDir: string; Pass: Integer; NewList: TStringList;
  InputBuf, OutputBuf: Integer; OnProgress: TProgressProc);
var
  groupCount, g, batchSize, i: Integer;
  workers: array of TMergeWorker;
  groupFiles: TStringList;
  outNames: array of string;
  err: string;
begin
  groupCount := CeilDiv(RunList.Count, GroupSize);
  SetLength(outNames, groupCount);
  for g := 0 to groupCount - 1 do
    outNames[g] := TempDir + Format('merge_p%.2d_g%.5d.tmp', [Pass, g]);

  g := 0;
  err := '';
  while g < groupCount do
  begin
    batchSize := NumThreads;
    if batchSize > groupCount - g then
      batchSize := groupCount - g;
    SetLength(workers, batchSize);
    for i := 0 to batchSize - 1 do
    begin
      groupFiles := TStringList.Create;
      ExtractGroup(RunList, (g + i) * GroupSize, GroupSize, groupFiles);
      workers[i] := TMergeWorker.Create(groupFiles, outNames[g + i], InputBuf, OutputBuf);
    end;
    for i := 0 to batchSize - 1 do
      workers[i].WaitFor;
    for i := 0 to batchSize - 1 do
    begin
      if (err = '') and (workers[i].FatalError <> '') then
        err := workers[i].FatalError;
      workers[i].Free;
    end;
    Inc(g, batchSize);
    if Assigned(OnProgress) then
      OnProgress(Format('Слияние: проход %d, группы %d/%d', [Pass, g, groupCount]));
  end;

  if err <> '' then
    raise Exception.Create(err);

  for g := 0 to groupCount - 1 do
    NewList.Add(outNames[g]);
end;

procedure RunMergePhase(RunList: TStringList; const DstFile, TempDir: string;
  NumCPU: Integer; OnProgress: TProgressProc);
var
  pass, numMergeThreads, perThreadBudget, k, groupCount, i: Integer;
  newList: TStringList;
  finalArr: array of string;
  merger: TKWayMerger;
begin
  if RunList.Count = 0 then
  begin
    TRawFile.OpenCreate(DstFile).Free;
    Exit;
  end;
  if RunList.Count = 1 then
  begin
    MoveOrCopyFile(RunList[0], DstFile);
    Exit;
  end;

  pass := 0;
  while True do
  begin
    Inc(pass);
    numMergeThreads := MAX_MERGE_THREADS;
    if numMergeThreads > NumCPU then numMergeThreads := NumCPU;
    if numMergeThreads > RunList.Count then numMergeThreads := RunList.Count;
    if numMergeThreads < 1 then numMergeThreads := 1;

    perThreadBudget := USABLE_BUDGET div numMergeThreads;
    k := (perThreadBudget - MERGE_OUTPUT_BUF_SIZE) div MERGE_INPUT_BUF_SIZE;
    if k < 2 then k := 2;

    groupCount := CeilDiv(RunList.Count, k);

    if groupCount <= 1 then
    begin
      SetLength(finalArr, RunList.Count);
      for i := 0 to RunList.Count - 1 do
        finalArr[i] := RunList[i];
      merger := TKWayMerger.Create(finalArr, FINAL_MERGE_INPUT_BUF);
      try
        merger.MergeTo(DstFile, FINAL_MERGE_OUTPUT_BUF);
      finally
        merger.Free;
      end;
      DeleteRunFiles(RunList);
      Exit;
    end;

    if Assigned(OnProgress) then
      OnProgress(Format('Слияние: проход %d, %d run(ов) -> %d групп (<=%d каждая), потоков: %d',
        [pass, RunList.Count, groupCount, k, numMergeThreads]));

    newList := TStringList.Create;
    try
      RunGroupsInBatches(RunList, k, numMergeThreads, TempDir, pass, newList,
        MERGE_INPUT_BUF_SIZE, MERGE_OUTPUT_BUF_SIZE, OnProgress);
      DeleteRunFiles(RunList);
      RunList.Assign(newList);
    finally
      newList.Free;
    end;
  end;
end;

{ TExternalSorter }

class procedure TExternalSorter.SortFile(const ASrcFile, ADstFile: string;
  ATempDir: string; OnProgress: TProgressProc);
var
  numCPU, numWorkers, i: Integer;
  fileSize: Int64;
  boundaries: TInt64Array;
  workers: array of TRunGenWorker;
  runList: TStringList;
  tempDir: string;
  err: string;
begin
  numCPU := GetLogicalCPUCount;
  fileSize := GetFileSize64(ASrcFile);

  if ATempDir = '' then
  begin
    SetLength(tempDir, MAX_PATH);
    SetLength(tempDir, Windows.GetTempPath(MAX_PATH, PChar(tempDir)));
  end
  else
    tempDir := ATempDir;
  tempDir := IncludeTrailingPathDelimiter(tempDir) +
    Format('extsort_%d_%d', [GetCurrentProcessId, GetTickCount]);
  tempDir := IncludeTrailingPathDelimiter(tempDir);
  ForceDirEx(tempDir);

  try
    if fileSize = 0 then
    begin
      TRawFile.OpenCreate(ADstFile).Free;
      Exit;
    end;

    numWorkers := MAX_GEN_THREADS;
    if numWorkers > numCPU then numWorkers := numCPU;
    if numWorkers < 1 then numWorkers := 1;

    boundaries := ComputeRegionBoundaries(ASrcFile, numWorkers, fileSize);

    if Assigned(OnProgress) then
      OnProgress(Format('Фаза 1: генерация серий, потоков: %d, размер файла: %d байт',
        [numWorkers, fileSize]));

    SetLength(workers, numWorkers);
    for i := 0 to numWorkers - 1 do
      workers[i] := TRunGenWorker.Create(ASrcFile, boundaries[i], boundaries[i + 1],
        tempDir, i, numWorkers);

    runList := TStringList.Create;
    try
      err := '';
      for i := 0 to numWorkers - 1 do
        workers[i].WaitFor;
      for i := 0 to numWorkers - 1 do
      begin
        runList.AddStrings(workers[i].RunFiles);
        if (err = '') and (workers[i].FatalError <> '') then
          err := workers[i].FatalError;
        workers[i].Free;
      end;
      if err <> '' then
        raise Exception.Create(err);

      if Assigned(OnProgress) then
        OnProgress(Format('Фаза 1 завершена: получено %d серий', [runList.Count]));

      RunMergePhase(runList, ADstFile, tempDir, numCPU, OnProgress);
    finally
      runList.Free;
    end;
  finally
    RemoveDir(tempDir);
  end;
end;

end.
