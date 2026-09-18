unit fMainWindow;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ShellAPI, StdCtrls, ExtCtrls, Menus, Buttons,
  uRestClient, uSettings, fConfiguration, fUserFrame,
  uConstants, uJson, uDTO, uUtils, uJsonResponse, ComCtrls;

const
  WM_TRAYICON = WM_USER + 1;

type
  TMainWindow = class(TForm)
    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    gbGroups: TGroupBox;
    pmTray: TPopupMenu;
    miModifySettings: TMenuItem;
    gbUsers: TGroupBox;
    Splitter1: TSplitter;
    lbGroups: TListBox;
    pSB: TScrollBox;
    pbProgress: TProgressBar;
    pnlSearch: TPanel;
    edSearch: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure miModifySettingsClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lbGroupsDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure lbGroupsClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure edSearchChange(Sender: TObject);
  private
    { Private declarations }
    FNotifyIconData: TNotifyIconData;
    FBaseURL: String;
    FRestClient: TRestClient;
    FTimerID : UINT;
    procedure AddTrayIcon;
    procedure RemoveTrayIcon;
    procedure ShowPopupMenuAtCursor;
    procedure LoadGroups;
    procedure SearchTimerMessage(var Msg: TMessage); message WM_TIMER;
    procedure TrayIconMessage(var Msg: TMessage); message WM_TRAYICON;
    function SettingsExists: Boolean;
    function ModifySettings: Boolean;
    procedure ClearScrollBox(AScrollBox: TScrollBox);
    procedure FillScrollBox(AScrollBox: TScrollBox; AList: TList);
  public
    { Public declarations }
  end;

var
  MainWindow: TMainWindow;

implementation
uses uWinSock, StrUtils;

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
    StrPCopy(szTip, 'REST Client');
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

  FRestClient:= TRestClient.Create;
  AddTrayIcon;

  LoadGroups;

end;

procedure TMainWindow.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
var i : Integer;
    pGroup: Group;
begin
  lbGroups.Items.BeginUpdate;
  try
    for i := 0 to Pred(lbGroups.Items.Count) do begin
      pGroup := Group(lbGroups.Items.Objects[i]);
      FreeAndNil(pGroup);
      lbGroups.Items.Objects[i] := nil;
    end;
    ClearScrollBox(pSB);
  finally
    lbGroups.Items.EndUpdate;
  end;
  CanClose := True;
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
    Result := pConfigurationWindow.ShowModal = mrOK;
  finally
    FreeAndNil(pConfigurationWindow);
  end;
end;

procedure TMainWindow.miModifySettingsClick(Sender: TObject);
begin
  if ModifySettings then begin
    FBaseURL := AppSettings.URL;
  end;
end;

procedure TMainWindow.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FRestClient);
  RemoveTrayIcon;
end;

procedure TMainWindow.LoadGroups;
var Response: WideString;
    JsonResponse : TJsonResponse;
    i : Integer;
begin
  Response := FRestClient.GetResponse('/groups');

  JsonResponse := TJsonResponse(DeserializeObject(Response, @CreateJsonResponseInstance, @CreateGroupInstance));
  SendMessage(lbGroups.Handle, WM_SETREDRAW, WPARAM(False), 0);
  try
    lbGroups.Items.Clear;
    for i := 0 to Pred(JsonResponse.Data.Count) do begin
      lbGroups.AddItem(Group(JsonResponse.Data[i]).DisplayName, JsonResponse.Data[i]);
    end;
  finally
    SendMessage(lbGroups.Handle, WM_SETREDRAW, WPARAM(True), 0);
    JsonResponse.Data.OwnsObjects := False;
    FreeAndNil(JsonResponse);
  end;
end;

procedure TMainWindow.lbGroupsDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var Offset : Integer;
    pGroup : Group;
    sNumbers : String;
begin
  pGroup := Group(lbGroups.Items.Objects[Index]);
  sNumbers := Format('%d / %d', [ pGroup.GroupCount, pGroup.UserCount ]);
  with (Control as TListBox).Canvas do begin
    if (odSelected in State)
      then Brush.Color := clTextHighLight
      else begin
      if (Index mod 2) = 0
        then Brush.Color := clBaseText
        else Brush.Color := clAltBaseText;
    end;
//    if (pGroup.UserCount = 0) then begin
    FillRect(Rect);
    Offset := 6;
    TextOut(Rect.Left + Offset, Rect.Top + Offset, lbGroups.Items[Index]);
    TextOut(Rect.Right - Offset - TextWidth(sNumbers), Rect.Top + Offset, sNumbers);
  end;
