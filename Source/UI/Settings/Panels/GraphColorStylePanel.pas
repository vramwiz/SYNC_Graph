unit GraphColorStylePanel;
// グラフ種別に対応する色一覧と折れ線のスタイルを編集する。
interface
uses System.Classes, System.UITypes, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls,
  DarkComboBox, GraphModel;
type TGraphColorStylePanel=class(TPanel)
private
  FDoc:TGraphDocument;
  FSwatches:TArray<TPanel>;
  FTitle,FSelected:TLabel;
  FMarker,FKind:TDarkComboBox;
  FIndex:Integer;
  FBusy:Boolean;
  FOnChange,FOnColorTargetChange:TNotifyEvent;
  procedure SelectColor(Sender:TObject);
  procedure StyleChanged(Sender:TObject);
  function GetSelectedColor:TAlphaColor;
public
  constructor Create(AOwner:TComponent); override;
  procedure Load(Doc:TGraphDocument);
  procedure SetSelectedColor(Color:TAlphaColor);
  property SelectedColor:TAlphaColor read GetSelectedColor;
  property OnChange:TNotifyEvent read FOnChange write FOnChange;
  property OnColorTargetChange:TNotifyEvent read FOnColorTargetChange write FOnColorTargetChange;
end;
implementation
uses System.SysUtils, System.Math, Vcl.Graphics;
constructor TGraphColorStylePanel.Create(AOwner:TComponent);
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=290; Height:=80; BevelOuter:=bvNone; Color:=$00303030;
  FTitle:=TLabel.Create(Self); FTitle.Parent:=Self; FTitle.SetBounds(12,8,272,24);
  FSelected:=TLabel.Create(Self); FSelected.Parent:=Self;
  FMarker:=TDarkComboBox.Create(Self); FMarker.Parent:=Self;
  FMarker.Items.Add('マーク: なし'); FMarker.Items.Add('マーク: 円'); FMarker.Items.Add('マーク: 角');
  FMarker.OnChange:=StyleChanged;
  FKind:=TDarkComboBox.Create(Self); FKind.Parent:=Self;
  FKind.Items.Add('線種: 実線'); FKind.Items.Add('線種: 破線'); FKind.Items.Add('線種: 点線');
  FKind.OnChange:=StyleChanged;
end;
procedure TGraphColorStylePanel.Load(Doc:TGraphDocument);
var I,N,Old,Y:Integer; C:TAlphaColor; IsLine:Boolean;
begin
  FDoc:=Doc; N:=0;
  if (Doc<>nil) and (Doc.Kind<>gkNone) then N:=Doc.SeriesCount;
  Old:=Length(FSwatches);
  for I:=N to Old-1 do FSwatches[I].Free;
  SetLength(FSwatches,N);
  for I:=Old to N-1 do
  begin
    FSwatches[I]:=TPanel.Create(Self); FSwatches[I].Parent:=Self;
    FSwatches[I].ParentBackground:=False; FSwatches[I].StyleElements:=[];
    FSwatches[I].Tag:=I; FSwatches[I].OnClick:=SelectColor;
    FSwatches[I].ShowHint:=True;
  end;
  FIndex:=EnsureRange(FIndex,0,Max(0,N-1));
  IsLine:=(Doc<>nil) and (Doc.Kind=gkLine);
  FTitle.Caption:='色・スタイル（要素ごと）';
  if (Doc<>nil) and (Doc.Kind=gkRadar) then FTitle.Caption:='色（データごと）';
  for I:=0 to N-1 do
  begin
    FSwatches[I].SetBounds(12+(I mod 7)*39,38+(I div 7)*36,34,30);
    FSwatches[I].Caption:=IntToStr(I+1); FSwatches[I].Hint:=IntToStr(I+1)+' 番の色';
    if IsLine then C:=Doc.Series[I].LineColor else C:=Doc.Series[I].FillColor;
    FSwatches[I].Color:=TColor(((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF));
    if (((C shr 16) and $FF)*299+((C shr 8) and $FF)*587+(C and $FF)*114)>140000 then
      FSwatches[I].Font.Color:=clBlack else FSwatches[I].Font.Color:=clWhite;
    if I=FIndex then FSwatches[I].BevelOuter:=bvLowered else FSwatches[I].BevelOuter:=bvRaised;
  end;
  Y:=38+((N+6) div 7)*36;
  FSelected.SetBounds(12,Y,272,24); FSelected.Visible:=N>0;
  FSelected.Caption:='選択: '+IntToStr(FIndex+1);
  FMarker.Visible:=IsLine; FKind.Visible:=IsLine;
  FMarker.SetBounds(12,Y+28,130,34); FKind.SetBounds(150,Y+28,134,34);
  FBusy:=True;
  try
    if N>0 then
    begin
      FMarker.ItemIndex:=Doc.Series[FIndex].Marker;
      FKind.ItemIndex:=EnsureRange(Doc.Series[FIndex].LineKind-1,0,2);
    end;
  finally FBusy:=False; end;
  Height:=Y+32; if IsLine then Height:=Y+72;
end;
procedure TGraphColorStylePanel.SelectColor(Sender:TObject);
begin
  FIndex:=TPanel(Sender).Tag; Load(FDoc);
  if Assigned(FOnColorTargetChange) then FOnColorTargetChange(Self);
end;
function TGraphColorStylePanel.GetSelectedColor:TAlphaColor;
begin
  Result:=$FFFFFFFF;
  if (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  if FDoc.Kind=gkLine then Result:=FDoc.Series[FIndex].LineColor
  else Result:=FDoc.Series[FIndex].FillColor;
end;
procedure TGraphColorStylePanel.SetSelectedColor(Color:TAlphaColor);
var S:TSeriesStyle;
begin
  if (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  S:=FDoc.Series[FIndex];
  // 色変更は既存のアルファを保ち、マーク色も系列色にそろえる。
  S.LineColor:=(S.LineColor and $FF000000) or (Color and $FFFFFF);
  S.FillColor:=(S.FillColor and $FF000000) or (Color and $FFFFFF);
  FDoc.Series[FIndex]:=S; Load(FDoc);
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TGraphColorStylePanel.StyleChanged(Sender:TObject);
var S:TSeriesStyle;
begin
  if FBusy or (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  S:=FDoc.Series[FIndex]; S.Marker:=FMarker.ItemIndex; S.LineKind:=FKind.ItemIndex+1;
  FDoc.Series[FIndex]:=S;
  if Assigned(FOnChange) then FOnChange(Self);
end;
end.
