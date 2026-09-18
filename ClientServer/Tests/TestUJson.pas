unit TestUJson;

interface

uses
  TestFramework, Classes, Contnrs, SysUtils, uJson, uDTO;

type
  TTestUJson = class(TTestCase)
  private
    procedure DeserializeObject_NoFactory;
    procedure DeserializeObject_InvalidJson;
    procedure DeserializeList_NotAnArray;
    procedure DeserializeList_NoFactory;
  published
    procedure SerializeObject_User_ProducesExpectedFields;
    procedure SerializeObject_EscapesSpecialCharacters;
    procedure SerializeList_EmptyList_ReturnsEmptyArray;
    procedure SerializeList_TwoItems_ReturnsJsonArray;

    procedure DeserializeObject_RoundTrip_RestoresProperties;
    procedure DeserializeObject_BooleanTrue;
    procedure DeserializeObject_BooleanFalse;
    procedure DeserializeObject_MissingFactory_Raises;
    procedure DeserializeObject_MalformedJson_Raises;

    procedure DeserializeList_RoundTrip;
    procedure DeserializeList_NonArrayJson_Raises;
    procedure DeserializeList_MissingFactory_Raises;

    procedure EscapeJSONString_EscapesQuotesAndBackslashes;
    procedure EscapeJSONString_EscapesControlCharacters;
    procedure EscapeJSONString_LeavesPlainTextUnchanged;
  end;

implementation

{ TTestUJson }

procedure TTestUJson.SerializeObject_User_ProducesExpectedFields;
var
  U: User;
  Json: string;
begin
  U := User.Create;
  try
    U.GroupId := 1;
    U.UserId := 42;
    U.AccountEnabled := True;
    U.DisplayName := 'Ivan Petrov';
    U.GroupPath := 'Root -> Sales';

    Json := SerializeObject(U);

    Check(Pos('"GroupId":1', Json) > 0, 'GroupId missing/incorrect: ' + Json);
    Check(Pos('"UserId":42', Json) > 0, 'UserId missing/incorrect: ' + Json);
    Check(Pos('"AccountEnabled":true', Json) > 0, 'AccountEnabled missing/incorrect: ' + Json);
    Check(Pos('"DisplayName":"Ivan Petrov"', Json) > 0, 'DisplayName missing/incorrect: ' + Json);
    Check(Pos('"GroupPath":"Root -> Sales"', Json) > 0, 'GroupPath missing/incorrect: ' + Json);
    Check(Copy(Json, 1, 1) = '{', 'JSON must start with {');
    Check(Copy(Json, Length(Json), 1) = '}', 'JSON must end with }');
  finally
    U.Free;
  end;
end;

procedure TTestUJson.SerializeObject_EscapesSpecialCharacters;
var
  U: User;
  Json: string;
