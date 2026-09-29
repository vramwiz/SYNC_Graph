unit GraphStylePanel;

// 線種・太さ・色対象を専用UIで編集し、共通カラーピッカーと接続する。
interface
uses System.Classes, System.Types, System.UITypes, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Controls,
  DarkComboBox, HorizontalTrackBarControl, GraphNumberEdit, GraphModel;
type
  TGraphStylePanel=class(TPanel)
  private
    FMode,FIndex,FColorTarget:TDarkComboBox;
    FLineKind,FMarker:TComboBox;
    FLineKindLabel,FMarkerLabel:TLabel;
    FLineWidth,FOutlineWidth:THorizontalTrackBarControl;
    FLineWidthLabel,FOutlineWidthLabel:TLabel;
    FTransparency:TGraphNumberEdit;
    FTransparencyLabel:TLabel;
    FColorSwatch:TPanel;
    FDoc:TGraphDocument;
    FBusy:Boolean;
    FOnChange,FOnColorTargetChange:TNotifyEvent;
    procedure SelectMode(Sender:TObject);
    procedure SelectIndex(Sender:TObject);
    procedure TargetChanged(Sender:TObject);
    procedure StyleChanged(Sender:TObject);
    procedure DrawLineKind(Control:TWinControl; Index:Integer; Rect:TRect;
      State:TOwnerDrawState);
    function GetSelectedColor:TAlphaColor;
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Doc:TGraphDocument);
    procedure RefreshValues;
    procedure Apply;
    procedure SetSelectedColor(Color:TAlphaColor);
    property SelectedColor:TAlphaColor read GetSelectedColor;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property OnColorTargetChange:TNotifyEvent read FOnColorTargetChange write FOnColorTargetChange;
  end;
implementation
uses System.SysUtils, System.Math, Winapi.Windows, Vcl.Graphics;

constructor TGraphStylePanel.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=290; Height:=390; BevelOuter:=bvNone; Color:=$00303030;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='装飾'; L.SetBounds(12,8,300,24);
  FMode:=TDarkComboBox.Create(Self); FMode.Parent:=Self; FMode.SetBounds(12,36,96,34);
  FMode.Items.Add('線'); FMode.Items.Add('系列'); FMode.ItemIndex:=0;
  FMode.OnChange:=SelectMode;
  FIndex:=TDarkComboBox.Create(Self); FIndex.Parent:=Self; FIndex.SetBounds(116,36,168,34);
  FIndex.OnChange:=SelectIndex;
  FLineKindLabel:=TLabel.Create(Self); FLineKindLabel.Parent:=Self;
  FLineKindLabel.Caption:='線種'; FLineKindLabel.SetBounds(12,86,80,24);
  FLineKind:=TComboBox.Create(Self); FLineKind.Parent:=Self;
  FLineKind.SetBounds(12,112,272,32); FLineKind.Style:=csOwnerDrawFixed;
  FLineKind.ItemHeight:=28; FLineKind.DropDownWidth:=272;
  FLineKind.Color:=$00303030; FLineKind.Font.Color:=$00EEEEEE;
  FLineKind.Items.Add('なし'); FLineKind.Items.Add('実線');
  FLineKind.Items.Add('破線'); FLineKind.Items.Add('点線');
  FLineKind.OnDrawItem:=DrawLineKind; FLineKind.OnChange:=StyleChanged;
  FLineWidthLabel:=TLabel.Create(Self); FLineWidthLabel.Parent:=Self;
  FLineWidthLabel.SetBounds(12,156,272,24);
  FLineWidth:=THorizontalTrackBarControl.Create(Self); FLineWidth.Parent:=Self;
  FLineWidth.SetBounds(12,180,272,32); FLineWidth.SetRange(0,200);
  FLineWidth.ShowTicks:=False; FLineWidth.WheelChangesPosition:=True;
  FLineWidth.OnChange:=StyleChanged;
  FOutlineWidthLabel:=TLabel.Create(Self); FOutlineWidthLabel.Parent:=Self;
  FOutlineWidthLabel.SetBounds(12,222,272,24);
  FOutlineWidth:=THorizontalTrackBarControl.Create(Self); FOutlineWidth.Parent:=Self;
  FOutlineWidth.SetBounds(12,246,272,32); FOutlineWidth.SetRange(0,200);
  FOutlineWidth.ShowTicks:=False; FOutlineWidth.WheelChangesPosition:=True;
  FOutlineWidth.OnChange:=StyleChanged;
  FTransparencyLabel:=TLabel.Create(Self); FTransparencyLabel.Parent:=Self;
  FTransparencyLabel.Caption:='透明度 (0～100)'; FTransparencyLabel.SetBounds(12,156,126,24);
  FTransparency:=TGraphNumberEdit.Create(Self); FTransparency.Parent:=Self;
  FTransparency.SetBounds(146,152,138,30); FTransparency.Minimum:=0;
  FTransparency.Maximum:=100; FTransparency.OnChange:=StyleChanged;
  FMarkerLabel:=TLabel.Create(Self); FMarkerLabel.Parent:=Self;
  FMarkerLabel.Caption:='マーク'; FMarkerLabel.SetBounds(12,204,80,24);
  FMarker:=TComboBox.Create(Self); FMarker.Parent:=Self; FMarker.Style:=csDropDownList;
  FMarker.SetBounds(146,198,138,32); FMarker.Items.Add('なし');
  FMarker.Items.Add('円'); FMarker.Items.Add('角'); FMarker.OnChange:=StyleChanged;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='カラー対象'; L.SetBounds(12,300,130,24);
  FColorTarget:=TDarkComboBox.Create(Self); FColorTarget.Parent:=Self;
  FColorTarget.SetBounds(12,326,204,34); FColorTarget.OnChange:=TargetChanged;
  FColorSwatch:=TPanel.Create(Self); FColorSwatch.Parent:=Self;
  FColorSwatch.SetBounds(224,326,60,34); FColorSwatch.BevelOuter:=bvLowered;
  FColorSwatch.ParentBackground:=False; FColorSwatch.ParentColor:=False;
  FColorSwatch.StyleElements:=[];
