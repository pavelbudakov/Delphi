unit uWinSock;

interface

function WSGetIP(const HostName: String): String;
function WSIsPortAvailable(PortNumber : Integer): Boolean;
function WSGetResponse(URL : String): String;

implementation
uses SysUtils, IdURI, WinSock, uConstants;

function WSGetIP(const HostName: String): String;
var
  WSAData: TWSAData;
  R: PHostEnt;
  A: TInAddr;
begin
  Result := '0.0.0.0';
  WSAStartup($101, WSAData);
  R := Winsock.GetHostByName(PAnsiChar(AnsiString(HostName)));
  if Assigned(R) then begin
    A := PInAddr(r^.h_Addr_List^)^;
    Result := WinSock.inet_ntoa(A);
  end;
end;

function WSIsPortAvailable(PortNumber : Integer): Boolean;
var
  WSAData: TWSAData;
  Sock: TSocket;
  Addr: TSockAddrIn;
  dwPort: Word;
//  ipAddressStr: String;
begin
  Result := False;

  dwPort := PortNumber;
  if (dwPort = 0)
    then Exit;

  if (WSAStartup($0202, WSAData) <> 0)
    then Exit;

  try
    Sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if Sock = INVALID_SOCKET
      then Exit;

    try
      Addr.sin_family := AF_INET;
      Addr.sin_addr.S_addr := INADDR_ANY;
      Addr.sin_port := htons(dwPort);
      if (bind(Sock, Addr, SizeOf(Addr)) = 0)
        then Result := True;
    finally
      closesocket(Sock);
    end;
  finally
    WSACleanup;
  end;
end;

function WSGetResponse(URL : String): String;
var Sock: TSocket;
    Data: TWSAData;
    Adr: sockaddr_in;
    Request, Response: String;
    BytesRead: Integer;
    pURI: TIdURI;
    Host: String;
    Port: Integer;
    Path : String;
begin
  Result := '';

  try
    pURI:= TIdURI.Create(URL);
    try
      Host := pURI.Host;
      Port := StrToIntDef(pURI.Port, 80);
      Path := pURI.Path;
      Path := pURI.GetPathAndParams;
    finally
      FreeAndNil(pURI);
    end;
  except
    Result := '';
    Exit;
  end;

  Host := WSGetIP(Host);

  WSAStartup($0202,Data);
  Adr.sin_family:=AF_INET;
  Adr.sin_addr.S_addr:=inet_addr(PChar(Host));
  Adr.sin_port:=htons(Port);
  Sock:=Socket(AF_INET, SOCK_STREAM, 0);
  if Sock=INVALID_SOCKET then Exit;
  if connect(Sock,Adr,sizeof(Adr))=0 then begin
    Request := Format( 'GET %s HTTP/1.0'#13#10 +
                       'User-Agent: %s'#13#10#13#10,
    [ Path, 'compatible']);
    if Send(Sock, PChar(Request)^, Length(Request), 0) = SOCKET_ERROR then begin
//      then
//      ShowMessage("Send error: " + IntToStr(WSAGetLastError))
    end else begin
      Sleep(1000);
      SetLength(Response, 65536);
      BytesRead := Recv(Sock, PChar(Response)^, 65536, 0);
      if BytesRead > 0 then begin
        SetLength(Response, BytesRead);
        Result := Response;
      end else begin
        //BytesRead = -1: ShowMessage('Recv error: ' + IntToStr(WSAGetLastError));
        //BytesRead = 0: ShowMessage('Connection closed by peer');
        Result := '';
      end;
    end;
  end;
  CloseSocket(Sock);
  WSACleanup;
end;

end.
