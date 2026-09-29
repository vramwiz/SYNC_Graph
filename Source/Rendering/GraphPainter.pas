unit GraphPainter;

// Skiaによる線・塗り・文字装飾と、編集用の文字ヒット領域を共通化する。
interface
uses System.Types, System.UITypes, System.Skia, System.Generics.Collections, GraphModel;
type
  TGraphLabel = record ID:Integer; Role:TTextRole; Bounds:TRectF; end;
  TGraphPainter = class
  public
    Canvas: ISkCanvas;
    Doc: TGraphDocument;
    Labels: TList<TGraphLabel>;
    Opacity: Single;
    OnlyLabelID, ExcludeLabelID:Integer;
    constructor Create(const ACanvas:ISkCanvas; ADoc:TGraphDocument; AOpacity:Single);
    destructor Destroy; override;
    procedure Line(const A,B:TPointF; const Style:TLineStyle; Alpha:Single=1);
    procedure Path(const Points:TArray<TPointF>; Closed:Boolean;
      Fill,Stroke:TAlphaColor; Alpha:Single=1);
    procedure Box(const R:TRectF; Fill,Stroke:TAlphaColor; Alpha:Single=1);
    procedure Marker(const P:TPointF; Kind:Integer; Color:TAlphaColor; Alpha:Single);
    procedure Text(const Value:string; Role:TTextRole; ID:Integer;
      const Position:TPointF; Alpha:Single=1);
    function Paint(Color:TAlphaColor; Alpha:Single=1):ISkPaint;
  end;
implementation
uses System.Math;

constructor TGraphPainter.Create(const ACanvas:ISkCanvas; ADoc:TGraphDocument; AOpacity:Single);
begin
  inherited Create; Canvas:=ACanvas; Doc:=ADoc; Opacity:=AOpacity;
  Labels:=TList<TGraphLabel>.Create;
  OnlyLabelID:=-1; ExcludeLabelID:=-1;
end;
destructor TGraphPainter.Destroy;
begin Labels.Free; inherited; end;

function TGraphPainter.Paint(Color:TAlphaColor; Alpha:Single):ISkPaint;
begin
  Result:=TSkPaint.Create; Result.AntiAlias:=True;
  Result.Color:=Color;
  Result.AlphaF:=((Color shr 24)/255)*Alpha*Opacity;
end;

procedure TGraphPainter.Line(const A,B:TPointF; const Style:TLineStyle; Alpha:Single);
var P:ISkPaint;
begin
  if OnlyLabelID>=0 then Exit;
  if (Style.Kind=0) or (Alpha<=0) then Exit;
  P:=Paint(Style.Color,Alpha); P.Style:=TSkPaintStyle.Stroke; P.StrokeWidth:=Style.Width;
  if Style.Kind=2 then P.PathEffect:=TSkPathEffect.MakeDash([8,5],0);
  if Style.Kind=3 then P.PathEffect:=TSkPathEffect.MakeDash([2,4],0);
  if Style.OutlineWidth>0 then
  begin
    P.Color:=Style.OutlineColor; P.AlphaF:=((Style.OutlineColor shr 24)/255)*Opacity*Alpha;
    P.StrokeWidth:=Style.Width+2*Style.OutlineWidth;
    Canvas.DrawLine(A,B,P);
    P.Color:=Style.Color; P.AlphaF:=((Style.Color shr 24)/255)*Opacity*Alpha;
    P.StrokeWidth:=Style.Width;
  end;
  Canvas.DrawLine(A,B,P);
end;

procedure TGraphPainter.Path(const Points:TArray<TPointF>; Closed:Boolean;
  Fill,Stroke:TAlphaColor; Alpha:Single);
