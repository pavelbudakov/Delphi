program ServerTests;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  uJson in '..\Common\uJson.pas',
  uConstants in '..\Common\uConstants.pas',
  uDTO in '..\Common\uDTO.pas',
  uUtils in '..\Common\uUtils.pas',
  uWinSock in '..\Common\uWinSock.pas',
  uRestRoutes in '..\Server\uRestRoutes.pas',
  uMSSQL in '..\Server\uMSSQL.pas',
  TestUJson in 'TestUJson.pas',
  TestURestRoutes in 'TestURestRoutes.pas',
  TestUMSSQL in 'TestUMSSQL.pas',
  TestUUtils in 'TestUUtils.pas',
  TestUWinSock in 'TestUWinSock.pas';

begin
  Application.Initialize;
  if IsConsole then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.
