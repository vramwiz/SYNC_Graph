unit GraphViewBounds;

// グラフ枠と文字枠に共通する8点ハンドルの描画・判定・寸法変更を扱う。
interface

uses System.Types, Vcl.Graphics;

procedure DrawBoundsHandles(Canvas:TCanvas; const Bounds:TRectF;
  PanX,PanY,Zoom:Single);
function HitBoundsHandle(const Bounds:TRectF; X,Y:Integer;
  PanX,PanY,Zoom:Single):Integer;
procedure ResizeBoundsHandle(var Bounds:TRectF; Handle:Integer;
  const Delta:TPointF; Minimum:Single);

implementation

uses System.Math;

procedure DrawBoundsHandles(Canvas:TCanvas; const Bounds:TRectF;
  PanX,PanY,Zoom:Single);
var R:TRect; I,HX,HY:Integer;
begin
  R:=Rect(Round(PanX+Bounds.Left*Zoom),Round(PanY+Bounds.Top*Zoom),
    Round(PanX+Bounds.Right*Zoom),Round(PanY+Bounds.Bottom*Zoom));
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=$00E9B456; Canvas.Pen.Style:=psDot;
  Canvas.Rectangle(R); Canvas.Pen.Style:=psSolid;
  Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=$00E9B456;
  for I:=0 to 7 do
  begin
    case I of
      0,3,5:HX:=R.Left;
      1,6:HX:=(R.Left+R.Right) div 2;
    else HX:=R.Right; end;
    case I of
      0,1,2:HY:=R.Top;
      3,4:HY:=(R.Top+R.Bottom) div 2;
    else HY:=R.Bottom; end;
    Canvas.Rectangle(HX-5,HY-5,HX+6,HY+6);
  end;
end;

function HitBoundsHandle(const Bounds:TRectF; X,Y:Integer;
  PanX,PanY,Zoom:Single):Integer;
var L,T,R,D,CX,CY:Integer;
begin
  Result:=-3;
  L:=Round(PanX+Bounds.Left*Zoom); T:=Round(PanY+Bounds.Top*Zoom);
  R:=Round(PanX+Bounds.Right*Zoom); D:=Round(PanY+Bounds.Bottom*Zoom);
  CX:=(L+R) div 2; CY:=(T+D) div 2;
  if (Abs(X-L)<=7) and (Abs(Y-T)<=7) then Result:=0
  else if (Abs(X-CX)<=7) and (Abs(Y-T)<=7) then Result:=1
  else if (Abs(X-R)<=7) and (Abs(Y-T)<=7) then Result:=2
  else if (Abs(X-L)<=7) and (Abs(Y-CY)<=7) then Result:=3
  else if (Abs(X-R)<=7) and (Abs(Y-CY)<=7) then Result:=4
  else if (Abs(X-L)<=7) and (Abs(Y-D)<=7) then Result:=5
  else if (Abs(X-CX)<=7) and (Abs(Y-D)<=7) then Result:=6
  else if (Abs(X-R)<=7) and (Abs(Y-D)<=7) then Result:=7;
end;

procedure ResizeBoundsHandle(var Bounds:TRectF; Handle:Integer;
  const Delta:TPointF; Minimum:Single);
begin
  if Handle in [0,3,5] then
    Bounds.Left:=Min(Bounds.Right-Minimum,Bounds.Left+Delta.X);
  if Handle in [2,4,7] then
    Bounds.Right:=Max(Bounds.Left+Minimum,Bounds.Right+Delta.X);
  if Handle in [0,1,2] then
    Bounds.Top:=Min(Bounds.Bottom-Minimum,Bounds.Top+Delta.Y);
  if Handle in [5,6,7] then
    Bounds.Bottom:=Max(Bounds.Top+Minimum,Bounds.Bottom+Delta.Y);
end;

end.
