unit GraphStylePanel;

// 線描画の箇所ごとに色・太さ・線種を横並びで編集する。
interface
uses System.Classes, System.Types, System.UITypes, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Controls, HorizontalTrackBarControl, GraphModel;
type
  TGraphStylePanel=class(TPanel)
  private
    FLabels:array[0..5] of TLabel;
    FColors,FOutlineColors:array[0..5] of TPanel;
    FWidths,FOutlineWidths:array[0..5] of THorizontalTrackBarControl;
    FKinds:array[0..5] of TComboBox;
    FDoc:TGraphDocument;
    FRowCaptions:array[0..5] of string;
    FWidthChanging:Boolean;
    FOnEditFinished:TNotifyEvent;
    FIndex:Integer;
    FOutline,FBusy:Boolean;
    FOnChange,FOnColorTargetChange:TNotifyEvent;
    procedure SelectColor(Sender:TObject);
    procedure WidthReleased(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure StyleChanged(Sender:TObject);
    procedure DrawLineKind(Control:TWinControl; Index:Integer; Rect:TRect; State:TOwnerDrawState);
    function GetSelectedColor:TAlphaColor;
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Doc:TGraphDocument);
    procedure RefreshValues;
    procedure Apply;
    procedure SetSelectedColor(Color:TAlphaColor);
    property WidthChanging:Boolean read FWidthChanging;
    property OnEditFinished:TNotifyEvent read FOnEditFinished write FOnEditFinished;
    property SelectedColor:TAlphaColor read GetSelectedColor;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property OnColorTargetChange:TNotifyEvent read FOnColorTargetChange write FOnColorTargetChange;
  end;
implementation
uses System.SysUtils, System.Math, Vcl.Graphics, Winapi.Windows;
constructor TGraphStylePanel.Create(AOwner:TComponent);
var I:Integer; L:TLabel;
  function S(Value:Integer):Integer;
  begin Result:=MulDiv(Value,CurrentPPI,96); end;
  function Swatch(Tag:Integer):TPanel;
  begin
    Result:=TPanel.Create(Self); Result.Parent:=Self; Result.Tag:=Tag;
    Result.ParentBackground:=False; Result.StyleElements:=[];
    Result.BevelOuter:=bvRaised; Result.ShowHint:=True; Result.Hint:='クリックして色を編集';
    Result.OnClick:=SelectColor;
  end;
  function Slider(Tag:Integer):THorizontalTrackBarControl;
  begin
    Result:=THorizontalTrackBarControl.Create(Self); Result.Parent:=Self; Result.Tag:=Tag;
    Result.SetRange(0,200); Result.ShowTicks:=False; Result.WheelChangesPosition:=True;
    Result.ShowHint:=True; Result.OnChange:=StyleChanged; Result.OnMouseUp:=WidthReleased;
  end;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=S(290); Height:=S(620); BevelOuter:=bvNone; Color:=$00303030;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='線（色・太さ・線種）'; L.SetBounds(S(12),S(8),S(272),S(24));
  for I:=0 to 5 do
  begin
    FLabels[I]:=TLabel.Create(Self); FLabels[I].Parent:=Self;
    FColors[I]:=Swatch(I); FOutlineColors[I]:=Swatch(I+6);
    FWidths[I]:=Slider(I); FOutlineWidths[I]:=Slider(I+6);
    FKinds[I]:=TComboBox.Create(Self); FKinds[I].Parent:=Self; FKinds[I].Tag:=I;
    FKinds[I].Style:=csOwnerDrawFixed; FKinds[I].ItemHeight:=S(28); FKinds[I].DropDownWidth:=S(160);
    FKinds[I].Color:=$00303030; FKinds[I].Font.Color:=$00EEEEEE;
    FKinds[I].Items.Add('なし'); FKinds[I].Items.Add('実線');
    FKinds[I].Items.Add('破線'); FKinds[I].Items.Add('点線');
    FKinds[I].OnDrawItem:=DrawLineKind; FKinds[I].OnChange:=StyleChanged;
  end;
