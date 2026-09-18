unit uMSSQL;

interface

uses Dialogs, TypInfo, SysUtils, Classes, Contnrs, IdCoderMIME, ActiveX, DB, ADODB,
     uJson, uConstants;

Type
  TMSSQLHandler = class
  private
    FConnection : TADOConnection;
    function GetIsActive: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function Connect(ConnectionString: String; out ErrorMessage:String): Boolean;
    procedure Disconnect;

    function LoadObjects(Sql: String; Params: TStringList; AClass: TClass; out RecordCount: Integer): String;

    property Active: Boolean read GetIsActive;
  end;

function MSSQLConnectionSuccessful(ConnectionString : String): Boolean;
function PreparedConnectionString(ConnectionString : String) : String;

implementation

{ TMSSQLHandler }

constructor TMSSQLHandler.Create;
begin
  inherited Create;
  CoInitialize(nil);
  FConnection := TADOConnection.Create(nil);
  FConnection.IsolationLevel := ilReadCommitted;
  FConnection.ConnectionTimeout := 30;
  FConnection.CommandTimeout := 30;
  FConnection.CursorLocation := clUseServer;
end;

destructor TMSSQLHandler.Destroy;
begin
  Disconnect;
  FreeAndNil(FConnection);
  CoUninitialize;
  inherited;
end;

function TMSSQLHandler.Connect(ConnectionString: String;
  out ErrorMessage: String): Boolean;
begin
  Disconnect;
  ErrorMessage := '';
  FConnection.ConnectionString := ConnectionString;
  try
    FConnection.Open;
    Result := True;
  except
    on E: Exception do begin
      ErrorMessage := E.Message;
      Result := False;
    end;
  end;
end;

procedure TMSSQLHandler.Disconnect;
begin
  if FConnection.Connected
    then FConnection.Close;
end;

function TMSSQLHandler.GetIsActive: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.Connected;
end;

function TMSSQLHandler.LoadObjects(Sql: String; Params: TStringList;
  AClass: TClass; out RecordCount: Integer): String;
var
  List: TObjectList;
  Obj: TObject;
  i: Integer;
  FieldName: string;
  PropInfo: PPropInfo;
  Query : TADOQuery;
  ErrorMessage: String;
  pMS : TMemoryStream;
  pStringMS: TStringStream;
  pEncoder : TIdEncoderMIME;
  sData : String;
begin
  Result := '';
  if not FConnection.Connected then begin
    if not Connect(FConnection.ConnectionString, ErrorMessage)
      then Exit;
  end;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Sql;

    if Assigned(Params) then
    begin
      for i := 0 to Pred(Params.Count) do begin
        Query.Parameters.ParamByName(Params.Names[i]).Value := Params.ValueFromIndex[i];
      end;
    end;

    List := TObjectList.Create(True);
    try
      Query.Open;
      try
        while not Query.Eof do begin
          Obj := AClass.Create;
          try
            for i := 0 to Pred(Query.FieldCount) do begin
              FieldName := Query.Fields[i].FieldName;
              PropInfo := GetPropInfo(Obj, FieldName);
              if PropInfo <> nil then begin
                if (Query.Fields[i].IsBlob) then begin
                  if (not Query.Fields[i].IsNull) then begin
                    pMS := TMemoryStream.Create;
                    pStringMS := TStringStream.Create('');
                    pEncoder := TIdEncoderMIME.Create(nil);
                    try
                      TBlobField(Query.Fields[i]).SaveToStream(pMS);
                      pMS.Position := 0;

                      pEncoder.Encode(pMS, pStringMS);
                      pStringMS.Position := 0;

                      sData := pStringMS.DataString;

                      SetPropValue(Obj, FieldName, sData);
                      //SetPropValue(Obj, FieldName, '');

                    finally
                      FreeAndNIl(pEncoder);
                      FreeAndNil(pStringMS);
                      FreeAndNil(pMS);
                    end;
                  end else begin
                    SetPropValue(Obj, FieldName, '');
                  end;
                end else begin
                  SetPropValue(Obj, FieldName, Query.Fields[i].AsString);
                end;
              end;
            end;
            List.Add(Obj);
          except
            FreeAndNil(Obj);
            raise;
          end;
          Query.Next;
        end;
      finally
        Query.Close;
      end;

      RecordCount := list.Count;
      Result := SerializeList(List);
    finally
      FreeAndNil(List);
      Disconnect;
    end;
  finally
    FreeAndNil(Query);
  end;
end;

function PreparedConnectionString(ConnectionString : String) : String;
var s : String;
    i : Integer;
begin
  s := ConnectionString;
  for i := Length(s) downto 1 do begin
    if s[i] <= #13
      then Delete(s, i, 1);
  end;
  Result := s;
end;

function MSSQLConnectionSuccessful(ConnectionString : String): Boolean;
var
  pConnection: TADOConnection;
begin
  Result := False;

  pConnection := TADOConnection.Create(nil);
  pConnection.ConnectionTimeout := 5;
  try
    try
      pConnection.ConnectionString := PreparedConnectionString(ConnectionString);
      pConnection.Open;
      Result := pConnection.Connected;
    except
      on E: Exception do begin
        ShowMessage(E.Message);
      end;
    end;
  finally
    if pConnection.Connected
      then pConnection.Connected := False;
    FreeAndNil(pConnection);
  end;
end;



end.
