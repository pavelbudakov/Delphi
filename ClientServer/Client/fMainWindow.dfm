object MainWindow: TMainWindow
  Left = 386
  Top = 141
  Width = 1305
  Height = 675
  Caption = #1055#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1080' '#1080' '#1075#1088#1091#1087#1087#1099
  Color = clWindow
  Ctl3D = False
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 283
    Top = 10
    Height = 616
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1289
    Height = 10
    Align = alTop
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 626
    Width = 1289
    Height = 10
    Align = alBottom
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 10
    Width = 10
    Height = 616
    Align = alLeft
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
  end
  object pnlRight: TPanel
    Left = 1279
    Top = 10
    Width = 10
    Height = 616
    Align = alRight
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 3
  end
  object gbGroups: TGroupBox
    Left = 10
    Top = 10
    Width = 273
    Height = 616
    Align = alLeft
    Caption = ' '#1043#1088#1091#1087#1087#1099' '
    Constraints.MinWidth = 50
    TabOrder = 4
    object lbGroups: TListBox
      Left = 1
      Top = 41
      Width = 271
      Height = 574
      Align = alClient
      BorderStyle = bsNone
      ItemHeight = 13
      TabOrder = 0
      OnClick = lbGroupsClick
      OnDrawItem = lbGroupsDrawItem
    end
    object pnlSearch: TPanel
      Left = 1
      Top = 14
      Width = 271
      Height = 27
      Align = alTop
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 1
      object edSearch: TEdit
        Left = 8
        Top = 4
        Width = 257
        Height = 19
        TabOrder = 0
        OnChange = edSearchChange
      end
    end
  end
  object gbUsers: TGroupBox
    Left = 286
    Top = 10
    Width = 993
    Height = 616
    Align = alClient
    Caption = ' '#1055#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1080' '
    TabOrder = 5
    object pSB: TScrollBox
      Left = 1
      Top = 14
      Width = 991
      Height = 584
      Align = alClient
      TabOrder = 0
    end
    object pbProgress: TProgressBar
      Left = 1
      Top = 598
      Width = 991
      Height = 17
      Align = alBottom
      Smooth = True
      TabOrder = 1
      Visible = False
    end
  end
  object pmTray: TPopupMenu
    Left = 34
    Top = 66
    object miModifySettings: TMenuItem
      Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1072
      OnClick = miModifySettingsClick
    end
  end
end
