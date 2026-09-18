object UserFrame: TUserFrame
  Left = 0
  Top = 0
  Width = 435
  Height = 171
  Align = alTop
  TabOrder = 0
  object pnlUser: TPanel
    Left = 0
    Top = 0
    Width = 435
    Height = 171
    Align = alClient
    TabOrder = 0
    TabStop = True
    object pImage: TImage
      Left = 16
      Top = 8
      Width = 145
      Height = 145
      Transparent = True
    end
    object lblName: TLabel
      Left = 184
      Top = 16
      Width = 57
      Height = 20
      Caption = 'lblName'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object lblPhone: TLabel
      Left = 184
      Top = 45
      Width = 61
      Height = 20
      Caption = 'lblPhone'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object lblAddress: TLabel
      Left = 184
      Top = 74
      Width = 74
      Height = 20
      Caption = 'lblAddress'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object lblNote: TLabel
      Left = 184
      Top = 104
      Width = 49
      Height = 20
      Caption = 'lblNote'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object lblUserID: TLabel
      Left = 185
      Top = 136
      Width = 43
      Height = 13
      Caption = 'lblUserID'
    end
    object lblGroupPath: TLabel
      Left = 432
      Top = 136
      Width = 61
      Height = 13
      Caption = 'lblGroupPath'
    end
    object lblGroupID: TLabel
      Left = 312
      Top = 136
      Width = 50
      Height = 13
      Caption = 'lblGroupID'
    end
  end
end
