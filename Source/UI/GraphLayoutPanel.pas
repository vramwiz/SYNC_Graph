unit GraphLayoutPanel;

// 構造と共通レイアウトの入力。空欄の目盛値は自動として保持する。
interface
uses System.Classes, Vcl.ExtCtrls, Vcl.ValEdit, Vcl.Samples.Spin,
  DarkComboBox, GraphModel;
type
  TGraphLayoutPanel=class(TPanel)
  private
    FKind:TDarkComboBox;
    FRows,FColumns:TSpinEdit;
    FGrid:TValueListEditor;
    FBusy:Boolean;
    FOnChange:TNotifyEvent;
    procedure Changed(Sender:TObject);
    procedure CellChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Doc:TGraphDocument);
    procedure Apply(Doc:TGraphDocument);
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property Grid:TValueListEditor read FGrid;
  end;
implementation
uses Vcl.StdCtrls, Vcl.Controls, System.SysUtils, DarkEditorTheme;
constructor TGraphLayoutPanel.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited;
  // ネイティブ入力部品のハンドル生成前に親ウィンドウを確定する。
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=450; Height:=600; BevelOuter:=bvNone;
  FKind:=TDarkComboBox.Create(Self); FKind.Parent:=Self; FKind.SetBounds(12,12,426,34);
  FKind.Font.Assign(Font); FKind.Anchors:=[akLeft,akTop,akRight];
  FKind.Items.Add('未設定'); FKind.Items.Add('N角形'); FKind.Items.Add('折れ線');
  FKind.Items.Add('棒'); FKind.Items.Add('円'); FKind.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='要素数'; L.SetBounds(12,62,70,24);
  FRows:=TSpinEdit.Create(Self); FRows.Parent:=Self; FRows.SetBounds(84,56,100,32);
  FRows.MinValue:=1; FRows.MaxValue:=MaxGraphRows; FRows.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='データ数'; L.SetBounds(224,62,80,24);
  FColumns:=TSpinEdit.Create(Self); FColumns.Parent:=Self; FColumns.SetBounds(312,56,126,32);
  FColumns.MinValue:=1; FColumns.MaxValue:=MaxGraphColumns; FColumns.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.AutoSize:=False; L.SetBounds(12,100,426,52); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='N角形: 行=軸、列=系列。円: データ数1。目盛の空欄=自動。値書式の空欄=非表示。';
  FGrid:=TValueListEditor.Create(Self); FGrid.Parent:=Self; FGrid.SetBounds(12,164,426,420);
  FGrid.Anchors:=[akLeft,akTop,akRight,akBottom]; FGrid.OnSetEditText:=CellChanged;
  FGrid.TitleCaptions[0]:='項目'; FGrid.TitleCaptions[1]:='値'; SetupEditorGrid(FGrid,220);
end;
procedure TGraphLayoutPanel.Changed(Sender:TObject);
begin if not FBusy and Assigned(FOnChange) then FOnChange(Self); end;
procedure TGraphLayoutPanel.CellChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
begin Changed(Sender); end;
procedure TGraphLayoutPanel.Load(Doc:TGraphDocument);
  procedure N(const Key:string; V:Double);
  begin FGrid.InsertRow(Key,FormatFloat('0.###',V,TFormatSettings.Invariant),True); end;
begin
  FBusy:=True;
  try
    FKind.ItemIndex:=Ord(Doc.Kind); FRows.Value:=Doc.Rows; FColumns.Value:=Doc.Columns;
    FGrid.Strings.Clear;
    N('X',Doc.Bounds.Left); N('Y',Doc.Bounds.Top); N('幅',Doc.Bounds.Width); N('高さ',Doc.Bounds.Height);
    N('横向き (0/1)',Ord(Doc.Horizontal)); N('積み重ね (0/1)',Ord(Doc.Stacked));
    N('相対角度',Doc.Rotation); N('要素名配置 (1～3)',Doc.NameLayout+1);
    FGrid.InsertRow('最小値',Doc.Minimum,True); FGrid.InsertRow('最大値',Doc.Maximum,True);
    FGrid.InsertRow('目盛間隔',Doc.Interval,True); FGrid.InsertRow('値書式',Doc.ValueFormat,True);
  finally FBusy:=False; end;
end;
procedure TGraphLayoutPanel.Apply(Doc:TGraphDocument);
  function N(Row:Integer):Double;
  begin Result:=StrToFloat(FGrid.Cells[1,Row],TFormatSettings.Invariant); end;
begin
  Doc.Kind:=TGraphKind(FKind.ItemIndex); Doc.ResizeStructure(FRows.Value,FColumns.Value);
  if Doc.Kind=gkPie then
  begin
    Doc.ResizeStructure(Doc.Rows,1);
    FBusy:=True;
    try FColumns.Value:=1; finally FBusy:=False; end;
  end;
  Doc.Bounds.Left:=N(1); Doc.Bounds.Top:=N(2); Doc.Bounds.Width:=N(3); Doc.Bounds.Height:=N(4);
  Doc.Horizontal:=N(5)<>0; Doc.Stacked:=N(6)<>0; Doc.Rotation:=N(7); Doc.NameLayout:=Trunc(N(8))-1;
  Doc.Minimum:=FGrid.Cells[1,9]; Doc.Maximum:=FGrid.Cells[1,10];
  Doc.Interval:=FGrid.Cells[1,11]; Doc.ValueFormat:=FGrid.Cells[1,12];
end;
end.
