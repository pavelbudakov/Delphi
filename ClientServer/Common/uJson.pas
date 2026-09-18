unit uJson;

interface

uses
  Classes, SysUtils, TypInfo, Contnrs;
Type
  TClassFactory = function: TObject;

  function SerializeObject(Obj: TObject): string;
  function SerializeList(List: TObjectList): string;
  function DeserializeObject(const Json: string; AClassFactory: TClassFactory;
    ListItemFactory: TClassFactory = nil): TObject;
  function DeserializeList(const Json: string; ItemFactory: TClassFactory): TObjectList;
  function EscapeJSONString(const S: string): string;

implementation


type
  TJsonValue = class
  end;

  TJsonString = class(TJsonValue)
  public
    Value: string;
    constructor Create(const AValue: string);
  end;

  TJsonNumber = class(TJsonValue)
  public
    Value: Double;
    constructor Create(const AValue: Double);
    function AsInteger: Integer;
    function AsFloat: Double;
  end;

  TJsonBoolean = class(TJsonValue)
  public
    Value: Boolean;
    constructor Create(const AValue: Boolean);
  end;

  TJsonNull = class(TJsonValue)
  end;

  TJsonObject = class(TJsonValue)
  private
    FItems: TStringList;
    FValues: TList;
    function GetValue(const Name: string): TJsonValue;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Name: string; Value: TJsonValue);
    function Contains(const Name: string): Boolean;
    property Items[const Name: string]: TJsonValue read GetValue; default;
    function Count: Integer;
    function Names(Index: Integer): string;
    function Values(Index: Integer): TJsonValue;
  end;

  TJsonArray = class(TJsonValue)
  private
    FItems: TList;
    function GetItem(Index: Integer): TJsonValue;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Value: TJsonValue);
    function Count: Integer;
    property Items[Index: Integer]: TJsonValue read GetItem; default;
  end;

  TJsonParser = class
  private
    FText: string;
    FPos: Integer;
    function ParseValue: TJsonValue;
    function ParseObject: TJsonObject;
    function ParseArray: TJsonArray;
    function ParseString: string;
    function ParseNumber: Double;
    procedure SkipWhitespace;
    function NextChar: Char;
    function PeekChar: Char;
  public
    class function Parse(const Json: string): TJsonValue;
  end;

{  TJsonString  }
constructor TJsonString.Create(const AValue: string);
begin
  Value := AValue;
end;

{  TJsonNumber  }
constructor TJsonNumber.Create(const AValue: Double);
begin
  Value := AValue;
end;

function TJsonNumber.AsInteger: Integer;
begin
  Result := Round(Value);
end;

function TJsonNumber.AsFloat: Double;
begin
  Result := Value;
end;

{  TJsonBoolean  }
constructor TJsonBoolean.Create(const AValue: Boolean);
begin
  Value := AValue;
end;

{  TJsonObject  }
constructor TJsonObject.Create;
begin
  FItems := TStringList.Create;
  FValues := TList.Create;
end;

destructor TJsonObject.Destroy;
var
  i: Integer;
begin
  for i := 0 to Pred(FValues.Count)
    do TObject(FValues[i]).Free;
  FValues.Free;
  FItems.Free;
  inherited;
end;

procedure TJsonObject.Add(const Name: string; Value: TJsonValue);
begin
  FItems.Add(Name);
  FValues.Add(Value);
end;

function TJsonObject.Contains(const Name: string): Boolean;
begin
  Result := FItems.IndexOf(Name) >= 0;
end;

function TJsonObject.GetValue(const Name: string): TJsonValue;
var
  idx: Integer;
begin
  idx := FItems.IndexOf(Name);
  if idx >= 0 then
    Result := TJsonValue(FValues[idx])
  else
    Result := nil;
end;

function TJsonObject.Count: Integer;
begin
  Result := FItems.Count;
end;

function TJsonObject.Names(Index: Integer): string;
begin
  Result := FItems[Index];
end;

function TJsonObject.Values(Index: Integer): TJsonValue;
begin
  Result := TJsonValue(FValues[Index]);
end;

{  TJsonArray  }
constructor TJsonArray.Create;
begin
  FItems := TList.Create;
end;

destructor TJsonArray.Destroy;
var
  i: Integer;