end;

procedure TGraphStylePanel.Load(Doc:TGraphDocument);
begin FDoc:=Doc; SelectMode(nil); end;

procedure TGraphStylePanel.SelectMode(Sender:TObject);
var I:Integer;
begin
  FBusy:=True;
  try
    FIndex.Items.Clear;
    if FMode.ItemIndex=0 then
    begin
      FIndex.Items.Add('X軸・基準線'); FIndex.Items.Add('Y軸');
      FIndex.Items.Add('目盛線'); FIndex.Items.Add('外枠');
      FIndex.Items.Add('系列線・棒枠'); FIndex.Items.Add('円区切り線');
    end
    else if FDoc<>nil then
      for I:=1 to FDoc.SeriesCount do FIndex.Items.Add('系列 / 区画 '+IntToStr(I));
    FIndex.ItemIndex:=0;
  finally FBusy:=False; end;
  FColorTarget.ItemIndex:=0;
  SelectIndex(nil);
end;

procedure TGraphStylePanel.SelectIndex(Sender:TObject);
var L:TLineStyle; V:TSeriesStyle; IsLine:Boolean; SavedTarget:Integer;
begin
  if FBusy or (FDoc=nil) or (FIndex.ItemIndex<0) then Exit;
  IsLine:=FMode.ItemIndex=0;
  SavedTarget:=Max(0,FColorTarget.ItemIndex);
  FBusy:=True;
  try
    FLineKind.Visible:=IsLine; FLineKindLabel.Visible:=IsLine;
    FLineWidth.Visible:=IsLine;
    FOutlineWidth.Visible:=IsLine; FLineWidthLabel.Visible:=IsLine;
    FOutlineWidthLabel.Visible:=IsLine;
    FTransparency.Visible:=not IsLine; FTransparencyLabel.Visible:=not IsLine;
    FMarker.Visible:=not IsLine; FMarkerLabel.Visible:=not IsLine;
    FColorTarget.Items.Clear;
    FColorTarget.Items.Add('線色');
    if IsLine then
    begin
      FColorTarget.Items.Add('縁取り色');
      L:=FDoc.Lines[FIndex.ItemIndex];
      FLineKind.ItemIndex:=EnsureRange(L.Kind,0,3);
      FLineWidth.Position:=EnsureRange(Round(L.Width*10),0,200);
      FOutlineWidth.Position:=EnsureRange(Round(L.OutlineWidth*10),0,200);
      FLineWidthLabel.Caption:=Format('線太さ %.1f',[L.Width]);
      FOutlineWidthLabel.Caption:=Format('縁取り太さ %.1f',[L.OutlineWidth]);
    end
    else
    begin
      FColorTarget.Items.Add('塗り色');
      V:=FDoc.Series[FIndex.ItemIndex];
      FTransparency.Text:=FormatFloat('0.###',V.Transparency,TFormatSettings.Invariant);
      FMarker.ItemIndex:=EnsureRange(V.Marker,0,2);
    end;
    FColorTarget.ItemIndex:=Min(SavedTarget,FColorTarget.Items.Count-1);
  finally FBusy:=False; end;
  TargetChanged(nil);
end;

procedure TGraphStylePanel.TargetChanged(Sender:TObject);
begin
  FColorSwatch.Color:=TColor((SelectedColor and $FF) shl 16 or
    (SelectedColor and $FF00) or (SelectedColor shr 16 and $FF));
  if Assigned(FOnColorTargetChange) then FOnColorTargetChange(Self);
end;

