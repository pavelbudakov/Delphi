program Server;

uses
  Windows,
  Forms,
  uSettings in 'uSettings.pas',
  fMainWindow in 'fMainWindow.pas' {MainWindow},
  fConfiguration in 'fConfiguration.pas' {ConfigurationWindow},
  uConstants in '..\Common\uConstants.pas',
  uDTO in '..\Common\uDTO.pas',
  uJson in '..\Common\uJson.pas',
  uUtils in '..\Common\uUtils.pas',
  uWinSock in '..\Common\uWinSock.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
