unit uUtils;

interface

function LoadStringFromFile(FileName : String): String;
procedure SaveStringToFile(FileName, Data : String);

implementation
uses SysUtils, Classes;     

function LoadStringFromFile(FileName : String): String;
var pSL : TStringList;
begin
  pSL := TStringList.Create;
  try
    pSL.LoadFromFile(FileName);
    Result := Trim(pSL.Text);
  finally
    FreeAndNil(pSL);
  end;
end;

procedure SaveStringToFile(FileName, Data : String);
var pSL : TStringList;
begin
  pSL := TStringList.Create;
  try
    pSL.Text := Trim(Data);
    pSL.SaveToFile(FileName);
  finally
    FreeAndNil(pSL);
  end;
end;

end.