end;

procedure TMainWindow.lbGroupsClick(Sender: TObject);
var Response: WideString;
    JsonResponse : TJsonResponse;
    pGroup : Group;
begin
  pGroup := Group(lbGroups.Items.Objects[lbGroups.ItemIndex]);

  pSB.Hide;
  pbProgress.Show;
  SendMessage(pSB.Handle, WM_SETREDRAW, WPARAM(False), 0);
  try
    Response := FRestClient.GetResponse(Format('/users/group/%d/nested', [ pGroup.GroupID ]));
    pbProgress.StepIt;
    JsonResponse := TJsonResponse(DeserializeObject(Response, @CreateJsonResponseInstance, @CreateUserInstance));
    pbProgress.StepIt;

    pbProgress.Position := 0;
    pbProgress.Max := JsonResponse.Data.Count;

    FillScrollBox(pSB, JsonResponse.Data);
  finally
    FreeAndNil(JsonResponse);
    pbProgress.Hide;
    pSB.Show;
    gbUsers.Caption := Format(' ѕользователи [%d], группа %d: %s  ', [pSB.ControlCount, pGroup.GroupID, pGroup.DisplayName] );
  end;
end;

function GenerateRandomString(ALength: Integer): string;
const
  Letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  Digits = '0123456789';
var
  i: Integer;
begin
  if ALength <= 0 then begin
    Result := '';
    Exit;
  end;

  SetLength(Result, ALength);
  Result[1] := Letters[Random(Length(Letters)) + 1];

  for i := 2 to ALength do begin
    if Random(2) = 0
      then Result[i] := Letters[Random(Length(Letters)) + 1]
      else Result[i] := Digits[Random(Length(Digits)) + 1];
  end;
end;

procedure TMainWindow.ClearScrollBox(AScrollBox: TScrollBox);
var
  i: Integer;
begin
  if not Assigned(AScrollBox)
    then Exit;

  SendMessage(AScrollBox.Handle, WM_SETREDRAW, 0, 0);
  try
    for i := Pred(AScrollBox.ControlCount) downto 0 do begin
      if AScrollBox.Controls[i] is TUserFrame then
        AScrollBox.Controls[i].Free;
    end;
  finally
    SendMessage(AScrollBox.Handle, WM_SETREDRAW, 1, 0);
    AScrollBox.Invalidate;
  end;
end;

procedure TMainWindow.FillScrollBox(AScrollBox: TScrollBox; AList: TList);
var
  i: Integer;
  UserFrame: TUserFrame;
begin
  if not Assigned(AScrollBox) or not Assigned(AList)
    then Exit;

  SendMessage(AScrollBox.Handle, WM_SETREDRAW, 0, 0);
  try
    ClearScrollBox(AScrollBox);
    for i := 0 to Pred(AList.Count) do begin
      pbProgress.StepIt;
      UserFrame := TUserFrame.Create(AScrollBox);
      UserFrame.Name := GenerateRandomString(20);
      UserFrame.Parent := AScrollBox;
      UserFrame.Align := alTop;
      UserFrame.Top := i * UserFrame.Height;
      UserFrame.LoadData(AList[i]);
    end;
  finally
    SendMessage(AScrollBox.Handle, WM_SETREDRAW, 1, 0);
    AScrollBox.Invalidate;
  end;
end;

procedure TMainWindow.edSearchChange(Sender: TObject);
begin
  KillTimer(Handle, FTimerID);
  FTimerID := SetTimer(Handle, 1, 500, nil);
end;

procedure TMainWindow.SearchTimerMessage(var Msg: TMessage);
var i: Integer;
    iCurrent: Integer;
begin
  KillTimer(Handle, FTimerID);

  iCurrent := lbGroups.ItemIndex;
  if (iCurrent < 0)
    then iCurrent := 0;

  try
    lbGroups.ClearSelection;
    for i := iCurrent to Pred(lbGroups.Items.Count) do begin
      if AnsiContainsText(lbGroups.Items[i], edSearch.Text) then begin
        lbGroups.ItemIndex := i;
        lbGroupsClick(nil);
        Exit;
      end;
    end;
    //не нашли после текущей позиции, начинаем с начала
    for i := 0 to Pred(iCurrent) do begin
      if AnsiContainsText(lbGroups.Items[i], edSearch.Text) then begin
        lbGroups.ItemIndex := i;
        lbGroupsClick(nil);
      end;
    end;
  finally
    lbGroups.SetFocus;
  end;
end;

end.