begin
  for i := 0 to Pred(FItems.Count)
    do TObject(FItems[i]).Free;
  FItems.Free;
  inherited;
end;

procedure TJsonArray.Add(Value: TJsonValue);
begin
  FItems.Add(Value);
end;

function TJsonArray.Count: Integer;
begin
  Result := FItems.Count;
end;

function TJsonArray.GetItem(Index: Integer): TJsonValue;
begin
  Result := TJsonValue(FItems[Index]);
end;

{  TJsonParser  }
class function TJsonParser.Parse(const Json: string): TJsonValue;
var
  Parser: TJsonParser;
begin
  Parser := TJsonParser.Create;
  try
    Parser.FText := Json;
    Parser.FPos := 1;
    Result := Parser.ParseValue;
  finally
    Parser.Free;
  end;
end;

function TJsonParser.ParseValue: TJsonValue;
var
  c: Char;
begin
  SkipWhitespace;
  c := PeekChar;
  case c of
    '{': Result := ParseObject;
    '[': Result := ParseArray;
    '"': Result := TJsonString.Create(ParseString);
    't', 'f':
      begin
        if Copy(FText, FPos, 4) = 'true' then
        begin
          Inc(FPos, 4);
          Result := TJsonBoolean.Create(True);
        end
        else if Copy(FText, FPos, 5) = 'false' then
        begin
          Inc(FPos, 5);
          Result := TJsonBoolean.Create(False);
        end
        else
          raise Exception.Create('Invalid JSON boolean');
      end;
    'n':
      begin
        if Copy(FText, FPos, 4) = 'null' then
        begin
          Inc(FPos, 4);
          Result := TJsonNull.Create;
        end
        else
          raise Exception.Create('Invalid JSON null');
      end;
    else
      if c in ['-', '0'..'9'] then
        Result := TJsonNumber.Create(ParseNumber)
      else
        raise Exception.CreateFmt('Unexpected character in JSON: %s', [c]);
  end;
end;

function TJsonParser.ParseObject: TJsonObject;
var
  Name: string;
  Value: TJsonValue;
begin
  Result := TJsonObject.Create;
  NextChar;
  SkipWhitespace;
  if PeekChar = '}' then
  begin
    NextChar;
    Exit;
  end;
  repeat
    SkipWhitespace;
    if PeekChar <> '"' then
      raise Exception.Create('Expected string key in JSON object');
    Name := ParseString;
    SkipWhitespace;
    if NextChar <> ':' then
      raise Exception.Create('Expected ":" in JSON object');
    Value := ParseValue;
    Result.Add(Name, Value);
    SkipWhitespace;
    if PeekChar = ',' then
      NextChar
    else
      Break;
  until False;
  SkipWhitespace;
  if NextChar <> '}' then
    raise Exception.Create('Expected "}" in JSON object');
end;

function TJsonParser.ParseArray: TJsonArray;
var
  Value: TJsonValue;
begin
  Result := TJsonArray.Create;
  NextChar;
  SkipWhitespace;
  if PeekChar = ']' then
  begin
    NextChar;
    Exit;
  end;
  repeat
    Value := ParseValue;
    Result.Add(Value);
    SkipWhitespace;
    if PeekChar = ',' then
      NextChar
    else
      Break;
  until False;
  SkipWhitespace;
  if NextChar <> ']' then
    raise Exception.Create('Expected "]" in JSON array');
end;

function TJsonParser.ParseString: string;
var
  c: Char;
begin
  NextChar;
  Result := '';
  while FPos <= Length(FText) do
  begin
    c := NextChar;
    if c = '"' then
      Break
    else if c = '\' then
    begin
      c := NextChar;
      case c of
        '"': Result := Result + '"';
        '\': Result := Result + '\';
        '/': Result := Result + '/';
        'b': Result := Result + #8;
        'f': Result := Result + #12;
        'n': Result := Result + #10;
        'r': Result := Result + #13;
        't': Result := Result + #9;
        'u':
          begin
            Inc(FPos, 4);
            Result := Result + '?';
          end;
      end;
    end
    else
      Result := Result + c;
  end;
end;

function TJsonParser.ParseNumber: Double;
var
  StartPos: Integer;
  S: string;
