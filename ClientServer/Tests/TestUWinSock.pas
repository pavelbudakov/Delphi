unit TestUWinSock;

interface

uses
  TestFramework, uWinSock;

type
  TTestWSIsPortAvailable = class(TTestCase)
  published
    procedure PortZero_ReturnsFalse;
  end;

implementation

procedure TTestWSIsPortAvailable.PortZero_ReturnsFalse;
begin
  CheckFalse(WSIsPortAvailable(0), 'Port 0 is not a valid port and must be reported as unavailable');
end;

initialization
  RegisterTest(TTestWSIsPortAvailable.Suite);

end.
