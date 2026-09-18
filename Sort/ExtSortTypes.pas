unit ExtSortTypes;

{
  ����� ��������� � ������������ ���������/������� ������� ����������.

  ������ ������ ��������� �� ������ ������ �������� � 1 �� (��. ��).
  SAFETY_RESERVE ������������� �� ���� �������, ������� VCL/RTL,
  ��������� ������������ ������� � �.�., ������� �� �����������
  ���� � ������� ����.
}

interface

const
  KEY_LEN       = 50;    // ��������� �� ������ 50 ������ ������
  MAX_LINE_LEN  = 500;   // ������������ ����� ������ ��� CRLF
  CRLF_LEN      = 2;

  TOTAL_MEMORY_BUDGET = 1 * 1024 * 1024; // 1 �� - ����� �� ��
  SAFETY_RESERVE      = 96 * 1024;
  USABLE_BUDGET        = TOTAL_MEMORY_BUDGET - SAFETY_RESERVE;

  MAX_GEN_THREADS   = 4;
  GEN_OUTPUT_BUF_SIZE = 16 * 1024;

  MAX_MERGE_THREADS      = 4;
  MERGE_INPUT_BUF_SIZE   = 8 * 1024;
  MERGE_OUTPUT_BUF_SIZE  = 16 * 1024;
  FINAL_MERGE_INPUT_BUF  = 8 * 1024;
  FINAL_MERGE_OUTPUT_BUF = 64 * 1024;

type
  // ������ �� ������ ������ ��������� ������ ������ �����.
  // ���� ����� ������ �� ���������� - ����������� ������ ������ ������.
  TLineRef = packed record
    Offset: Cardinal;
    Len: Word;
  end;

  PByteArr = ^TByteArr;
  TByteArr = array[0..MaxInt - 1] of Byte;

// ��������� ���� ����� �� ������ KEY_LEN ������ (�������� ������� < ��������).
// ��� ��������� � �������� KEY_LEN ���������� 0 - ���-����� ������ ���������� ���.
// Off1/Off2 - �������� ������ ����� ������ ������� P1/P2 (Delphi 7 �� ���
// �������� ���������� ��� ��������������� ����������� ��� {$POINTERMATH},
// ������� ���������� ������ ��� ����� PByteArr).
function CompareKeyBytes(P1: PByte; Off1, Len1: Integer; P2: PByte; Off2, Len2: Integer): Integer;

function GetLogicalCPUCount: Integer;

implementation

uses
  Windows;

function CompareKeyBytes(P1: PByte; Off1, Len1: Integer; P2: PByte; Off2, Len2: Integer): Integer;
var
  k1, k2, i: Integer;
  arr1, arr2: PByteArr;
  b1, b2: Byte;
begin
  k1 := Len1;
  if k1 > KEY_LEN then k1 := KEY_LEN;
  k2 := Len2;
  if k2 > KEY_LEN then k2 := KEY_LEN;
  // Длина ключа (до KEY_LEN байт) - главный критерий: более короткая
  // строка всегда меньше более длинной, даже если её содержимое "больше".
  // Содержимое сравнивается только при равенстве длин ключа.
  if k1 <> k2 then
  begin
    Result := k1 - k2;
    Exit;
  end;
  arr1 := PByteArr(P1);
  arr2 := PByteArr(P2);
  for i := 0 to k1 - 1 do
  begin
    b1 := arr1^[Off1 + i];
    b2 := arr2^[Off2 + i];
    if b1 <> b2 then
    begin
      Result := Integer(b1) - Integer(b2);
      Exit;
    end;
  end;
  Result := 0;
end;

function GetLogicalCPUCount: Integer;
var
  SysInfo: TSystemInfo;
begin
  GetSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
  if Result < 1 then Result := 1;
end;

end.
