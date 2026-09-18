unit TestUUtils;

interface

uses
  TestFramework, SysUtils, Classes, uUtils;

type
  TTestUUtils = class(TTestCase)
  private
    FTempFile: string;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SaveAndLoad_RoundTrip_ReturnsSameContent;
    procedure SaveStringToFile_TrimsLeadingAndTrailingWhitespace;
    procedure LoadStringFromFile_TrimsResult;
    procedure LoadStringFromFile_MissingFile_RaisesException;
  end;

implementation

procedure TTestUUtils.SetUp;
begin
  FTempFile := ExtractFilePath(ParamStr(0)) + 'dunit_uutils_test.tmp';
  if FileExists(FTempFile) then
    DeleteFile(FTempFile);
end;

procedure TTestUUtils.TearDown;
begin
  if FileExists(FTempFile) then
    DeleteFile(FTempFile);
end;

procedure TTestUUtils.SaveAndLoad_RoundTrip_ReturnsSameContent;
begin
  SaveStringToFile(FTempFile, 'Hello' + #13#10 + 'World');
  CheckEquals('Hello' + #13#10 + 'World', LoadStringFromFile(FTempFile));
end;

procedure TTestUUtils.SaveStringToFile_TrimsLeadingAndTrailingWhitespace;
begin
  SaveStringToFile(FTempFile, '   Padded content   ');
  CheckEquals('Padded content', LoadStringFromFile(FTempFile));
end;

procedure TTestUUtils.LoadStringFromFile_TrimsResult;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := 'Config Value' + sLineBreak + sLineBreak;
    SL.SaveToFile(FTempFile);
  finally
    SL.Free;
  end;

  CheckEquals('Config Value', LoadStringFromFile(FTempFile));
end;

procedure TTestUUtils.LoadStringFromFile_MissingFile_RaisesException;
begin
  ExpectedException := EFOpenError;
  LoadStringFromFile(FTempFile + '.missing');
end;

initialization
  RegisterTest(TTestUUtils.Suite);

end.
