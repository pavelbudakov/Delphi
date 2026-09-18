program SortFile;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  ExtSortTypes in 'ExtSortTypes.pas',
  ExtSortIO in 'ExtSortIO.pas',
  RunGenerator in 'RunGenerator.pas',
  KWayMerger in 'KWayMerger.pas',
  ExternalSort in 'ExternalSort.pas';

procedure ShowProgress(const Msg: string);
begin
  WriteLn(FormatDateTime('hh:nn:ss', Now), '  ', Msg);
end;

var
  srcFile, dstFile, tempDir: string;
  startTick: DWORD;
begin
  SetConsoleTitle('Sorting huge files');

  SetConsoleCP(1251);
  SetConsoleOutputCP(1251);

  try
    if ParamCount < 2 then
    begin
      WriteLn('Использование: SortFile.exe <исходный файл> <файл результата> [папка для временных файлов]');
      WriteLn('Сортирует строки CRLF-файла (ANSI) по первым 50 символам.');
      Halt(1);
    end;
    srcFile := ParamStr(1);
    dstFile := ParamStr(2);
    if ParamCount >= 3 then
      tempDir := ParamStr(3)
    else
      tempDir := '';

    if not FileExists(srcFile) then
    begin
      WriteLn('Файл не найден: ', srcFile);
      Halt(2);
    end;

    startTick := GetTickCount;
    TExternalSorter.SortFile(srcFile, dstFile, tempDir, ShowProgress);
    WriteLn(Format('Готово за %.1f сек.', [(GetTickCount - startTick) / 1000.0]));
  except
    on E: Exception do
    begin
      WriteLn('Ошибка: ', E.Message);
      Halt(1);
    end;
  end;
end.
