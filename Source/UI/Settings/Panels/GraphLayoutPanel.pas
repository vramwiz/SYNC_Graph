unit GraphLayoutPanel;

// 構造、向き、目盛りを編集する。グラフ枠の位置と寸法はキャンバスで操作する。
interface
uses System.Classes, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, DarkComboBox,
  GraphNumberEdit, GraphModel;
type
  TGraphLayoutPanel=class(TPanel)
  private
    FKind,FNameLayout:TDarkComboBox;
    FRows,FColumns:TEdit;
    FRotation:TGraphNumberEdit;
    FNumbers:array[0..2] of TGraphNumberEdit;
    FHorizontal,FStacked:TCheckBox;
    FValueFormat:TEdit;
    FBusy:Boolean;
    FOnChange,FOnNameLayoutChange:TNotifyEvent;
    procedure Changed(Sender:TObject);
    procedure CountClicked(Sender:TObject; Button:TUDBtnType);
    procedure NameLayoutChanged(Sender:TObject);
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Doc:TGraphDocument);
    procedure Apply(Doc:TGraphDocument);
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property OnNameLayoutChange:TNotifyEvent read FOnNameLayoutChange write FOnNameLayoutChange;
    property ValueFormatEdit:TEdit read FValueFormat;
  end;
implementation
uses System.SysUtils, System.Math, Vcl.Controls;

constructor TGraphLayoutPanel.Create(AOwner:TComponent);
var L:TLabel; I:Integer;
  procedure LabelAt(const Caption:string; X,Y,W:Integer);
  begin
    L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:=Caption;
    L.SetBounds(X,Y,W,24); L.Font.Color:=$00EEEEEE;
  end;
  function NumberAt(X,Y,W:Integer; MinValue,MaxValue:Double; Empty:Boolean=False):TGraphNumberEdit;
  begin
    Result:=TGraphNumberEdit.Create(Self); Result.Parent:=Self;
    Result.SetBounds(X,Y,W,30); Result.Minimum:=MinValue; Result.Maximum:=MaxValue;
    Result.AllowEmpty:=Empty; Result.OnChange:=Changed;
  end;
  function CountAt(X,W,MaxValue:Integer):TEdit;
  var Spin:TUpDown;
  begin
    Result:=TEdit.Create(Self); Result.Parent:=Self;
    Result.SetBounds(X,80,W-18,30); Result.Text:='3';
    Result.StyleElements:=[]; Result.Color:=$00303030; Result.Font.Color:=$00EEEEEE;
    Spin:=TUpDown.Create(Self); Spin.Parent:=Self;
    Spin.Min:=1; Spin.Max:=MaxValue; Spin.Thousands:=False;
    // Associateは不正な生入力をフォーカス移動で補正するため使わず、矢印操作だけを接続する。
    // 手入力の検証・保管はフォームの終了処理に委ね、入力途中の文字を失わない。
    Spin.Position:=3; Spin.Tag:=X; Spin.OnClick:=CountClicked;
    Spin.SetBounds(X+W-18,80,18,30);
    Result.OnChange:=Changed;
  end;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=290; Height:=480; BevelOuter:=bvNone; Color:=$00303030;
  LabelAt('構造・目盛り',12,8,272);
  FKind:=TDarkComboBox.Create(Self); FKind.Parent:=Self; FKind.SetBounds(12,36,272,34);
  FKind.Font.Assign(Font); FKind.Items.Add('未設定'); FKind.Items.Add('N角形');
  FKind.Items.Add('折れ線'); FKind.Items.Add('棒'); FKind.Items.Add('円');
  FKind.OnChange:=Changed;
  LabelAt('要素数',12,86,55); FRows:=CountAt(68,70,MaxGraphRows);
  LabelAt('データ数',146,86,70); FColumns:=CountAt(216,68,MaxGraphColumns);
  FHorizontal:=TCheckBox.Create(Self); FHorizontal.Parent:=Self;
  FHorizontal.Caption:='横向き'; FHorizontal.SetBounds(12,146,120,28);
  FHorizontal.OnClick:=Changed;
  FStacked:=TCheckBox.Create(Self); FStacked.Parent:=Self;
  FStacked.Caption:='積み重ね'; FStacked.SetBounds(146,146,138,28);
  FStacked.OnClick:=Changed;
  LabelAt('要素名配置',12,192,94);
  FNameLayout:=TDarkComboBox.Create(Self); FNameLayout.Parent:=Self;
  FNameLayout.SetBounds(108,184,176,34);
  for I:=1 to 3 do FNameLayout.Items.Add('配置 '+IntToStr(I));
  FNameLayout.OnChange:=NameLayoutChanged;
  LabelAt('相対角度',12,234,90);
  FRotation:=NumberAt(108,228,176,-360,360);
  LabelAt('目盛範囲',12,278,272);
  LabelAt('最小値',12,310,55); FNumbers[0]:=NumberAt(68,304,70,-1.0E9,1.0E9,True);
  LabelAt('最大値',146,310,55); FNumbers[1]:=NumberAt(204,304,80,-1.0E9,1.0E9,True);
  LabelAt('目盛間隔',12,354,90); FNumbers[2]:=NumberAt(108,348,176,0,1.0E9,True);
  LabelAt('値書式（右クリックで候補）',12,400,272);
  FValueFormat:=TEdit.Create(Self); FValueFormat.Parent:=Self;
  FValueFormat.StyleElements:=[];
  FValueFormat.SetBounds(12,428,272,30); FValueFormat.Color:=$00303030;
  FValueFormat.Font.Color:=$00EEEEEE; FValueFormat.OnChange:=Changed;
