unit fConfiguration;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Buttons, WinSock, DB, ADODB,
  uConstants, uSettings, uJson, uUtils;

type
  TConfigurationWindow = class(TForm)
    pnlLeft: TPanel;
    pnlContent: TPanel;
    gbPortNumber: TGroupBox;
    edPortNumber: TEdit;
    pnlRight: TPanel;
    pnlTop: TPanel;
    lblPortNumber: TLabel;
    btnCheckPort: TBitBtn;
    gbMSSQL: TGroupBox;
    pnlDivider: TPanel;
    btnCheckConnectionString: TBitBtn;
    lblConnectionString: TLabel;
    mConnectionString: TMemo;
    Panel1: TPanel;
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    lblNote: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnCheckPortClick(Sender: TObject);
    procedure edPortNumberKeyPress(Sender: TObject; var Key: Char);
    procedure edPortNumberChange(Sender: TObject);
    procedure btnCheckConnectionStringClick(Sender: TObject);
    procedure mConnectionStringKeyPress(Sender: TObject; var Key: Char);
    procedure mConnectionStringChange(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    { Private declarations }
    FPortValidated: Boolean;
    FConnectionStringValidated: Boolean;
    function IsPortAvailable: Boolean;
    function IsMSSQLConnectionSuccessful: Boolean;
    procedure InitPortCheckButton(Checked: Boolean);
    procedure InitConnectionStringCheckButton(Checked: Boolean);
    function LoadConfiguration: Boolean;
    function SaveConfiguration: Boolean;
  public
    { Public declarations }
    ServerActive : Boolean;
  end;

implementation
uses uWinSock, uMSSQL;

{$R *.dfm}

function TConfigurationWindow.LoadConfiguration: Boolean;
begin
  Result := False;
  if Assigned(AppSettings) then begin
    edPortNumber.Text := IntToStr(AppSettings.Port);
    mConnectionString.Text := AppSettings.ConnectionString;
    Result := True;
  end;
end;

function TConfigurationWindow.SaveConfiguration: Boolean;
begin
  Result := False;
  FreeAndNil(AppSettings);
  AppSettings := TSettings.Create;
  if Assigned(AppSettings)then begin
    AppSettings.Port := StrToIntDef(edPortNumber.Text, 0);
    AppSettings.ConnectionString := PreparedConnectionString(mConnectionString.Text);
    Result := SaveSettings;
  end;
end;

function TConfigurationWindow.IsPortAvailable: Boolean;
begin
  if Assigned(AppSettings) and ServerActive and (AppSettings.Port = StrToIntDef(edPortNumber.Text, 0)) then begin
    Result := True;
  end else begin
    Result := WSIsPortAvailable(StrToIntDef(edPortNumber.Text, 0));
  end;
end;

function TConfigurationWindow.IsMSSQLConnectionSuccessful: Boolean;
begin
  Result := MSSQLConnectionSuccessful(mConnectionString.Text);
end;

procedure TConfigurationWindow.btnCheckPortClick(Sender: TObject);
begin
  InitPortCheckButton(IsPortAvailable);
end;

procedure TConfigurationWindow.edPortNumberKeyPress(Sender: TObject;
  var Key: Char);
begin
  if (not (Key in ['0'..'9', #8, #9]))
    then Key := #0;
end;

procedure TConfigurationWindow.InitPortCheckButton(Checked : Boolean);
begin
  if Checked then begin
    With btnCheckPort do begin
      Kind := bkOK;
      Caption := '';
      Enabled := False;
      Hint := '���������';
    end;
  end else begin
    With btnCheckPort do begin
      Kind := bkRetry;
      Caption := '';
      Enabled := True;
      ModalResult := mrNone;
      Hint := '���������';
    end;
  end;

  FPortValidated := Checked;
  btnOk.Enabled := FPortValidated and FConnectionStringValidated;
  lblNote.Visible := not btnOk.Enabled;
end;

procedure TConfigurationWindow.edPortNumberChange(Sender: TObject);
begin
  InitPortCheckButton(False);
end;

procedure TConfigurationWindow.FormCreate(Sender: TObject);
begin
  LoadConfiguration;
  InitPortCheckButton(False);
  InitConnectionStringCheckButton(False);
end;

procedure TConfigurationWindow.InitConnectionStringCheckButton(Checked : Boolean);
begin
  if Checked then begin
    With btnCheckConnectionString do begin
      Kind := bkOK;
      Caption := '';
      Enabled := False;
      Hint := '���������';
    end;
  end else begin
    With btnCheckConnectionString do begin
      Kind := bkRetry;
      Caption := '';
      Enabled := True;
      ModalResult := mrNone;
      Hint := '���������';
    end;
  end;

  FConnectionStringValidated := Checked;
  btnOk.Enabled := FPortValidated and FConnectionStringValidated;
  lblNote.Visible := not btnOk.Enabled;

end;

procedure TConfigurationWindow.btnCheckConnectionStringClick(
  Sender: TObject);
begin
  InitConnectionStringCheckButton(IsMSSQLConnectionSuccessful);
end;

procedure TConfigurationWindow.mConnectionStringKeyPress(Sender: TObject;
  var Key: Char);
begin
  if Key in [#10, #13]
    then Key := #0;
end;

procedure TConfigurationWindow.mConnectionStringChange(Sender: TObject);
begin
  InitConnectionStringCheckButton(False);
end;

procedure TConfigurationWindow.btnOkClick(Sender: TObject);
begin
  SaveConfiguration;
end;

end.
