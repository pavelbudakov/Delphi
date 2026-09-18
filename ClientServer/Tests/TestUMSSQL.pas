unit TestUMSSQL;

interface

uses
  TestFramework, SysUtils, uMSSQL;

type
  TTestPreparedConnectionString = class(TTestCase)
  published
    procedure RemovesCarriageReturnsAndLineFeeds;
    procedure RemovesTabsAndOtherControlChars;
    procedure PreservesSpacesAndPrintableCharacters;
    procedure EmptyString_ReturnsEmpty;
    procedure NoControlChars_ReturnsUnchanged;
  end;

implementation

procedure TTestPreparedConnectionString.RemovesCarriageReturnsAndLineFeeds;
var
  Input: string;
begin
  Input := 'Provider=SQLOLEDB;' + #13#10 + 'Data Source=SRV;' + #13#10 + 'Initial Catalog=DB;';
  CheckEquals('Provider=SQLOLEDB;Data Source=SRV;Initial Catalog=DB;', PreparedConnectionString(Input));
end;

procedure TTestPreparedConnectionString.RemovesTabsAndOtherControlChars;
var
  Input: string;
begin
  Input := 'A' + #9 + 'B' + #0 + 'C' + #7 + 'D';
  CheckEquals('ABCD', PreparedConnectionString(Input));
end;

procedure TTestPreparedConnectionString.PreservesSpacesAndPrintableCharacters;
var
  Input: string;
begin
  Input := 'User Id=sa; Password=secret!;';
  CheckEquals(Input, PreparedConnectionString(Input));
end;

procedure TTestPreparedConnectionString.EmptyString_ReturnsEmpty;
begin
  CheckEquals('', PreparedConnectionString(''));
end;

procedure TTestPreparedConnectionString.NoControlChars_ReturnsUnchanged;
begin
  CheckEquals('Server=.;Database=test;', PreparedConnectionString('Server=.;Database=test;'));
end;

initialization
  RegisterTest(TTestPreparedConnectionString.Suite);

end.
