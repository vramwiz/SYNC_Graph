unit GraphStylePanel;

// 文字・線・系列の装飾入力を担当する。画面とモデルの対応をフォームから分離する。
interface
uses System.Classes, Vcl.ExtCtrls, Vcl.ValEdit, Vcl.StdCtrls,
  DarkComboBox, GraphModel;
type
  TGraphStylePanel=class(TPanel)
  private
    FMode,FIndex:TDarkComboBox;
    FGrid:TValueListEditor;
    FDoc:TGraphDocument;
    FBusy:Boolean;
    FOnChange:TNotifyEvent;
    procedure SelectMode(Sender:TObject);
    procedure SelectIndex(Sender:TObject);
    procedure Changed(Sender:TObject; ACol,ARow:Integer; const Value:string);
    procedure ChooseColor(Sender:TObject);
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Doc:TGraphDocument);
    procedure RefreshValues;
    procedure Apply;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses System.SysUtils, System.UITypes, Vcl.Controls, GraphColorPopup, DarkEditorTheme;

constructor TGraphStylePanel.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited;
  // ネイティブ入力部品のハンドル生成前に親ウィンドウを確定する。
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=450; Height:=600; BevelOuter:=bvNone;
  FMode:=TDarkComboBox.Create(Self); FMode.Parent:=Self; FMode.SetBounds(12,12,170,34);
  FMode.Items.Add('線'); FMode.Items.Add('系列'); FMode.ItemIndex:=0;
  FMode.Font.Assign(Font); FMode.OnChange:=SelectMode;
  FIndex:=TDarkComboBox.Create(Self); FIndex.Parent:=Self; FIndex.SetBounds(194,12,244,34);
  FIndex.Font.Assign(Font); FIndex.Anchors:=[akLeft,akTop,akRight]; FIndex.OnChange:=SelectIndex;
  L:=TLabel.Create(Self); L.Parent:=Self; L.AutoSize:=False; L.SetBounds(12,58,426,48); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='色は #AARRGGBB。色の行をダブルクリックで選択。透明度0=不透明。';
  FGrid:=TValueListEditor.Create(Self); FGrid.Parent:=Self; FGrid.SetBounds(12,118,426,466);
  FGrid.Anchors:=[akLeft,akTop,akRight,akBottom]; FGrid.TitleCaptions[0]:='項目'; FGrid.TitleCaptions[1]:='値';
  SetupEditorGrid(FGrid,220); FGrid.OnSetEditText:=Changed; FGrid.OnDblClick:=ChooseColor;
end;

procedure TGraphStylePanel.Load(Doc:TGraphDocument);
begin FDoc:=Doc; SelectMode(nil); end;

procedure TGraphStylePanel.RefreshValues;
begin SelectIndex(nil); end;

procedure TGraphStylePanel.SelectMode(Sender:TObject);
var I:Integer;
begin
  FBusy:=True;
  try
    FIndex.Items.Clear;
    case FMode.ItemIndex of
      0:begin
        FIndex.Items.Add('X軸・基準線'); FIndex.Items.Add('Y軸'); FIndex.Items.Add('目盛線'); FIndex.Items.Add('外枠');
        FIndex.Items.Add('系列線・棒枠'); FIndex.Items.Add('円区切り線');
      end;
      1:for I:=1 to FDoc.SeriesCount do FIndex.Items.Add('系列 / 区画 '+IntToStr(I));
    end;
    FIndex.ItemIndex:=0;
  finally FBusy:=False; end;
  SelectIndex(nil);
end;

procedure TGraphStylePanel.SelectIndex(Sender:TObject);
var L:TLineStyle; V:TSeriesStyle;
  procedure Add(const K,Value:string); begin FGrid.InsertRow(K,Value,True); end;
  procedure Num(const K:string; Value:Double); begin Add(K,FloatToStr(Value,TFormatSettings.Invariant)); end;
  procedure Col(const K:string; Value:TAlphaColor); begin Add(K,'#'+IntToHex(Value,8)); end;
begin
  if FBusy or (FDoc=nil) or (FIndex.ItemIndex<0) then Exit;
  FBusy:=True;
  try
    FGrid.Strings.Clear;
    case FMode.ItemIndex of
      0:begin
        L:=FDoc.Lines[FIndex.ItemIndex]; Num('線種 (0無/1実/2破/3点)',L.Kind);
        Col('線色',L.Color); Num('線太さ',L.Width); Col('縁取り色',L.OutlineColor); Num('縁取り太さ',L.OutlineWidth);
      end;
      1:begin
        V:=FDoc.Series[FIndex.ItemIndex]; Col('線色',V.LineColor); Col('塗色',V.FillColor);
        Num('透明度 (0～100)',V.Transparency); Num('マーク (0無/1円/2角)',V.Marker);
      end;
    end;
  finally FBusy:=False; end;
end;

procedure TGraphStylePanel.Apply;
var L:TLineStyle; V:TSeriesStyle;
  function N(Row:Integer):Double; begin Result:=StrToFloat(FGrid.Cells[1,Row],TFormatSettings.Invariant); end;
  function C(Row:Integer):TAlphaColor;
  var Text:string;
  begin
    Text:=FGrid.Cells[1,Row];
    if (Length(Text)<>9) or (Text[1]<>'#') then raise EConvertError.Create('色は#AARRGGBB形式で指定してください。');
    Result:=StrToUInt64('$'+Copy(Text,2,8));
  end;
begin
  if FBusy or (FDoc=nil) then Exit;
  case FMode.ItemIndex of
    0:begin
      L.Kind:=Trunc(N(1)); L.Color:=C(2); L.Width:=N(3); L.OutlineColor:=C(4); L.OutlineWidth:=N(5);
      FDoc.Lines[FIndex.ItemIndex]:=L;
    end;
    1:begin
      V.LineColor:=C(1); V.FillColor:=C(2); V.Transparency:=N(3); V.Marker:=Trunc(N(4));
      FDoc.Series[FIndex.ItemIndex]:=V;
    end;
  end;
end;

procedure TGraphStylePanel.Changed(Sender:TObject; ACol,ARow:Integer; const Value:string);
begin if not FBusy and Assigned(FOnChange) then FOnChange(Self); end;

procedure TGraphStylePanel.ChooseColor(Sender:TObject);
var Text:string; C:TAlphaColor;
begin
  if Pos('色',FGrid.Cells[0,FGrid.Row])=0 then Exit;
  Text:=FGrid.Cells[1,FGrid.Row];
  if (Length(Text)<>9) or (Text[1]<>'#') then Exit;
  C:=StrToUInt64('$'+Copy(Text,2,8));
  if PickGraphColor(C) then FGrid.Cells[1,FGrid.Row]:='#'+IntToHex(C,8);
  if Assigned(FOnChange) then FOnChange(Self);
end;
end.
