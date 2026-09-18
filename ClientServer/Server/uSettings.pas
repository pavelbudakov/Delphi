{$M+}

unit uSettings;

interface
uses Classes, SysUtils, TypInfo, Contnrs, uConstants, uJson, uUtils;

Type
  TSettings = class(TPersistent)
  private
    FPort: Integer;
    FConnectionString: string;
  published
    property Port: Integer read FPort write FPort;
    property ConnectionString: string read FConnectionString write FConnectionString;
  end;

var AppSettings : TSettings = nil;

function LoadSettings: Boolean;
function SaveSettings: Boolean;

implementation

function CreateSettingsInstance: TObject;
begin
  Result := TSettings.Create;
end;

function LoadSettings: Boolean;
var json : String;
begin
  Result := False;
  if FileExists(cCONFIGURATION_FILE) then begin
    try
      json := LoadStringFromFile(cCONFIGURATION_FILE);
      AppSettings := TSettings(DeserializeObject(json, @CreateSettingsInstance));
      Result := True;
    except
    end;
  end;
end;

function SaveSettings: Boolean;
var json : String;
begin
  Result := False;
  if Assigned(AppSettings) then begin
    try
      json := SerializeObject(AppSettings);
      SaveStringToFile(cCONFIGURATION_FILE, json);
      Result := True;
    except
    end;
  end;
end;

begin
  RegisterClasses([TSettings]);
  LoadSettings;
end.
