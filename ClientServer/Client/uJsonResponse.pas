{$M+}
unit uJsonResponse;

interface
uses Classes, SysUtils, Contnrs, uDTO;

Type
  TJsonError = class(TPersistent)
  private
    FCode: String;
    FPath: String;
  published
    property Code: String read FCode write FCode;
    property Path: String read FPath write FPath;
  end;

  TJsonResponse = class(TPersistent)
  private
    FIsSuccess: Boolean;
    FIsFailure: Boolean;
    FRecordCount: Integer;
    FError: TJsonError;
    FJsonData: TObjectList;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property IsSuccess: Boolean read FIsSuccess write FIsSuccess;
    property IsFailure: Boolean read FIsFailure write FIsFailure;
    property RecordCount: Integer read FRecordCount write FRecordCount;
    property Error: TJsonError read FError write FError;
    property Data: TObjectList read FJsonData write FJsonData;
  end;


function CreateJsonResponseInstance: TObject;
function CreateErrorInstance: TObject;

implementation

function CreateJsonResponseInstance: TObject;
begin
  Result := TJsonResponse.Create;
end;

function CreateErrorInstance: TObject;
begin
  Result := TJsonError.Create;
end;

{ TJsonResponse }

constructor TJsonResponse.Create;
begin
  inherited;
  FError := TJsonError.Create;
  FJsonData := TObjectList.Create(True);
end;

destructor TJsonResponse.Destroy;
begin
  FreeAndNil(FJsonData);
  FreeAndNil(FError);
  inherited;
end;

initialization
  RegisterClasses([TJsonResponse]);
end.