end;
procedure TGraphStylePanel.Load(Doc:TGraphDocument);
var I,Y:Integer; ShowRow,ElementStyle:Boolean; Caption:string; L:TLineStyle;
  procedure Bounds(Control:TControl; X,Y,W,H:Integer);
  begin
    Control.SetBounds(MulDiv(X,CurrentPPI,96),MulDiv(Y,CurrentPPI,96),
      MulDiv(W,CurrentPPI,96),MulDiv(H,CurrentPPI,96));
  end;
  procedure PaintSwatch(Control:TPanel; C:TAlphaColor);
  begin Control.Color:=TColor(((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF)); end;
begin
  FDoc:=Doc; if Doc=nil then Exit;
  FBusy:=True;
  try
    Y:=38;
    for I:=0 to 5 do
    begin
      ShowRow:=True; ElementStyle:=((Doc.Kind<>gkNone) and (I=4)) or ((Doc.Kind=gkPie) and (I=5));
      case I of
        0:begin
          Caption:='X軸・基準線';
          if Doc.Kind=gkRadar then Caption:='放射軸';
          if Doc.Kind=gkPie then Caption:='要素名の引出線';
        end;
        1:begin Caption:='Y軸'; ShowRow:=Doc.Kind in [gkNone,gkLine,gkBar]; end;
        2:begin Caption:='目盛り'; ShowRow:=Doc.Kind<>gkPie; end;
        3:Caption:='グラフ領域の外枠';
        4:begin
          ShowRow:=Doc.Kind<>gkPie;
          Caption:='データの外周';
          if Doc.Kind=gkRadar then Caption:='データの外周（色はデータ設定）';
          if Doc.Kind=gkBar then Caption:='棒の縁';
          if Doc.Kind=gkLine then Caption:='折れ線（色・線種は要素設定）';
        end;
        5:begin Caption:='扇形の外周・区切り'; ShowRow:=Doc.Kind in [gkNone,gkPie]; end;
      end;
      L:=Doc.Lines[I];
      FRowCaptions[I]:=Caption;
      FLabels[I].Caption:=Caption+Format('  %.1f',[L.Width]);
      FLabels[I].Visible:=ShowRow; FColors[I].Visible:=ShowRow and not ElementStyle;
      FWidths[I].Visible:=ShowRow; FKinds[I].Visible:=ShowRow and not ((Doc.Kind=gkLine) and (I=4));
      FOutlineColors[I].Visible:=ShowRow;
      FOutlineWidths[I].Visible:=ShowRow;
      Bounds(FLabels[I],12,Y,272,24);
      Bounds(FColors[I],12,Y+26,30,30);
      Bounds(FWidths[I],50,Y+26,94,30);
      Bounds(FKinds[I],152,Y+26,116,32);
      FKinds[I].DropDownWidth:=MulDiv(160,CurrentPPI,96);
      Bounds(FOutlineColors[I],12,Y+62,30,30);
      Bounds(FOutlineWidths[I],50,Y+62,94,30);
      FWidths[I].Position:=EnsureRange(Round(L.Width*10),0,200);
      FOutlineWidths[I].Position:=EnsureRange(Round(L.OutlineWidth*10),0,200);
      FWidths[I].Hint:=Format('線太さ %.1f',[L.Width]);
      FOutlineWidths[I].Hint:=Format('縁取り太さ %.1f',[L.OutlineWidth]);
      FKinds[I].ItemIndex:=EnsureRange(L.Kind,0,3);
      PaintSwatch(FColors[I],L.Color); PaintSwatch(FOutlineColors[I],L.OutlineColor);
      if ShowRow then Inc(Y,104);
    end;
    Height:=MulDiv(Y+8,CurrentPPI,96);
  finally FBusy:=False; end;
end;
procedure TGraphStylePanel.SelectColor(Sender:TObject);
var Tag:Integer;
begin
  Tag:=TControl(Sender).Tag; FIndex:=Tag mod 6; FOutline:=Tag>=6;
  if Assigned(FOnColorTargetChange) then FOnColorTargetChange(Self);
end;
function TGraphStylePanel.GetSelectedColor:TAlphaColor;
begin
  Result:=$FFFFFFFF; if FDoc=nil then Exit;
  if FOutline then Result:=FDoc.Lines[FIndex].OutlineColor else Result:=FDoc.Lines[FIndex].Color;
end;
procedure TGraphStylePanel.SetSelectedColor(Color:TAlphaColor);
var L:TLineStyle;
begin
  if FDoc=nil then Exit;
  Color:=(SelectedColor and $FF000000) or (Color and $FFFFFF);
  if Color=SelectedColor then Exit;
  L:=FDoc.Lines[FIndex];
  if FOutline then L.OutlineColor:=Color else L.Color:=Color;
  FDoc.Lines[FIndex]:=L; RefreshValues;
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TGraphStylePanel.StyleChanged(Sender:TObject);
var I:Integer; L:TLineStyle;
begin
  if FBusy or (FDoc=nil) then Exit;
  I:=TControl(Sender).Tag mod 6; L:=FDoc.Lines[I];
  if Sender=FKinds[I] then L.Kind:=FKinds[I].ItemIndex
  else if Sender=FWidths[I] then L.Width:=FWidths[I].Position/10
  else L.OutlineWidth:=FOutlineWidths[I].Position/10;
  FDoc.Lines[I]:=L;
  // 操作中は対象行の文字だけを更新し、全行の再配置を避ける。
  FLabels[I].Caption:=FRowCaptions[I]+Format('  %.1f',[L.Width]);
  FWidths[I].Hint:=Format('線太さ %.1f',[L.Width]);
  FOutlineWidths[I].Hint:=Format('縁取り太さ %.1f',[L.OutlineWidth]);
  FWidthChanging:=Sender is THorizontalTrackBarControl;
  try
    if Assigned(FOnChange) then FOnChange(Self);
  finally FWidthChanging:=False; end;
end;
procedure TGraphStylePanel.WidthReleased(Sender:TObject; Button:TMouseButton;
  Shift:TShiftState; X,Y:Integer);
begin
  if (Button=mbLeft) and Assigned(FOnEditFinished) then FOnEditFinished(Self);
end;
procedure TGraphStylePanel.DrawLineKind(Control:TWinControl; Index:Integer;
  Rect:TRect; State:TOwnerDrawState);
var C:TCanvas; X,Y,EndX,LengthOn,LengthOff:Integer;
begin
  C:=TComboBox(Control).Canvas;
  if odSelected in State then C.Brush.Color:=$00613F20 else C.Brush.Color:=$00303030;
  C.FillRect(Rect); C.Font.Color:=$00EEEEEE;
  if (Index<0) or (Index>=TComboBox(Control).Items.Count) then Exit;
  if Index=0 then
  begin C.TextOut(Rect.Left+4,Rect.Top+5,'なし'); Exit; end;
  Y:=(Rect.Top+Rect.Bottom) div 2;
  C.Font.Assign(TComboBox(Control).Font);
  X:=Rect.Left+C.TextWidth(TComboBox(Control).Items[Index])+12; EndX:=Rect.Right-4;
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
  C.TextOut(Rect.Left+4,Rect.Top+5,TComboBox(Control).Items[Index]);
end;

procedure TGraphStylePanel.RefreshValues;
begin Load(FDoc); end;
procedure TGraphStylePanel.Apply;
begin end;
end.