function TGraphStylePanel.GetSelectedColor:TAlphaColor;
begin
  Result:=$FFFFFFFF;
  if (FDoc=nil) or (FIndex.ItemIndex<0) then Exit;
  if FMode.ItemIndex=0 then
  begin
    if FColorTarget.ItemIndex=1 then Result:=FDoc.Lines[FIndex.ItemIndex].OutlineColor
    else Result:=FDoc.Lines[FIndex.ItemIndex].Color;
  end
  else if FColorTarget.ItemIndex=1 then Result:=FDoc.Series[FIndex.ItemIndex].FillColor
  else Result:=FDoc.Series[FIndex.ItemIndex].LineColor;
end;

procedure TGraphStylePanel.SetSelectedColor(Color:TAlphaColor);
var L:TLineStyle; V:TSeriesStyle; Old:TAlphaColor;
begin
  if (FDoc=nil) or (FIndex.ItemIndex<0) then Exit;
  Old:=SelectedColor;
  Color:=(Old and $FF000000) or (Color and $00FFFFFF);
  if Old=Color then Exit;
  if FMode.ItemIndex=0 then
  begin
    L:=FDoc.Lines[FIndex.ItemIndex];
    if FColorTarget.ItemIndex=1 then L.OutlineColor:=Color else L.Color:=Color;
    FDoc.Lines[FIndex.ItemIndex]:=L;
  end
  else
  begin
    V:=FDoc.Series[FIndex.ItemIndex];
    if FColorTarget.ItemIndex=1 then V.FillColor:=Color else V.LineColor:=Color;
    FDoc.Series[FIndex.ItemIndex]:=V;
  end;
  TargetChanged(nil);
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphStylePanel.StyleChanged(Sender:TObject);
var L:TLineStyle; V:TSeriesStyle; Transparency:Double;
begin
  if FBusy or (FDoc=nil) or (FIndex.ItemIndex<0) then Exit;
  if FMode.ItemIndex=0 then
  begin
    L:=FDoc.Lines[FIndex.ItemIndex];
    L.Kind:=FLineKind.ItemIndex;
    L.Width:=FLineWidth.Position/10;
    L.OutlineWidth:=FOutlineWidth.Position/10;
    FDoc.Lines[FIndex.ItemIndex]:=L;
    FLineWidthLabel.Caption:=Format('線太さ %.1f',[L.Width]);
    FOutlineWidthLabel.Caption:=Format('縁取り太さ %.1f',[L.OutlineWidth]);
  end
  else
  begin
    if not TryStrToFloat(FTransparency.Text,Transparency,TFormatSettings.Invariant) or
      (Transparency<0) or (Transparency>100) then
    begin
      FTransparency.Font.Color:=$008080FF;
      if Assigned(FOnChange) then FOnChange(Self);
      Exit;
    end;
    FTransparency.Font.Color:=$00EEEEEE;
    V:=FDoc.Series[FIndex.ItemIndex];
    V.Transparency:=Transparency;
    V.Marker:=FMarker.ItemIndex;
    FDoc.Series[FIndex.ItemIndex]:=V;
  end;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphStylePanel.DrawLineKind(Control:TWinControl; Index:Integer;
  Rect:TRect; State:TOwnerDrawState);
var C:TCanvas; X,Y,EndX,LengthOn,LengthOff:Integer;
begin
  C:=FLineKind.Canvas;
  if odSelected in State then C.Brush.Color:=$00613F20 else C.Brush.Color:=$00303030;
  C.FillRect(Rect); C.Font.Color:=$00EEEEEE;
  if (Index<0) or (Index>=FLineKind.Items.Count) then Exit;
  if Index=0 then
  begin C.TextOut(Rect.Left+12,Rect.Top+5,'なし'); Exit; end;
  Y:=(Rect.Top+Rect.Bottom) div 2;
  X:=Rect.Left+12; EndX:=Rect.Right-58;
  C.Pen.Color:=$00EEEEEE; C.Pen.Style:=psSolid; C.Pen.Width:=2;
  // 幅2のGDIペンではpsDash/psDotが実線になるため、間隔を自前で描く。
  case Index of
    1: begin C.MoveTo(X,Y); C.LineTo(EndX,Y); end;
    2,3:
      begin
        if Index=2 then begin LengthOn:=8; LengthOff:=5; end
        else begin LengthOn:=2; LengthOff:=4; end;
        while X<EndX do
        begin
          C.MoveTo(X,Y); C.LineTo(Min(X+LengthOn,EndX),Y);
          Inc(X,LengthOn+LengthOff);
        end;
      end;
  end;
  C.Pen.Width:=1;
  C.TextOut(Rect.Right-50,Rect.Top+5,FLineKind.Items[Index]);
end;

procedure TGraphStylePanel.RefreshValues;
begin SelectIndex(nil); end;

procedure TGraphStylePanel.Apply;
var Value:Double;
begin
  if (FMode.ItemIndex=1) and
    (not TryStrToFloat(FTransparency.Text,Value,TFormatSettings.Invariant) or
      (Value<0) or (Value>100)) then
    raise EConvertError.Create('透明度は0～100の数値で入力してください。');
end;
end.
