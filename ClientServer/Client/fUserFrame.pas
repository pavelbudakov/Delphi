unit fUserFrame;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, IdCoderMIME, JPEG, uDTO;

type
  TUserFrame = class(TFrame)
    pnlUser: TPanel;
    pImage: TImage;
    lblName: TLabel;
    lblPhone: TLabel;
    lblAddress: TLabel;
    lblNote: TLabel;
    lblUserID: TLabel;
    lblGroupPath: TLabel;
    lblGroupID: TLabel;
  protected
    procedure WndProc(var Message: TMessage); override;
  private
    FUser: User;
    { Private declarations }
    procedure SetAccountEnabled(const Value: Boolean);
    procedure SetAddress(const Value: WideString);
    procedure SetDisplayName(const Value: WideString);
    procedure SetGroupId(const Value: Integer);
    procedure SetGroupPath(const Value: WideString);
    procedure SetNote(const Value: WideString);
    procedure SetPhone(const Value: WideString);
    procedure SetPhoto(const Value: WideString);
    procedure SetUserId(const Value: Integer);
  public
    { Public declarations }
    destructor Destroy; override;
    procedure LoadData(pUser: User);
    property GroupId: Integer write SetGroupId;
    property UserId: Integer write SetUserId;
    property AccountEnabled: Boolean write SetAccountEnabled;
    property DisplayName: WideString write SetDisplayName;
    property Photo: WideString write SetPhoto;
    property Phone: WideString write SetPhone;
    property Address: WideString write SetAddress;
    property Note: WideString write SetNote;
    property GroupPath: WideString write SetGroupPath;
    property UserData : User read FUser write FUser;
  end;

implementation

{$R *.dfm}

{ TUserFrame }

procedure TUserFrame.SetAccountEnabled(const Value: Boolean);
begin
  if Value
    then pnlUser.Color := clWhite
    else pnlUser.Color := clSilver;
end;

procedure TUserFrame.SetAddress(const Value: WideString);
begin
  lblAddress.Caption := Value;
end;

procedure TUserFrame.SetDisplayName(const Value: WideString);
var s: String;
begin
  s := Value;
  if (not FUser.AccountEnabled)
    then s := s + ' [не активен]';
  lblName.Caption := s;
end;

procedure TUserFrame.SetUserId(const Value: Integer);
begin
  lblUserID.Caption := Format('Пользователь: %d', [Value]);
end;

procedure TUserFrame.SetGroupId(const Value: Integer);
begin
  lblGroupID.Caption := Format('Группа: %d', [Value]);
end;

procedure TUserFrame.SetGroupPath(const Value: WideString);
begin
  if (Pos( '>', Value) > 0)
    then lblGroupPath.Caption := Format('Вложенная группа: %s', [Value])
    else lblGroupPath.Caption := '';
end;

procedure TUserFrame.SetNote(const Value: WideString);
begin
  lblNote.Caption := Value;
end;

procedure TUserFrame.SetPhone(const Value: WideString);
begin
  lblPhone.Caption := Value;
end;

procedure TUserFrame.SetPhoto(const Value: WideString);
var pMS : TMemoryStream;
    pDecoder : TIdDecoderMIME;
    pGraphic: TGraphic;
begin
  pMS := TMemoryStream.Create;
  pDecoder := TIdDecoderMIME.Create(nil);
  try
    pDecoder.DecodeStream(Value, pMS);
    pMS.Position := 0;

    pGraphic := TJPEGImage.Create;
    try
      pGraphic.LoadFromStream(pMS);
      pImage.Picture.Assign(pGraphic);
    finally
      FreeAndNil(pGraphic);
    end;

  finally
    FreeAndNIl(pDecoder);
    FreeAndNil(pMS);
  end;

end;

procedure TUserFrame.LoadData(pUser: User);
begin
  if (not Assigned(pUser)) then Exit;
  UserData       := pUser.Copy;

  GroupId := pUser.GroupID;
  UserId  := pUser.UserId;
  AccountEnabled := pUser.AccountEnabled;
  DisplayName    := pUser.DisplayName;
  Photo          := pUser.Photo;
  Phone          := pUser.Phone;
  Address        := pUser.Address;
  Note           := pUser.Note;
  GroupPath      := pUser.GroupPath;
end;

procedure TUserFrame.WndProc(var Message: TMessage);
var
  ParentScrollBox: TScrollBox;
  Ctrl: TWinControl;
  Frames: TList;
  i: Integer;
  CurrentIndex: Integer;
  TargetFrame: TUserFrame;
  WheelDelta: SmallInt;
begin
  ParentScrollBox := nil;
  Ctrl := Parent;
  while Assigned(Ctrl) do begin
    if Ctrl is TScrollBox then begin
      ParentScrollBox := TScrollBox(Ctrl);
      Break;
    end;
    Ctrl := Ctrl.Parent;
  end;

  if not Assigned(ParentScrollBox) then begin
    inherited;
    Exit;
  end;

  Frames := TList.Create;
  try
    for i := 0 to ParentScrollBox.ControlCount - 1 do begin
      if ParentScrollBox.Controls[i] is TUserFrame
        then Frames.Add(ParentScrollBox.Controls[i]);
    end;

    CurrentIndex := Frames.IndexOf(Self);
    if CurrentIndex < 0 then begin
      inherited;
      Exit;
    end;

    TargetFrame := nil;

    case Message.Msg of
      WM_KEYDOWN:
        case Message.WParam of
          VK_UP:
            if CurrentIndex > 0
              then TargetFrame := TUserFrame(Frames[CurrentIndex - 1]);

          VK_DOWN:
            if CurrentIndex < Frames.Count - 1
              then TargetFrame := TUserFrame(Frames[CurrentIndex + 1]);

          VK_PRIOR:
            if CurrentIndex > 0 then begin
              i := CurrentIndex - 5;
              if i < 0 then i := 0;
              TargetFrame := TUserFrame(Frames[i]);
            end;

          VK_NEXT:
            if CurrentIndex < Frames.Count - 1 then begin
              i := CurrentIndex + 5;
              if i > Frames.Count - 1 then i := Frames.Count - 1;
              TargetFrame := TUserFrame(Frames[i]);
            end;

          VK_HOME:
            if Frames.Count > 0
              then TargetFrame := TUserFrame(Frames[0]);

          VK_END:
            if Frames.Count > 0
              then TargetFrame := TUserFrame(Frames[Frames.Count - 1]);
        end;

      WM_MOUSEWHEEL:
        begin
          WheelDelta := SmallInt(Message.WParam shr 16);
          if WheelDelta > 0 then begin
            if CurrentIndex > 0
              then TargetFrame := TUserFrame(Frames[CurrentIndex - 1]);
          end
          else if WheelDelta < 0 then begin
            if CurrentIndex < Frames.Count - 1
              then TargetFrame := TUserFrame(Frames[CurrentIndex + 1]);
          end;
        end;
    end;

    if Assigned(TargetFrame) then begin
      ParentScrollBox.ScrollInView(TargetFrame);
      Message.Result := 0;
      Exit;
    end;
  finally
    Frames.Free;
  end;

  inherited;
end;
destructor TUserFrame.Destroy;
begin
  if Assigned(FUser)
    then FreeAndNil(FUser);
  inherited;
end;

end.
