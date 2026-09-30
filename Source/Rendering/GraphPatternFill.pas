unit GraphPatternFill;

// 面のクリップと模様描画を担当する。線間隔は出力座標で固定し、隣接三角形でも模様を連続させる。
interface
uses System.Skia;
procedure DrawPatternFill(const Canvas:ISkCanvas; const Shape:ISkPath;
  const Paint:ISkPaint; Pattern:Integer);
implementation
uses System.Types, System.Math;
procedure DrawPatternFill(const Canvas:ISkCanvas; const Shape:ISkPath;
  const Paint:ISkPaint; Pattern:Integer);
var B:TRectF; X:Single;
begin
  if Pattern=0 then Exit;
  if Pattern=1 then begin Canvas.DrawPath(Shape,Paint); Exit; end;
  B:=Shape.Bounds;
  Canvas.Save;
  try
    Canvas.ClipPath(Shape,TSkClipOp.Intersect,True);
    Paint.Style:=TSkPaintStyle.Stroke; Paint.StrokeWidth:=1.5;
    if Pattern in [2,4] then
    begin
      X:=Floor((B.Left+B.Top)/10)*10;
      while X<=B.Right+B.Bottom do
      begin
        Canvas.DrawLine(PointF(X-B.Top,B.Top),PointF(X-B.Bottom,B.Bottom),Paint);
        X:=X+10;
      end;
    end;
    if Pattern in [3,4] then
    begin
      X:=Floor((B.Left-B.Bottom)/10)*10;
      while X<=B.Right-B.Top do
      begin
        Canvas.DrawLine(PointF(X+B.Top,B.Top),PointF(X+B.Bottom,B.Bottom),Paint);
        X:=X+10;
      end;
    end;
  finally Canvas.Restore; end;
end;
end.
