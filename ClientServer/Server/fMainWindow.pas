unit fMainWindow;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ShellAPI, Menus, uSettings, uRestServer, uMSSQL, uJson, uDTO, uConstants;

const
  WM_TRAYICON = WM_USER + 1;

type
  TMainWindow = class(TForm)
    pmTray: TPopupMenu;
    miExit: TMenuItem;
    miChangeState: TMenuItem;
    miModifySettings: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure pmTrayPopup(Sender: TObject);
    procedure miChangeStateClick(Sender: TObject);
    procedure miModifySettingsClick(Sender: TObject);
  private
    { Private declarations }
    FServer: TRestServer;
    FNotifyIconData: TNotifyIconData;
//    FSQL: TMSSQLHandler;
    procedure AddTrayIcon;
    procedure RemoveTrayIcon;
    procedure ShowPopupMenuAtCursor;
    procedure TrayIconMessage(var Msg: TMessage); message WM_TRAYICON;
    function SettingsExists: Boolean;
    function ModifySettings: Boolean;
    //routes
    function GetSignature(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetGroup(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetGroups(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetUser(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetUsers(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetUsersByGroup(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function GetUsersByGroupNested(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;

  public
    { Public declarations }
  end;

var
  MainWindow: TMainWindow;

implementation

uses fConfiguration, IdCustomHTTPServer;

{$R *.dfm}

procedure TMainWindow.AddTrayIcon;
begin
  FillChar(FNotifyIconData, SizeOf(FNotifyIconData), 0);
  with FNotifyIconData do begin
    cbSize := SizeOf(TNotifyIconData);
    Wnd := Handle;
    uID := 1;
    uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
    uCallbackMessage := WM_TRAYICON;
    hIcon := Application.Icon.Handle;
    StrPCopy(szTip, 'REST Server');
  end;
  Shell_NotifyIcon(NIM_ADD, @FNotifyIconData);
end;

procedure TMainWindow.RemoveTrayIcon;
begin
  Shell_NotifyIcon(NIM_DELETE, @FNotifyIconData);
end;

procedure TMainWindow.TrayIconMessage(var Msg: TMessage);
begin
  case Msg.lParam of
    WM_RBUTTONDOWN:
      ShowPopupMenuAtCursor;
  end;
end;

procedure TMainWindow.ShowPopupMenuAtCursor;
var
  Pt: TPoint;
begin
  GetCursorPos(Pt);
  pmTray.Popup(Pt.X, Pt.Y);
end;

procedure TMainWindow.FormCreate(Sender: TObject);
begin
  if (not SettingsExists) then begin
    if (not ModifySettings) then begin
      PostMessage(Application.Handle, WM_QUIT, 0, 0);
      Exit;
    end;
  end;

  AddTrayIcon;

  FServer := TRestServer.Create;

  FServer.RegisterRoute('/signature', hcGET, GetSignature);

  FServer.RegisterRoute('/users', hcGET, GetUsers);
  FServer.RegisterRoute('/users/{id}', hcGET, GetUser);
  FServer.RegisterRoute('/groups', hcGET, GetGroups);
  FServer.RegisterRoute('/groups/{id}', hcGET, GetGroup);

  FServer.RegisterRoute('/users/group/{id}', hcGET, GetUsersByGroup);
  FServer.RegisterRoute('/users/group/{id}/nested', hcGET, GetUsersByGroupNested);

  FServer.Active := True;
end;

procedure TMainWindow.FormDestroy(Sender: TObject);
begin
  RemoveTrayIcon;
  FreeAndNil(FServer);
end;

procedure TMainWindow.miExitClick(Sender: TObject);
begin
  PostMessage(Application.Handle, WM_QUIT, 0, 0);
end;

procedure TMainWindow.pmTrayPopup(Sender: TObject);
begin
  if Assigned(FServer) and FServer.Active
    then miChangeState.Caption := 'Стоп'
    else miChangeState.Caption := 'Старт'
end;

procedure TMainWindow.miChangeStateClick(Sender: TObject);
begin
  FServer.Active := not FServer.Active;
end;

function TMainWindow.SettingsExists: Boolean;
begin
  Result := Assigned(AppSettings);
end;

function TMainWindow.ModifySettings: Boolean;
var pConfigurationWindow : TConfigurationWindow;
begin
  pConfigurationWindow := TConfigurationWindow.Create(Self);
  try
    pConfigurationWindow.ServerActive := Assigned(FServer) and FServer.Active;
    Result := pConfigurationWindow.ShowModal = mrOK;
  finally
    FreeAndNil(pConfigurationWindow);
  end;
end;

procedure TMainWindow.miModifySettingsClick(Sender: TObject);
begin
  if ModifySettings then begin
    if FServer.Active then begin
      FServer.Active := False;
      FServer.Active := True;
    end;
  end;
end;

//endpoints

function TMainWindow.GetUsers(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_USERS_ALL, Params, User, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetUser(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_USER_BY_USERID, Params, User, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetUsersByGroup(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_USERS_BY_GROUP_DIRECT, Params, User, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetGroups(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_GROUPS_ALL, Params, Group, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetGroup(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_GROUP_BY_GROUPID, Params, Group, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetUsersByGroupNested(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
var ErrorMessage: String;
    pSQL: TMSSQLHandler;
begin
  Result := '';
  RecordCount := 0;
  pSQL := TMSSQLHandler.Create;
  try
    if not pSQL.Connect(AppSettings.ConnectionString, ErrorMessage)
      then raise Exception.Create(MSG_NOT_CONNECTED + ': ' + ErrorMessage);
    try
      Result := pSQL.LoadObjects(QRY_GET_USERS_BY_GROUPID_NESTED, Params, User, RecordCount);
    finally
      pSQL.Disconnect;
    end;
  finally
    FreeAndNil(pSQL);
  end;
end;

function TMainWindow.GetSignature(const Params: TStringList;
  const RawPath: String; out RecordCount: Integer): WideString;
begin
  RecordCount := 0;
  Result := cSIGNATURE;
end;

end.
