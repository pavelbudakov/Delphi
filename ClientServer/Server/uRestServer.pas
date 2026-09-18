unit uRestServer;

interface
uses Windows, Forms, SysUtils, Classes, Contnrs, IdBaseComponent, IdComponent,
  IdCustomTCPServer, IdCustomHTTPServer, IdHTTPServer, IdExceptionCore, StrUtils,
  IdContext, StdCtrls, uRestRoutes, uMSSQL, uDTO, uJson, uSettings, uConstants;

Type
  TRestServer = class
  private
    FServer: TIdHTTPServer;
    FRestRouter: TRestRouter;
    FShuttingDown: Boolean;
    FActiveRequests: Integer;
    procedure ProcessCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure ProcessCommandOther(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    function GetIsActive: Boolean;
    procedure SetIsActive(const Value: Boolean);
    function GeneratePayload(iCode: Integer; sDescription : WideString; RecordCount : Integer) : WideString;
    procedure StopServerGracefully;
    procedure ProcessOnConnect(AContext: TIdContext);
    procedure DisconnectAllClients;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterRoute(Path: String; HttpMethod: THTTPCommandType; Handler: TRouteHandler);
    property Active: Boolean read GetIsActive write SetIsActive;
  end;

implementation

{ TRestServer }

constructor TRestServer.Create;
begin
  inherited;
  FRestRouter:= TRestRouter.Create;
  FServer := TIdHTTPServer.Create(nil);
  FServer.DefaultPort := AppSettings.Port;
  FServer.KeepAlive := False;
  FServer.OnCommandOther := ProcessCommandOther;
  FServer.OnCommandGet := ProcessCommandGet;
  FServer.OnConnect := ProcessOnConnect;
end;

destructor TRestServer.Destroy;
begin
  Active := False;
  FreeAndNil(FServer);
  FreeAndNil(FRestRouter);
  inherited;
end;

procedure TRestServer.RegisterRoute(Path: String; HttpMethod: THTTPCommandType; Handler: TRouteHandler);
begin
  FRestRouter.RegisterRoute(Path, HTTPMethod, Handler);
end;

const PayloadPrefix: WideString = '{"isSuccess": #SUCCESS#, "isFailure": #FAILURE#, "recordCount": #TOTALRECORDS#, "info": {"code": "#ERRORCODE#", "path": "#PATH#"}, "data": ';//#DATA# ] }';
      PayloadSuffix: WideString = ' }';

function TRestServer.GeneratePayload(iCode: Integer; sDescription: WideString; RecordCount : Integer) : WideString;
begin
  Result := PayloadPrefix;
  Result := StringReplace(Result, '#SUCCESS#', IfThen(iCode = 200, 'true', 'false'), [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '#FAILURE#', IfThen(iCode <> 200, 'true', 'false'), [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '#ERRORCODE#', IntToStr(iCode), [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '#PATH#', EscapeJSONString(sDescription), [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '#TOTALRECORDS#', IntToStr(RecordCount), [rfReplaceAll, rfIgnoreCase]);
end;

procedure TRestServer.ProcessOnConnect(AContext: TIdContext);
begin
  if FShuttingDown then begin
    AContext.Connection.Disconnect;
    Abort;
  end;
end;

procedure TRestServer.ProcessCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var Handler: TRouteHandler;
    Params: TStringList;
    ResponseContent: String;
    RecordCount: Integer;
begin
  InterlockedIncrement(FActiveRequests);
  try
    if FShuttingDown then begin
      AResponseInfo.ResponseNo := 503;
      AResponseInfo.CustomHeaders.Values['Retry-After'] := '5';
      AResponseInfo.CloseConnection := True;
      Exit;
    end;

    if FRestRouter.TryMatch(ARequestInfo.CommandType, ARequestInfo.URI, Params, Handler) then begin
      try
        try
          ResponseContent := Handler(Params, ARequestInfo.URI, RecordCount);
          AResponseInfo.ContentType := 'application/json';
          AResponseInfo.CharSet := 'UTF-8';
          AResponseInfo.ResponseNo := 200;

          AResponseInfo.ContentText := GeneratePayload(200, ARequestInfo.URI, RecordCount) + ResponseContent + PayloadSuffix;
        except
          on E: Exception do begin
            AResponseInfo.ContentType := 'application/json';
            AResponseInfo.CharSet := 'UTF-8';
            AResponseInfo.ResponseNo := 500;
            AResponseInfo.ContentText := GeneratePayload(500, E.Message, 0) + 'null' + PayloadSuffix;
          end;
        end;
      finally
        FreeAndNil(Params);
      end;
    end else begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentText := GeneratePayload(404, ARequestInfo.URI, 0) + 'null' + PayloadSuffix;
    end;
  finally
    InterlockedDecrement(FActiveRequests);
    AResponseInfo.CloseConnection := True;
//  if FShuttingDown
//    then AResponseInfo.CloseConnection := True;
  end;
end;

procedure TRestServer.ProcessCommandOther(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var Handler: TRouteHandler;
    Params: TStringList;
    ResponseContent: WideString;
    RecordCount: Integer;
begin
  InterlockedIncrement(FActiveRequests);
  try
    if FShuttingDown then begin
      AResponseInfo.ResponseNo := 503;
      AResponseInfo.CustomHeaders.Values['Retry-After'] := '5';
      AResponseInfo.CloseConnection := True;
      Exit;
    end;

    if FRestRouter.TryMatch(ARequestInfo.CommandType, ARequestInfo.URI, Params, Handler) then begin
      try
        try
          ResponseContent := Handler( Params, ARequestInfo.URI, RecordCount);
          AResponseInfo.ContentType := 'application/json';
          AResponseInfo.CharSet := 'UTF-8';
          AResponseInfo.ResponseNo := 200;

          AResponseInfo.ContentText := GeneratePayload(200, ARequestInfo.URI, RecordCount) + ResponseContent + PayloadSuffix;
        except
          on E: Exception do begin
            AResponseInfo.ContentType := 'application/json';
            AResponseInfo.CharSet := 'UTF-8';
            AResponseInfo.ResponseNo := 500;
            AResponseInfo.ContentText := GeneratePayload(500, E.Message, 0) + 'null' + PayloadSuffix;
          end;
        end;
      finally
        FreeAndNil(Params);
      end;
    end else begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentText := GeneratePayload(404, ARequestInfo.URI, 0) + 'null' + PayloadSuffix;
    end;

  finally
    InterlockedDecrement(FActiveRequests);
    AResponseInfo.CloseConnection := True;
//  if FShuttingDown
//    then AResponseInfo.CloseConnection := True;
  end;
end;
(*
const Payload: WideString = '{"isSuccess": #SUCCESS#, "isFailure": #FAILURE#, "error": {"code": "#ERRORCODE#", "description": "#ERRORDESCRIPTION#"}, "data": [ #DATA# ] }';

function TRestServer.GeneratePayload(iCode: Integer; sDescription, sContent: WideString) : WideString;
begin
  Result := Payload;
  Result := WideStringReplace(Result, '#SUCCESS#', IfThen(iCode = 200, 'true', 'false'), [rfReplaceAll, rfIgnoreCase]);
  Result := WideStringReplace(Result, '#FAILURE#', IfThen(iCode <> 200, 'true', 'false'), [rfReplaceAll, rfIgnoreCase]);
  Result := WideStringReplace(Result, '#ERRORCODE#', IntToStr(iCode), [rfReplaceAll, rfIgnoreCase]);
  Result := WideStringReplace(Result, '#ERRORDESCRIPTION#', sDescription, [rfReplaceAll, rfIgnoreCase]);
  Result := WideStringReplace(Result, '#DATA#', sContent, [rfReplaceAll, rfIgnoreCase]);
end;
*)

function TRestServer.GetIsActive: Boolean;
begin
  Result := (FServer <> nil) and (FServer.Active);
end;

procedure TRestServer.DisconnectAllClients;
var
  List: TList;
  i: Integer;
  Context: TIdContext;
begin
  List := FServer.Contexts.LockList;
  try
    for i := Pred(List.Count) downto 0 do begin
      Context := TIdContext(List[i]);
      if Context = nil then Continue;
      try
        Context.Connection.Disconnect;
      except
        // Ignore any socket errors during disconnection
      end;
    end;
  finally
    FServer.Contexts.UnlockList;
  end;
end;

procedure TRestServer.StopServerGracefully;
var Timeout: Cardinal;
begin
  if not FServer.Active then Exit;

  FShuttingDown := True;
  try
    try
      Timeout := GetTickCount + 30000;
      while (FActiveRequests > 0) and (GetTickCount < Timeout) do begin
        Sleep(100);
        Application.ProcessMessages;
      end;
      DisconnectAllClients;
      Sleep(200);
    except
    end;
    
    FServer.Active := False;
  finally
    FShuttingDown := False;
  end;
end;

procedure TRestServer.SetIsActive(const Value: Boolean);
begin
  if (FServer <> nil) and (FServer.Active <> Value) then begin
    if (not Value) then begin
      StopServerGracefully;
    end else begin
      FServer.Bindings.Clear;
      FServer.DefaultPort := AppSettings.Port;
      FServer.Active := True;
      FShuttingDown := False;
    end;
  end;
end;

end.
