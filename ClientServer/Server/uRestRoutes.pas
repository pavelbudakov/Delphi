unit uRestRoutes;

interface

uses SysUtils, Classes, Contnrs,
     IdCustomHTTPServer;

type
  TRouteHandler = function(const Params: TStringList; const RawPath: String; out RecordCount: Integer): WideString of object;

  TRestRouter = class
  private
    FRoutes: TObjectList;
    function SplitPath(const Path: string): TStrings;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterRoute(const Template: string; const aHttpMethod: THTTPCommandType;
                            Handler: TRouteHandler);
    function TryMatch(const aHttpMethod: THTTPCommandType; const Path: string;
                      out Params: TStringList;
                      out Handler: TRouteHandler): Boolean;
  end;

implementation

Type
  TRouteSegment = record
    IsParam: Boolean;
    Value: string;
  end;

  TRoute = class
    Segments: array of TRouteSegment;
    Handler: TRouteHandler;
    Method: THTTPCommandType;
  end;

constructor TRestRouter.Create;
begin
  inherited;
  FRoutes := TObjectList.Create(True);
end;

destructor TRestRouter.Destroy;
begin
  FreeAndNil(FRoutes);
  inherited;
end;

function TRestRouter.SplitPath(const Path: string): TStrings;
var
  i, start: Integer;
  seg: string;
begin
  Result := TStringList.Create;
  if Path = '' then Exit;

  start := 1;
  for i := 1 to Length(Path) do begin
    if Path[i] = '/' then begin
      if (i > start) then begin
        seg := Copy(Path, start, i - start);
        Result.Add(seg);
      end;
      start := i + 1;
    end;
  end;

  if (start <= Length(Path)) then begin
    seg := Copy(Path, start, Length(Path) - start + 1);
    Result.Add(seg);
  end;
end;

procedure TRestRouter.RegisterRoute(const Template: string; const aHttpMethod: THTTPCommandType; Handler: TRouteHandler);
var
  Parts: TStrings;
  i: Integer;
  seg: string;
  Route: TRoute;
begin
  Parts := SplitPath(Template);
  try
    Route := TRoute.Create;
    SetLength(Route.Segments, Parts.Count);
    for i := 0 to Pred(Parts.Count) do begin
      seg := Parts[i];
      if (Length(seg) >= 2) and (seg[1] = '{') and (seg[Length(seg)] = '}') then begin
        Route.Segments[i].IsParam := True;
        Route.Segments[i].Value := Copy(seg, 2, Length(seg) - 2);
      end else begin
        Route.Segments[i].IsParam := False;
        Route.Segments[i].Value := seg;
      end;
    end;
    Route.Handler := Handler;
    Route.Method := aHttpMethod;
  finally
    FreeAndNil(Parts);
  end;
  FRoutes.Add(Route);
end;

function TRestRouter.TryMatch(const aHttpMethod: THTTPCommandType; const Path: string;
                              out Params: TStringList;
                              out Handler: TRouteHandler): Boolean;
var
  Parts: TStrings;
  Route: TRoute;
  i, j: Integer;
  Match: Boolean;
  HasParams: Boolean;
  TempParams: TStringList;
begin
  Result := False;
  Match := False;
  Parts := SplitPath(Path);
  try
    for i := 0 to FRoutes.Count - 1 do
    begin
      Route := TRoute(FRoutes[i]);

      if Route.Method <> aHttpMethod then Continue;

      if Length(Route.Segments) <> Parts.Count then Continue;

      HasParams := False;
      for j := 0 to High(Route.Segments) do begin
        if Route.Segments[j].IsParam then begin
          HasParams := True;
          Break;
        end;
      end;

      if HasParams then Continue;

      Match := True;
      for j := 0 to High(Route.Segments) do begin
        if not SameText(Route.Segments[j].Value, Parts[j]) then begin
          Match := False;
          Break;
        end;
      end;

      if Match then begin
        Handler := Route.Handler;
        Params := TStringList.Create;
        Result := True;
        Exit;
      end;
    end;

    for i := 0 to Pred(FRoutes.Count) do begin
      Route := TRoute(FRoutes[i]);

      if Route.Method <> aHttpMethod then Continue;

      if Length(Route.Segments) <> Parts.Count then Continue;

      TempParams := TStringList.Create;
      try
        Match := True;
        for j := 0 to High(Route.Segments) do begin
          if Route.Segments[j].IsParam then begin
            TempParams.Values[Route.Segments[j].Value] := Parts[j];
          end else begin
            if not SameText(Route.Segments[j].Value, Parts[j]) then begin
              Match := False;
              Break;
            end;
          end;
        end;

        if Match then begin
          Handler := Route.Handler;
          Params := TempParams;
          Result := True;
          Exit;
        end;
      finally
        if not Match then begin
          FreeAndNil(TempParams);
        end;
      end;
    end;

    Result := False;
    Params := nil;
    Handler := nil;
  finally
    FreeAndNil(Parts);
  end;
end;

end.