begin
  U := User.Create;
  try
    U.DisplayName := 'Line1' + #13#10 + 'Line2 "quoted" \ backslash';
    Json := SerializeObject(U);

    Check(Pos('\"quoted\"', Json) > 0, 'Quotes must be escaped: ' + Json);
    Check(Pos('\\', Json) > 0, 'Backslash must be escaped: ' + Json);
    Check(Pos('\r\n', Json) > 0, 'CRLF must be escaped: ' + Json);
    Check(Pos(#13, Json) = 0, 'Raw CR must not appear unescaped: ' + Json);
  finally
    U.Free;
  end;
end;

procedure TTestUJson.SerializeList_EmptyList_ReturnsEmptyArray;
var
  List: TObjectList;
begin
  List := TObjectList.Create(True);
  try
    CheckEquals('[]', SerializeList(List));
  finally
    List.Free;
  end;
end;

procedure TTestUJson.SerializeList_TwoItems_ReturnsJsonArray;
var
  List: TObjectList;
  U1, U2: User;
  Json: string;
begin
  List := TObjectList.Create(True);
  try
    U1 := User.Create;
    U1.UserId := 1;
    List.Add(U1);

    U2 := User.Create;
    U2.UserId := 2;
    List.Add(U2);

    Json := SerializeList(List);

    Check(Copy(Json, 1, 1) = '[', 'Array must start with [: ' + Json);
    Check(Copy(Json, Length(Json), 1) = ']', 'Array must end with ]: ' + Json);
    Check(Pos('"UserId":1', Json) > 0, 'First user missing: ' + Json);
    Check(Pos('"UserId":2', Json) > 0, 'Second user missing: ' + Json);
    Check(Pos('},{', Json) > 0, 'Two objects should be comma separated: ' + Json);
  finally
    List.Free;
  end;
end;

procedure TTestUJson.DeserializeObject_RoundTrip_RestoresProperties;
var
  Original, Restored: User;
  Json: string;
begin
  Original := User.Create;
  Original.GroupId := 7;
  Original.UserId := 99;
  Original.AccountEnabled := True;
  Original.DisplayName := 'Test User';
  Original.Phone := '555-0100';
  Original.Address := 'Nowhere';
  Original.Note := 'Some note';
  Original.GroupPath := 'A -> B';

  Json := SerializeObject(Original);

  Restored := User(DeserializeObject(Json, @CreateUserInstance));
  try
    CheckEquals(Original.GroupId, Restored.GroupId, 'GroupId');
    CheckEquals(Original.UserId, Restored.UserId, 'UserId');
    Check(Original.AccountEnabled = Restored.AccountEnabled, 'AccountEnabled mismatch');
    CheckEquals(string(Original.DisplayName), string(Restored.DisplayName), 'DisplayName');
    CheckEquals(string(Original.Phone), string(Restored.Phone), 'Phone');
    CheckEquals(string(Original.Address), string(Restored.Address), 'Address');
    CheckEquals(string(Original.Note), string(Restored.Note), 'Note');
    CheckEquals(string(Original.GroupPath), string(Restored.GroupPath), 'GroupPath');
  finally
    Restored.Free;
    Original.Free;
  end;
end;

procedure TTestUJson.DeserializeObject_BooleanTrue;
var
  U: User;
begin
  U := User(DeserializeObject('{"AccountEnabled":true}', @CreateUserInstance));
  try
    Check(U.AccountEnabled, 'Expected AccountEnabled = True');
  finally
    U.Free;
  end;
end;

procedure TTestUJson.DeserializeObject_BooleanFalse;
var
  U: User;
begin
  U := User(DeserializeObject('{"AccountEnabled":false}', @CreateUserInstance));
  try
    Check(not U.AccountEnabled, 'Expected AccountEnabled = False');
  finally
    U.Free;
  end;
end;

procedure TTestUJson.DeserializeObject_NoFactory;
begin
  DeserializeObject('{}', nil);
end;

procedure TTestUJson.DeserializeObject_MissingFactory_Raises;
begin
  CheckException(DeserializeObject_NoFactory, Exception, 'Expected exception when class factory is nil');
end;

procedure TTestUJson.DeserializeObject_InvalidJson;
begin
  DeserializeObject('{not valid json', @CreateUserInstance);
end;

procedure TTestUJson.DeserializeObject_MalformedJson_Raises;
begin
  CheckException(DeserializeObject_InvalidJson, Exception, 'Expected exception for malformed JSON');
end;

procedure TTestUJson.DeserializeList_RoundTrip;
var
  List, Restored: TObjectList;
  U1, U2: User;
  Json: string;
begin
  List := TObjectList.Create(True);
  try
    U1 := User.Create;
    U1.UserId := 1;
    U1.DisplayName := 'One';
    List.Add(U1);

    U2 := User.Create;
    U2.UserId := 2;
    U2.DisplayName := 'Two';
    List.Add(U2);

    Json := SerializeList(List);
  finally
    List.Free;
  end;

  Restored := DeserializeList(Json, @CreateUserInstance);
  try
    CheckEquals(2, Restored.Count, 'Expected 2 restored items');
    CheckEquals(1, User(Restored[0]).UserId, 'First UserId');
    CheckEquals('One', string(User(Restored[0]).DisplayName), 'First DisplayName');
    CheckEquals(2, User(Restored[1]).UserId, 'Second UserId');
    CheckEquals('Two', string(User(Restored[1]).DisplayName), 'Second DisplayName');
  finally
    Restored.Free;
  end;
end;

procedure TTestUJson.DeserializeList_NotAnArray;
begin
  DeserializeList('{"a":1}', @CreateUserInstance);
end;

procedure TTestUJson.DeserializeList_NonArrayJson_Raises;
begin
  CheckException(DeserializeList_NotAnArray, Exception, 'Expected exception when JSON is not an array');
end;

procedure TTestUJson.DeserializeList_NoFactory;
begin
  DeserializeList('[]', nil);
end;

procedure TTestUJson.DeserializeList_MissingFactory_Raises;
begin
  CheckException(DeserializeList_NoFactory, Exception, 'Expected exception when item factory is nil');
end;

procedure TTestUJson.EscapeJSONString_EscapesQuotesAndBackslashes;
begin
  CheckEquals('\"quoted\" and \\backslash\\', EscapeJSONString('"quoted" and \backslash\'));
end;

procedure TTestUJson.EscapeJSONString_EscapesControlCharacters;
begin
  CheckEquals('line1\r\nline2\ttab', EscapeJSONString('line1' + #13#10 + 'line2' + #9 + 'tab'));
end;

procedure TTestUJson.EscapeJSONString_LeavesPlainTextUnchanged;
begin
  CheckEquals('Hello World 123', EscapeJSONString('Hello World 123'));
end;

initialization
  RegisterTest(TTestUJson.Suite);

end.
