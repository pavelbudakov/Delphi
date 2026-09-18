{$M+}

unit uDTO;

interface
uses Classes, SysUtils, TypInfo, Contnrs, uJson;

Type
  Group = class(TPersistent)
  private
    FGroupID: Integer;
    FDisplayName: WideString;
    FGroupCount: Integer;
    FUserCount: Integer;
  published
    property GroupID: Integer read FGroupID write FGroupID;
    property DisplayName: WideString read FDisplayName write FDisplayName;
    property UserCount: Integer read FUserCount write FUserCount;
    property GroupCount: Integer read FGroupCount write FGroupCount;
  end;

  User = class(TPersistent)
  private
    FGroupId: Integer;
    FUserId: Integer;
    FAccountEnabled: Boolean;
    FDisplayName: WideString;
    FPhoto: WideString;
    FPhone: WideString;
    FAddress: WideString;
    FNote: WideString;
    FGroupPath: WideString;
    FGroupDisplayName: WideString;
  public
    function Copy: User;
  published
    property GroupId: Integer read FGroupId write FGroupId;
    property UserId: Integer read FUserId write FUserId;
    property GroupDisplayName: WideString read FGroupDisplayName write FGroupDisplayName;
    property AccountEnabled: Boolean read FAccountEnabled write FAccountEnabled;
    property DisplayName: WideString read FDisplayName write FDisplayName;
    property Photo: WideString read FPhoto write FPhoto;
    property Phone: WideString read FPhone write FPhone;
    property Address: WideString read FAddress write FAddress;
    property Note: WideString read FNote write FNote;
    property GroupPath: WideString read FGroupPath write FGroupPath;
  end;

function CreateGroupInstance: TObject;
function CreateUserInstance: TObject;


implementation

function CreateGroupInstance: TObject;
begin
  Result := Group.Create;
end;

function CreateUserInstance: TObject;
begin
  Result := User.Create;
end;

{ User }

function User.Copy: User;
begin
  Result := User.Create;
  Result.GroupId := GroupId;
  Result.UserId  := UserId;
  Result.AccountEnabled := AccountEnabled;
  Result.DisplayName := DisplayName;
  Result.Photo := Photo;
  Result.Phone := Phone;
  Result.Address := Address;
  Result.Note := Note;
  Result.GroupPath := GroupPath;
end;

end.
