{$M+}

unit uSettings;

interface
uses Classes, SysUtils, TypInfo, Contnrs, uConstants, uJson, uUtils;

Type
  TSettings = class(TPersistent)
  private
    FURL: String;
  published
    property URL: String read FURL write FURL;
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
  if FileExists(cCLIENT_CONFIGURATION_FILE) then begin
    try
      json := LoadStringFromFile(cCLIENT_CONFIGURATION_FILE);
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
      SaveStringToFile(cCLIENT_CONFIGURATION_FILE, json);
      Result := True;
    except
    end;
  end;
end;


begin
  LoadSettings;
end.
