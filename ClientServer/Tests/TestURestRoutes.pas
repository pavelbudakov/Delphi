unit TestURestRoutes;

interface

uses
  TestFramework, SysUtils, Classes, IdCustomHTTPServer, uRestRoutes;

type
  TTestTRestRouter = class(TTestCase)
  private
    FRouter: TRestRouter;
    FLastHandlerName: string;
    function UsersHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function UserByIdHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function UsersMeHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
    function MultiParamHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TryMatch_StaticRoute_Matches;
    procedure TryMatch_ParamRoute_ExtractsParamValue;
    procedure TryMatch_WrongHttpMethod_ReturnsFalse;
    procedure TryMatch_WrongSegmentCount_ReturnsFalse;
    procedure TryMatch_UnregisteredPath_ReturnsFalse;
    procedure TryMatch_StaticRouteTakesPriorityOverParamRoute;
    procedure TryMatch_MultipleParams_ExtractsAllByName;
    procedure TryMatch_TrailingSlash_StillMatches;
    procedure TryMatch_RepeatedSlashes_AreIgnored;
    procedure TryMatch_CaseInsensitiveStaticSegment_Matches;
  end;

implementation

function TTestTRestRouter.UsersHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
begin
  FLastHandlerName := 'Users';
  RecordCount := 0;
  Result := '';
end;

function TTestTRestRouter.UserByIdHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
begin
  FLastHandlerName := 'UserById';
  RecordCount := 0;
  Result := '';
end;

function TTestTRestRouter.UsersMeHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
begin
  FLastHandlerName := 'UsersMe';
  RecordCount := 0;
  Result := '';
end;

function TTestTRestRouter.MultiParamHandler(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString;
begin
  FLastHandlerName := 'MultiParam';
  RecordCount := 0;
  Result := '';
end;

procedure TTestTRestRouter.SetUp;
begin
  FRouter := TRestRouter.Create;
  FLastHandlerName := '';
end;

procedure TTestTRestRouter.TearDown;
begin
  FreeAndNil(FRouter);
end;

procedure TTestTRestRouter.TryMatch_StaticRoute_Matches;
var
  Params: TStringList;
  Handler: TRouteHandler;
  RC: Integer;
begin
  FRouter.RegisterRoute('/users', hcGET, UsersHandler);

  CheckTrue(FRouter.TryMatch(hcGET, '/users', Params, Handler), 'Expected route to match');
  try
    CheckEquals(0, Params.Count, 'Static route should have no params');
    Handler(Params, '/users', RC);
    CheckEquals('Users', FLastHandlerName, 'Wrong handler matched');
  finally
    Params.Free;
  end;
end;

procedure TTestTRestRouter.TryMatch_ParamRoute_ExtractsParamValue;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users/{id}', hcGET, UserByIdHandler);

  CheckTrue(FRouter.TryMatch(hcGET, '/users/42', Params, Handler), 'Expected param route to match');
  try
    CheckEquals(1, Params.Count, 'Expected one extracted param');
    CheckEquals('42', Params.Values['id'], 'Param "id" should be 42');
  finally
    Params.Free;
  end;
end;

procedure TTestTRestRouter.TryMatch_WrongHttpMethod_ReturnsFalse;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users', hcGET, UsersHandler);
  CheckFalse(FRouter.TryMatch(hcPOST, '/users', Params, Handler), 'POST should not match a GET-only route');
end;

procedure TTestTRestRouter.TryMatch_WrongSegmentCount_ReturnsFalse;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users/{id}', hcGET, UserByIdHandler);
  CheckFalse(FRouter.TryMatch(hcGET, '/users/42/extra', Params, Handler), 'Extra segment should not match');
end;

procedure TTestTRestRouter.TryMatch_UnregisteredPath_ReturnsFalse;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users', hcGET, UsersHandler);
  CheckFalse(FRouter.TryMatch(hcGET, '/groups', Params, Handler), 'Unregistered path should not match');
end;

procedure TTestTRestRouter.TryMatch_StaticRouteTakesPriorityOverParamRoute;
var
  Params: TStringList;
  Handler: TRouteHandler;
  RC: Integer;
begin
  // Registered "wrong way round" on purpose: the param route first.
  FRouter.RegisterRoute('/users/{id}', hcGET, UserByIdHandler);
  FRouter.RegisterRoute('/users/me', hcGET, UsersMeHandler);

  CheckTrue(FRouter.TryMatch(hcGET, '/users/me', Params, Handler), 'Expected a match');
  try
    Handler(Params, '/users/me', RC);
    CheckEquals('UsersMe', FLastHandlerName,
      'Static route should win over param route regardless of registration order');
  finally
    Params.Free;
  end;
end;

procedure TTestTRestRouter.TryMatch_MultipleParams_ExtractsAllByName;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/groups/{groupId}/users/{userId}', hcGET, MultiParamHandler);

  CheckTrue(FRouter.TryMatch(hcGET, '/groups/7/users/99', Params, Handler), 'Expected match');
  try
    CheckEquals(2, Params.Count, 'Expected two params');
    CheckEquals('7', Params.Values['groupId'], 'groupId');
    CheckEquals('99', Params.Values['userId'], 'userId');
  finally
    Params.Free;
  end;
end;

procedure TTestTRestRouter.TryMatch_TrailingSlash_StillMatches;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users', hcGET, UsersHandler);
  CheckTrue(FRouter.TryMatch(hcGET, '/users/', Params, Handler), 'Trailing slash should be ignored');
  Params.Free;
end;

procedure TTestTRestRouter.TryMatch_RepeatedSlashes_AreIgnored;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/users/{id}', hcGET, UserByIdHandler);
  CheckTrue(FRouter.TryMatch(hcGET, '//users//42', Params, Handler), 'Repeated slashes should be collapsed');
  try
    CheckEquals('42', Params.Values['id']);
  finally
    Params.Free;
  end;
end;

procedure TTestTRestRouter.TryMatch_CaseInsensitiveStaticSegment_Matches;
var
  Params: TStringList;
  Handler: TRouteHandler;
begin
  FRouter.RegisterRoute('/Users', hcGET, UsersHandler);
  CheckTrue(FRouter.TryMatch(hcGET, '/users', Params, Handler),
    'Static segment matching should be case-insensitive');
  Params.Free;
end;

initialization
  RegisterTest(TTestTRestRouter.Suite);

end.