var B:ISkPathBuilder; P:ISkPaint; I:Integer; Shape:ISkPath; Style:TLineStyle;
begin
  if OnlyLabelID>=0 then Exit;
  if Length(Points)=0 then Exit;
  B:=TSkPathBuilder.Create; B.MoveTo(Points[0]);
  for I:=1 to High(Points) do B.LineTo(Points[I]);
  if Closed then B.Close;
  Shape:=B.Detach;
  if Closed then Canvas.DrawPath(Shape,Paint(Fill,Alpha));
  Style:=Doc.Lines[4];
  if Doc.Kind=gkPie then Style:=Doc.Lines[5];
  if Style.Kind=0 then Exit;
  P:=Paint(Stroke,Alpha); P.Style:=TSkPaintStyle.Stroke; P.StrokeWidth:=Style.Width;
  if Style.Kind=2 then P.PathEffect:=TSkPathEffect.MakeDash([8,5],0);
  if Style.Kind=3 then P.PathEffect:=TSkPathEffect.MakeDash([2,4],0);
  if Style.OutlineWidth>0 then
  begin
    P.Color:=Style.OutlineColor; P.AlphaF:=((Style.OutlineColor shr 24)/255)*Alpha*Opacity;
    P.StrokeWidth:=Style.Width+Style.OutlineWidth*2; Canvas.DrawPath(Shape,P);
    P.Color:=Stroke; P.AlphaF:=((Stroke shr 24)/255)*Alpha*Opacity; P.StrokeWidth:=Style.Width;
  end;
  Canvas.DrawPath(Shape,P);
end;

procedure TGraphPainter.Box(const R:TRectF; Fill,Stroke:TAlphaColor; Alpha:Single);
begin
  Path([R.TopLeft,PointF(R.Right,R.Top),R.BottomRight,PointF(R.Left,R.Bottom)],True,Fill,Stroke,Alpha);
end;

procedure TGraphPainter.Marker(const P:TPointF; Kind:Integer; Color:TAlphaColor; Alpha:Single);
begin
  if OnlyLabelID>=0 then Exit;
  if Kind=1 then Canvas.DrawCircle(P.X,P.Y,5,Paint(Color,Alpha))
  else if Kind=2 then Box(RectF(P.X-5,P.Y-5,P.X+5,P.Y+5),Color,Color,Alpha);
end;

procedure TGraphPainter.Text(const Value:string; Role:TTextRole; ID:Integer;
  const Position:TPointF; Alpha:Single);
var S:TTextStyle; Font:ISkFont; Face:ISkTypeface; FS:TSkFontStyle;
  P:ISkPaint; X,Y,W:Single; L:TGraphLabel; Weight:Integer; Slant:TSkFontSlant;
begin
  if (Value='') or (Alpha<=0) then Exit;
  if ((OnlyLabelID>=0) and (ID<>OnlyLabelID)) or
    ((ExcludeLabelID>=0) and (ID=ExcludeLabelID)) then Exit;
  S:=Doc.TextStyles[Role]; Weight:=400; if S.Bold then Weight:=700;
  Slant:=TSkFontSlant.Upright; if S.Italic then Slant:=TSkFontSlant.Italic;
  FS:=TSkFontStyle.Create(Weight,5,Slant);
  if (ID>=0) and (ID<Length(Doc.LabelScales)) then S.Size:=S.Size*Doc.LabelScales[ID];
  Face:=TSkTypeface.MakeFromName(S.Font,FS); Font:=TSkFont.Create(Face,S.Size);
  W:=Font.MeasureText(Value); X:=Position.X-W/2; Y:=Position.Y;
  if (ID>=0) and (ID<Length(Doc.Offsets)) then
  begin X:=X+Doc.Offsets[ID].X; Y:=Y+Doc.Offsets[ID].Y; end;
  if (S.ShadowX<>0) or (S.ShadowY<>0) or (S.ShadowBlur>0) then
  begin
    P:=Paint(S.ShadowColor,Alpha);
    if S.ShadowBlur>0 then P.MaskFilter:=TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal,S.ShadowBlur);
    Canvas.DrawSimpleText(Value,X+S.ShadowX,Y+S.ShadowY,Font,P);
  end;
  if S.OutlineWidth>0 then
  begin
    P:=Paint(S.OutlineColor,Alpha); P.Style:=TSkPaintStyle.Stroke; P.StrokeWidth:=2*S.OutlineWidth;
    if S.OutlineBlur>0 then P.MaskFilter:=TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal,S.OutlineBlur);
    Canvas.DrawSimpleText(Value,X,Y,Font,P);
  end;
  Canvas.DrawSimpleText(Value,X,Y,Font,Paint(S.Color,Alpha));
  if ID>=0 then
  begin L.ID:=ID; L.Role:=Role; L.Bounds:=RectF(X,Y-S.Size,W+X,Y+S.Size*0.25); Labels.Add(L); end;
end;
end.