begin
  StartPos := FPos;
  while (FPos <= Length(FText)) and (FText[FPos] in ['-', '+', '0'..'9', '.', 'e', 'E']) do
    Inc(FPos);
  S := Copy(FText, StartPos, FPos - StartPos);
  Result := StrToFloat(S);
end;

procedure TJsonParser.SkipWhitespace;
begin
  while (FPos <= Length(FText)) and (FText[FPos] in [#9, #10, #13, #32]) do
    Inc(FPos);
end;

function TJsonParser.NextChar: Char;
begin
  if FPos <= Length(FText) then
  begin
    Result := FText[FPos];
    Inc(FPos);
  end
  else
    Result := #0;
end;

function TJsonParser.PeekChar: Char;
begin
  if FPos <= Length(FText) then
    Result := FText[FPos]
  else
    Result := #0;
end;

function EscapeJSONString(const S: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    case c of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
      else
        if Ord(c) < 32 then
          Result := Result + Format('\u%.4x', [Ord(c)])
        else
          Result := Result + c;
    end;
  end;
end;

function SerializeObject(Obj: TObject): string;
var
  PropCount, i: Integer;
  PropList: PPropList;
  PropInfo: PPropInfo;
  PropType: TTypeKind;
  JsonParts: TStringList;
begin
  JsonParts := TStringList.Create;
  try
    PropCount := GetPropList(PTypeInfo(Obj.ClassInfo), PropList);
    try
      for i := 0 to Pred(PropCount) do begin
        PropInfo := PropList^[i];
        PropType := PropInfo.PropType^^.Kind;
        case PropType of
          tkInteger, tkInt64, tkChar, tkWChar:
            JsonParts.Add(Format('"%s":%d', [PropInfo.Name, GetOrdProp(Obj, PropInfo)]));
          tkEnumeration: begin
              if (PropInfo.PropType^^.Name = 'Boolean') or
                 (PropInfo.PropType^^.Name = 'ByteBool') or
                 (PropInfo.PropType^^.Name = 'WordBool') or
                 (PropInfo.PropType^^.Name = 'LongBool') then
              begin
                if GetOrdProp(Obj, PropInfo) <> 0
                  then JsonParts.Add(Format('"%s":true', [PropInfo.Name]))
                  else JsonParts.Add(Format('"%s":false', [PropInfo.Name]));
              end else begin
                JsonParts.Add(Format('"%s":%d', [PropInfo.Name, GetOrdProp(Obj, PropInfo)]));
              end;
            end;
            tkFloat:
            JsonParts.Add(Format('"%s":%s', [PropInfo.Name, FloatToStr(GetFloatProp(Obj, PropInfo))]));
          tkString, tkLString, tkWString:
            JsonParts.Add(Format('"%s":"%s"', [PropInfo.Name, EscapeJSONString(GetStrProp(Obj, PropInfo))]));
          tkClass:
            begin
              if GetObjectProp(Obj, PropInfo) is TObjectList then
                JsonParts.Add(Format('"%s":%s', [PropInfo.Name, SerializeList(TObjectList(GetObjectProp(Obj, PropInfo)))]))
              else
                JsonParts.Add(Format('"%s":%s', [PropInfo.Name, SerializeObject(GetObjectProp(Obj, PropInfo))]));
            end;
        end;
      end;
    finally
      FreeMem(PropList);
    end;

    Result := '{';
    for i := 0 to Pred(JsonParts.Count) do begin
      if i > 0
        then Result := Result + ',';
      Result := Result + JsonParts[i];
    end;
    Result := Result + '}';

  finally
    JsonParts.Free;
  end;
end;

function SerializeList(List: TObjectList): string;
var
  i: Integer;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for i := 0 to Pred(List.Count)
      do Parts.Add(SerializeObject(List[i]));
    Result := '[';
    for i := 0 to Pred(Parts.Count) do begin
      if (i > 0) then Result := Result + ',';
      Result := Result + Parts[i];
    end;
    Result := Result + ']';
  finally
    Parts.Free;
  end;
end;

procedure DeserializeInto(JsonValue: TJsonValue; Obj: TObject; ListItemFactory: TClassFactory);
var
  i, j, PropCount: Integer;
  PropList: PPropList;
  PropInfo: PPropInfo;
  JsonObj: TJsonObject;
  JsonArr: TJsonArray;
  ChildObj: TObject;
  List: TObjectList;
begin
  if not (JsonValue is TJsonObject) then
    raise Exception.Create('JSON value must be an object for deserialization into an existing instance.');

  JsonObj := TJsonObject(JsonValue);
  PropCount := GetPropList(PTypeInfo(Obj.ClassInfo), PropList);
  try
    for i := 0 to Pred(PropCount) do begin
      PropInfo := PropList^[i];
      if not JsonObj.Contains(PropInfo.Name) then Continue;

      case PropInfo.PropType^^.Kind of
        tkInteger, tkInt64, tkChar, tkWChar, tkEnumeration:
          begin
            if JsonObj[PropInfo.Name] is TJsonBoolean then
              SetOrdProp(Obj, PropInfo, Ord(TJsonBoolean(JsonObj[PropInfo.Name]).Value))
            else if JsonObj[PropInfo.Name] is TJsonNumber then
              SetOrdProp(Obj, PropInfo, TJsonNumber(JsonObj[PropInfo.Name]).AsInteger)
            else
              raise Exception.CreateFmt(
                'Property %s: expected boolean or number, got %s',
                [PropInfo.Name, JsonObj[PropInfo.Name].ClassName]
              );
          end;
        tkFloat:
          SetFloatProp(Obj, PropInfo, TJsonNumber(JsonObj[PropInfo.Name]).AsFloat);

        tkString, tkLString, tkWString:
          SetStrProp(Obj, PropInfo, TJsonString(JsonObj[PropInfo.Name]).Value);

        tkClass:
          begin
            if JsonObj[PropInfo.Name] is TJsonObject then
            begin
              ChildObj := GetObjectProp(Obj, PropInfo);
              if not Assigned(ChildObj) then
                raise Exception.CreateFmt(
                  'Property "%s" is not initialized. Create it in the constructor.', [PropInfo.Name]);
              DeserializeInto(JsonObj[PropInfo.Name], ChildObj, nil);
            end
            else if JsonObj[PropInfo.Name] is TJsonArray then
            begin
              ChildObj := GetObjectProp(Obj, PropInfo);
              if not Assigned(ChildObj) then
                raise Exception.CreateFmt(
                  'Property "%s" is not initialized. Create it in the constructor.', [PropInfo.Name]);
              if not (ChildObj is TObjectList) then
                raise Exception.CreateFmt('Property "%s" is not a TObjectList.', [PropInfo.Name]);

              List := TObjectList(ChildObj);
              List.Clear;
              JsonArr := TJsonArray(JsonObj[PropInfo.Name]);

              if not Assigned(ListItemFactory) then
                raise Exception.CreateFmt(
                  'No factory provided for list items of property "%s".', [PropInfo.Name]);

              for j := 0 to Pred(JsonArr.Count) do begin
                ChildObj := ListItemFactory();
                DeserializeInto(JsonArr[j], ChildObj, nil);
                List.Add(ChildObj);
              end;
            end;
          end;
      end;
    end;
  finally
    FreeMem(PropList);
  end;
end;

function DeserializeObject(const Json: string; AClassFactory: TClassFactory;
  ListItemFactory: TClassFactory = nil): TObject;
var
  JsonValue: TJsonValue;
begin
  Result := nil;
  JsonValue := TJsonParser.Parse(Json);
  try
    if not Assigned(AClassFactory) then
      raise Exception.Create('Class factory is required.');
    Result := AClassFactory();
    DeserializeInto(JsonValue, Result, ListItemFactory);
  finally
    JsonValue.Free;
  end;
end;

function DeserializeList(const Json: string; ItemFactory: TClassFactory): TObjectList;
var
  JsonValue: TJsonValue;
  JsonArr: TJsonArray;
  i: Integer;
  Item: TObject;
begin
  Result := nil;
  JsonValue := TJsonParser.Parse(Json);
  try
    if not (JsonValue is TJsonArray) then
      raise Exception.Create('JSON value must be an array.');
    if not Assigned(ItemFactory) then
      raise Exception.Create('Item factory is required.');

    Result := TObjectList.Create(True);
    JsonArr := TJsonArray(JsonValue);
    for i := 0 to Pred(JsonArr.Count) do begin
      Item := ItemFactory();
      DeserializeInto(JsonArr[i], Item, nil);
      Result.Add(Item);
    end;
  finally
    JsonValue.Free;
  end;
end;

end.
