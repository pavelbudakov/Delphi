program Server;

{$APPTYPE CONSOLE}


uses
  Windows,
  SysUtils,
  ServerMain in 'ServerMain.pas',
  SharedMemProtocol in 'SharedMemProtocol.pas';

var
  ServerInstance: TSharedMemoryServer;
begin
  SetConsoleTitle('Shared Memory Server');
  SetConsoleCP(1251);
  SetConsoleOutputCP(1251);

  Writeln('Сервер разделяемой памяти');
  ServerInstance := TSharedMemoryServer.Create;
  try
    if ServerInstance.Initialize then
      ServerInstance.Run
    else
      Writeln('Не удалось инициализировать сервер.');
  finally
    ServerInstance.Free;
  end;
end.