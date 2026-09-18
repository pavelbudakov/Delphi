unit uRestClient;

interface
uses Windows, Forms, SysUtils, Classes, Contnrs, IdBaseComponent, IdComponent,
  IdHTTP, IdExceptionCore, StrUtils,
  IdContext, StdCtrls, uDTO, uJson, uSettings, uConstants;

Type
  TRestClient = class
  private
    FClient: TIdHTTP;
  public
    constructor Create;
    destructor Destroy; override;
    function GetResponse(Path: String): WideString;
  end;

implementation

{ TRestClient }

constructor TRestClient.Create;
begin
  FClient := TIdHTTP.Create(nil);
  FClient.ConnectTimeout := 5;
  FClient.Request.ContentType := 'application/json';
end;

destructor TRestClient.Destroy;
begin
  FreeAndNil(FClient);
  inherited;
end;

function DecodeToWideString(const S: AnsiString; CodePage: Integer): WideString;
var Len: Integer;
begin
  Len := MultiByteToWideChar(CodePage, 0, PAnsiChar(S), Length(S), nil, 0);
  SetLength(Result, Len);
  if Len > 0 then
    MultiByteToWideChar(CodePage, 0, PAnsiChar(S), Length(S), PWideChar(Result), Len);
end;

function TRestClient.GetResponse(Path: String): WideString;
var URL : String;
    pResponseStream: TStringStream;
begin
  URL := AppSettings.URL + Path;
  pResponseStream := TStringStream.Create('');
  try
    FClient.Get(URL, pResponseStream);
    Result := UTF8Decode(pResponseStream.DataString);
  finally
    FreeAndNil(pResponseStream);
  end;
end;

end.
