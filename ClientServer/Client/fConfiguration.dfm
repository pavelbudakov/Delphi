object ConfigurationWindow: TConfigurationWindow
  Left = 292
  Top = 143
  BorderStyle = bsDialog
  Caption = ' '#1050#1086#1085#1092#1080#1075#1091#1088#1072#1094#1080#1103' REST '#1089#1077#1088#1074#1077#1088#1072' '
  ClientHeight = 145
  ClientWidth = 393
  Color = clWindow
  Ctl3D = False
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object pnlLeft: TPanel
    Left = 0
    Top = 10
    Width = 10
    Height = 89
    Align = alLeft
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
  end
  object pnlContent: TPanel
    Left = 10
    Top = 10
    Width = 373
    Height = 89
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    object gbPortNumber: TGroupBox
      Left = 0
      Top = 0
      Width = 373
      Height = 89
      Align = alTop
      Caption = ' '#1055#1086#1088#1090' '
      TabOrder = 0
      object lblPortNumber: TLabel
        Left = 8
        Top = 27
        Width = 261
        Height = 13
        Caption = #1042#1074#1077#1076#1080#1090#1077' '#1072#1076#1088#1077#1089' '#1080' '#1085#1086#1084#1077#1088' '#1087#1086#1088#1090#1072' REST '#1089#1077#1088#1074#1077#1088#1072
      end
      object edServerAddress: TEdit
        Left = 8
        Top = 56
        Width = 353
        Height = 19
        Ctl3D = False
        ParentCtl3D = False
        TabOrder = 0
        Text = 'http://localhost:56001'
        OnChange = edServerAddressChange
        OnKeyPress = edServerAddressKeyPress
      end
      object btnCheckPort: TBitBtn
        Left = 331
        Top = 20
        Width = 27
        Height = 27
        Hint = #1055#1088#1086#1074#1077#1088#1080#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = btnCheckPortClick
        Glyph.Data = {
          DE010000424DDE01000000000000760000002800000024000000120000000100
          0400000000006801000000000000000000001000000000000000000000000000
          80000080000000808000800000008000800080800000C0C0C000808080000000
          FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00333333444444
          33333333333F8888883F33330000324334222222443333388F3833333388F333
          000032244222222222433338F8833FFFFF338F3300003222222AAAAA22243338
          F333F88888F338F30000322222A33333A2224338F33F8333338F338F00003222
          223333333A224338F33833333338F38F00003222222333333A444338FFFF8F33
          3338888300003AAAAAAA33333333333888888833333333330000333333333333
          333333333333333333FFFFFF000033333333333344444433FFFF333333888888
          00003A444333333A22222438888F333338F3333800003A2243333333A2222438
          F38F333333833338000033A224333334422224338338FFFFF8833338000033A2
          22444442222224338F3388888333FF380000333A2222222222AA243338FF3333
          33FF88F800003333AA222222AA33A3333388FFFFFF8833830000333333AAAAAA
          3333333333338888883333330000333333333333333333333333333333333333
          0000}
        NumGlyphs = 2
      end
    end
    object pnlDivider: TPanel
      Left = 0
      Top = 89
      Width = 373
      Height = 10
      Align = alTop
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 1
    end
  end
  object pnlRight: TPanel
    Left = 383
    Top = 10
    Width = 10
    Height = 89
    Align = alRight
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 393
    Height = 10
    Align = alTop
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 3
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 99
    Width = 393
    Height = 46
    Align = alBottom
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 4
    object lblNote: TLabel
      Left = 192
      Top = 10
      Width = 139
      Height = 26
      Caption = #1055#1088#1086#1074#1077#1076#1080#1090#1077' '#1074#1072#1083#1080#1076#1072#1094#1080#1102' '#1082#1086#1085#1092#1080#1075#1091#1088#1072#1094#1080#1080' '#1089#1077#1088#1074#1077#1088#1072
      Visible = False
      WordWrap = True
    end
    object btnOk: TBitBtn
      Left = 8
      Top = 11
      Width = 75
      Height = 25
      Enabled = False
      TabOrder = 0
      OnClick = btnOkClick
      Kind = bkOK
    end
    object btnCancel: TBitBtn
      Left = 96
      Top = 11
      Width = 75
      Height = 25
      TabOrder = 1
      Kind = bkCancel
    end
  end
end
