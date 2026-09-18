program Client;

uses
  Forms,
  uDTO in '..\Common\uDTO.pas',
  uJson in '..\Common\uJson.pas',
  uUtils in '..\Common\uUtils.pas',
  fConfiguration in 'fConfiguration.pas' {ConfigurationWindow},
  fMainWindow in 'fMainWindow.pas' {MainWindow},
  fUserFrame in 'fUserFrame.pas' {UserFrame: TFrame},
  uConstants in '..\Common\uConstants.pas',
  uWinSock in '..\Common\uWinSock.pas',
  uRestClient in 'uRestClient.pas',
  uJsonResponse in 'uJsonResponse.pas',
  uSettings in 'uSettings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
