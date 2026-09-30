unit GraphColorStylePanel;
// データごとの縁色・塗り色・塗り模様と、折れ線専用スタイルを編集する。
interface
uses System.Classes, System.UITypes, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls,
  DarkComboBox, GraphModel;
type TGraphColorStylePanel=class(TPanel)
private
  FDoc:TGraphDocument;
  FSwatches:TArray<TPanel>;
  FTitle,FSelected:TLabel;
  FMarker,FKind,FPattern:TDarkComboBox;
  FIndex:Integer;
  FBusy,FFill:Boolean;
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
  FPattern:=TDarkComboBox.Create(Self); FPattern.Parent:=Self; FPattern.Name:='FillPattern';
  FPattern.Items.Add('塗り: なし'); FPattern.Items.Add('塗り: ベタ');
  FPattern.Items.Add('塗り: 斜線'); FPattern.Items.Add('塗り: 逆斜線');
  FPattern.Items.Add('塗り: 交差線'); FPattern.OnChange:=StyleChanged;
end;
procedure TGraphColorStylePanel.Load(Doc:TGraphDocument);
var I,N,Count,Old,Y,Index:Integer; C:TAlphaColor; IsLine:Boolean;
  procedure Bounds(Control:TControl; X,Y,W,H:Integer);
  begin
    Control.SetBounds(Round(X*CurrentPPI/96),Round(Y*CurrentPPI/96),
      Round(W*CurrentPPI/96),Round(H*CurrentPPI/96));
  end;
begin
  FDoc:=Doc; N:=0;
  if (Doc<>nil) and (Doc.Kind<>gkNone) then N:=Doc.SeriesCount;
  IsLine:=(Doc<>nil) and (Doc.Kind=gkLine);
  if IsLine then FFill:=False;
  Count:=N; if not IsLine then Count:=N*2;
  Old:=Length(FSwatches);
  for I:=Count to Old-1 do FSwatches[I].Free;
  SetLength(FSwatches,Count);
  for I:=Old to Count-1 do
  begin
    FSwatches[I]:=TPanel.Create(Self); FSwatches[I].Parent:=Self;
    FSwatches[I].ParentBackground:=False; FSwatches[I].StyleElements:=[];
    FSwatches[I].OnClick:=SelectColor; FSwatches[I].ShowHint:=True;
  end;
  FIndex:=EnsureRange(FIndex,0,Max(0,N-1));
  FTitle.Caption:='色・スタイル（要素ごと）';
  if (Doc<>nil) and (Doc.Kind=gkRadar) then FTitle.Caption:='色・スタイル（データごと）';
  for I:=0 to Count-1 do
  begin
    if IsLine then
    begin
      Index:=I; FSwatches[I].Tag:=I*2;
      Bounds(FSwatches[I],12+(I mod 7)*39,38+(I div 7)*36,34,30);
      FSwatches[I].Caption:=IntToStr(Index+1);
      C:=Doc.Series[Index].LineColor;
    end else
    begin
      Index:=I div 2; FSwatches[I].Tag:=I;
      Bounds(FSwatches[I],12+(Index mod 3)*90+(I mod 2)*42,38+(Index div 3)*36,40,30);
      if Odd(I) then
      begin FSwatches[I].Caption:=IntToStr(Index+1)+'塗'; C:=Doc.Series[Index].FillColor; end
      else begin FSwatches[I].Caption:=IntToStr(Index+1)+'縁'; C:=Doc.Series[Index].LineColor; end;
    end;
    FSwatches[I].Hint:=IntToStr(Index+1)+' 番の縁・線色';
    if Odd(FSwatches[I].Tag) then FSwatches[I].Hint:=IntToStr(Index+1)+' 番の塗り色';
    FSwatches[I].Color:=TColor(((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF));
    if (((C shr 16) and $FF)*299+((C shr 8) and $FF)*587+(C and $FF)*114)>140000 then
      FSwatches[I].Font.Color:=clBlack else FSwatches[I].Font.Color:=clWhite;
    if (Index=FIndex) and (Odd(FSwatches[I].Tag)=FFill) then
      FSwatches[I].BevelOuter:=bvLowered else FSwatches[I].BevelOuter:=bvRaised;
  end;
  if IsLine then Y:=38+((N+6) div 7)*36 else Y:=38+((N+2) div 3)*36;
  Bounds(FTitle,12,8,272,24);
  Bounds(FSelected,12,Y,272,24); FSelected.Visible:=N>0;
  FSelected.Caption:='選択: '+IntToStr(FIndex+1);
  if FFill then FSelected.Caption:=FSelected.Caption+' 塗り色'
  else FSelected.Caption:=FSelected.Caption+' 縁・線色';
  FMarker.Visible:=IsLine; FKind.Visible:=IsLine;
  FPattern.Visible:=(N>0) and not IsLine;
  Bounds(FMarker,12,Y+28,130,34); Bounds(FKind,150,Y+28,134,34);
  Bounds(FPattern,12,Y+28,256,34);
  FBusy:=True;
  try
    if N>0 then
    begin
      FMarker.ItemIndex:=Doc.Series[FIndex].Marker;
      FKind.ItemIndex:=EnsureRange(Doc.Series[FIndex].LineKind-1,0,2);
      FPattern.ItemIndex:=Doc.Series[FIndex].FillPattern;
    end;
  finally FBusy:=False; end;
  Height:=Round((Y+72)*CurrentPPI/96);
end;
procedure TGraphColorStylePanel.SelectColor(Sender:TObject);
begin
  FIndex:=TPanel(Sender).Tag div 2; FFill:=Odd(TPanel(Sender).Tag); Load(FDoc);
  if Assigned(FOnColorTargetChange) then FOnColorTargetChange(Self);
end;
function TGraphColorStylePanel.GetSelectedColor:TAlphaColor;
begin
  Result:=$FFFFFFFF;
  if (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  if FFill then Result:=FDoc.Series[FIndex].FillColor
  else Result:=FDoc.Series[FIndex].LineColor;
end;
procedure TGraphColorStylePanel.SetSelectedColor(Color:TAlphaColor);
var S:TSeriesStyle;
begin
  if (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  S:=FDoc.Series[FIndex];
  // 縁と塗りを独立して編集し、それぞれの既存アルファを保つ。
  if FFill then S.FillColor:=(S.FillColor and $FF000000) or (Color and $FFFFFF)
  else S.LineColor:=(S.LineColor and $FF000000) or (Color and $FFFFFF);
  FDoc.Series[FIndex]:=S; Load(FDoc);
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TGraphColorStylePanel.StyleChanged(Sender:TObject);
var S:TSeriesStyle;
begin
  if FBusy or (FDoc=nil) or (Length(FSwatches)=0) then Exit;
  S:=FDoc.Series[FIndex];
  if Sender=FPattern then S.FillPattern:=FPattern.ItemIndex
  else begin S.Marker:=FMarker.ItemIndex; S.LineKind:=FKind.ItemIndex+1; end;
  FDoc.Series[FIndex]:=S;
  if Assigned(FOnChange) then FOnChange(Self);
end;
end.