end;

procedure TGraphLayoutPanel.CountClicked(Sender:TObject; Button:TUDBtnType);
var Spin:TUpDown; Edit:TEdit; Value:Integer;
begin
  Spin:=TUpDown(Sender);
  if Spin.Tag=68 then Edit:=FRows else Edit:=FColumns;
  if not TryStrToInt(Edit.Text,Value) then Value:=Spin.Position;
  if Button=btNext then Inc(Value) else Dec(Value);
  Value:=EnsureRange(Value,Spin.Min,Spin.Max);
  Spin.Position:=Value; Edit.Text:=IntToStr(Value);
end;
procedure TGraphLayoutPanel.Changed(Sender:TObject);
begin if not FBusy and Assigned(FOnChange) then FOnChange(Self); end;

procedure TGraphLayoutPanel.NameLayoutChanged(Sender:TObject);
begin
  if FBusy then Exit;
  if Assigned(FOnNameLayoutChange) then FOnNameLayoutChange(Self);
  Changed(Sender);
end;

procedure TGraphLayoutPanel.Load(Doc:TGraphDocument);
begin
  FBusy:=True;
  try
    FKind.ItemIndex:=Ord(Doc.Kind);
    FRows.Text:=IntToStr(Doc.Rows); FColumns.Text:=IntToStr(Doc.Columns);
    FHorizontal.Checked:=Doc.Horizontal; FStacked.Checked:=Doc.Stacked;
    FNameLayout.ItemIndex:=EnsureRange(Doc.NameLayout,0,2);
    FRotation.Text:=FormatFloat('0.###',Doc.Rotation,TFormatSettings.Invariant);
    FNumbers[0].Text:=Doc.Minimum; FNumbers[1].Text:=Doc.Maximum;
    FNumbers[2].Text:=Doc.Interval; FValueFormat.Text:=Doc.ValueFormat;
  finally FBusy:=False; end;
end;

procedure TGraphLayoutPanel.Apply(Doc:TGraphDocument);
var Rows,Columns:Integer; Rotation:Double;
begin
  if FKind.ItemIndex<0 then raise EConvertError.Create('グラフ種類を選択してください。');
  Rows:=StrToInt(FRows.Text); Columns:=StrToInt(FColumns.Text);
  if not InRange(Rows,1,MaxGraphRows) or
    not InRange(Columns,1,MaxGraphColumns) then
    raise EConvertError.Create('要素数またはデータ数が入力範囲を超えています。');
  Rotation:=StrToFloat(FRotation.Text,TFormatSettings.Invariant);
  if not InRange(Rotation,-360,360) then
    raise EConvertError.Create('相対角度は-360～360で入力してください。');
  Doc.Kind:=TGraphKind(FKind.ItemIndex);
  Doc.ResizeStructure(Rows,Columns);
  if Doc.Kind=gkPie then
  begin
    Doc.ResizeStructure(Doc.Rows,1);
    FBusy:=True;
    try FColumns.Text:='1'; finally FBusy:=False; end;
  end;
  // 枠の位置と寸法はGraphViewが更新するため、設定欄からは書き戻さない。
  Doc.Horizontal:=FHorizontal.Checked; Doc.Stacked:=FStacked.Checked;
  Doc.NameLayout:=FNameLayout.ItemIndex;
  Doc.Rotation:=Rotation;
  Doc.Minimum:=FNumbers[0].Text; Doc.Maximum:=FNumbers[1].Text;
  Doc.Interval:=FNumbers[2].Text; Doc.ValueFormat:=FValueFormat.Text;
end;
end.
