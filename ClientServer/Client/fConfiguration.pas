unit fConfiguration;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Buttons, WinSock, DB, ADODB, StrUtils, IdURI,
  uWinSock, uConstants, uSettings, uJson, uUtils;

type
  TConfigurationWindow = class(TForm)
    pnlLeft: TPanel;
    pnlContent: TPanel;
    gbPortNumber: TGroupBox;
    edServerAddress: TEdit;
    pnlRight: TPanel;
    pnlTop: TPanel;
    lblPortNumber: TLabel;
    btnCheckPort: TBitBtn;
    pnlDivider: TPanel;
    pnlButtons: TPanel;
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    lblNote: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnCheckPortClick(Sender: TObject);
    procedure edServerAddressChange(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure edServerAddressKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
    procedure InitPortCheckButton(Checked: Boolean);
    function LoadConfiguration: Boolean;
    function SaveConfiguration: Boolean;
    function SignatureMatches(URL: String): Boolean;
  public
    { Public declarations }
  end;

implementation

{$R *.dfm}

function TConfigurationWindow.LoadConfiguration: Boolean;
begin
  Result := False;
  if Assigned(AppSettings) then begin
    edServerAddress.Text := AppSettings.URL;
    Result := True;
  end;
end;

function TConfigurationWindow.SaveConfiguration: Boolean;
begin
  Result := False;
  AppSettings := TSettings.Create;
  if Assigned(AppSettings)then begin
    AppSettings.URL := Trim(edServerAddress.Text);
    Result := SaveSettings;
  end;
end;

procedure TConfigurationWindow.btnCheckPortClick(Sender: TObject);
begin
  InitPortCheckButton(SignatureMatches(edServerAddress.Text));
end;

procedure TConfigurationWindow.InitPortCheckButton(Checked : Boolean);
begin
  if Checked then begin
    With btnCheckPort do begin
      Kind := bkOK;
      Caption := '';
      Enabled := False;
      Hint := 'Проверено';
    end;
    btnOk.Enabled := True;
  end else begin
    With btnCheckPort do begin
      Kind := bkRetry;
      Caption := '';
      Enabled := True;
      ModalResult := mrNone;
      Hint := 'Проверить';
    end;
    btnOk.Enabled := False;
  end;
  lblNote.Visible := not btnOk.Enabled;
end;

procedure TConfigurationWindow.edServerAddressChange(Sender: TObject);
begin
  InitPortCheckButton(False);
end;

procedure TConfigurationWindow.FormCreate(Sender: TObject);
begin
  LoadConfiguration;
  InitPortCheckButton(False);
end;

procedure TConfigurationWindow.btnOkClick(Sender: TObject);
begin
  SaveConfiguration;
end;

function TConfigurationWindow.SignatureMatches(URL : String): Boolean;
var Response : String;
begin
  try
    Response := WSGetResponse(URL + '/signature');
  finally
    Result := AnsiContainsText(Response, cSIGNATURE);
  end;
end;

procedure TConfigurationWindow.edServerAddressKeyPress(Sender: TObject;
  var Key: Char);
begin
  if (Key <= #32) and (not (Key in [#7, #8])) then Key := #0;
end;

end.
