unit GraphTextDecorations;

// 選択文字の装飾ハンドルについて、配置・描画・ドラッグ値を一か所で扱う。
interface

uses System.Types, GraphModel, Vcl.Graphics;

function HitTextDecoration(X,Y:Integer; const Bounds:TRectF;
  PPI,ClientWidth,ClientHeight:Integer; PanX,PanY,Zoom:Single):Integer;
procedure DrawTextDecorations(Canvas:TCanvas; const Bounds:TRectF;
  const Style:TTextStyle; PPI,ClientWidth,ClientHeight:Integer;
  PanX,PanY,Zoom:Single);
function DragTextDecoration(const Initial:TTextStyle; Kind:Integer;
  const Delta:TPointF):TTextStyle;

implementation

uses System.Math, System.SysUtils, Winapi.Windows;

function DecorationPoint(Kind:Integer; const Bounds:TRectF;
  PPI,ClientWidth,ClientHeight:Integer; PanX,PanY,Zoom:Single):TPoint;
var Step,Margin,StartX,Y:Integer;
begin
  Step:=MulDiv(34,PPI,96);
  Margin:=MulDiv(20,PPI,96);
  StartX:=EnsureRange(Round(PanX+Bounds.Left*Zoom)+Margin,
    Margin,Max(Margin,ClientWidth-Margin-3*Step));
  Y:=EnsureRange(Round(PanY+Bounds.Bottom*Zoom)+MulDiv(28,PPI,96),
    Margin,Max(Margin,ClientHeight-Margin));
  Result:=Point(StartX+Kind*Step,Y);
end;

function HitTextDecoration(X,Y:Integer; const Bounds:TRectF;
  PPI,ClientWidth,ClientHeight:Integer; PanX,PanY,Zoom:Single):Integer;
var K,Radius:Integer; P:TPoint;
begin
  Result:=-1; Radius:=MulDiv(13,PPI,96);
  for K:=0 to 3 do
  begin
    P:=DecorationPoint(K,Bounds,PPI,ClientWidth,ClientHeight,PanX,PanY,Zoom);
    if (Abs(X-P.X)<=Radius) and (Abs(Y-P.Y)<=Radius) then Exit(K);
  end;
end;

procedure DrawTextDecorations(Canvas:TCanvas; const Bounds:TRectF;
  const Style:TTextStyle; PPI,ClientWidth,ClientHeight:Integer;
  PanX,PanY,Zoom:Single);
const Captions:array[0..3] of string=('縁','影','縁ぼ','影ぼ');
var K,Radius:Integer; P:TPoint; Active:Boolean; Value:string;
begin
  Radius:=MulDiv(12,PPI,96);
  Canvas.Font.Name:='Yu Gothic UI'; Canvas.Font.Size:=8;
  Canvas.Pen.Color:=$00E9B456;
  for K:=0 to 3 do
  begin
    P:=DecorationPoint(K,Bounds,PPI,ClientWidth,ClientHeight,PanX,PanY,Zoom);
    case K of
      0:begin Active:=Style.OutlineWidth>0; Value:=IntToStr(Round(Style.OutlineWidth)); end;
      1:begin Active:=(Style.ShadowX<>0) or (Style.ShadowY<>0);
          Value:=Format('%d,%d',[Round(Style.ShadowX),Round(Style.ShadowY)]); end;
      2:begin Active:=Style.OutlineBlur>0; Value:=IntToStr(Round(Style.OutlineBlur)); end;
    else Active:=Style.ShadowBlur>0; Value:=IntToStr(Round(Style.ShadowBlur)); end;
    if Active then Canvas.Brush.Color:=$004A3B24 else Canvas.Brush.Color:=$00303030;
    Canvas.Ellipse(P.X-Radius,P.Y-Radius,P.X+Radius+1,P.Y+Radius+1);
    Canvas.Brush.Style:=bsClear; Canvas.Font.Color:=$00E9B456;
    Canvas.TextOut(P.X-Canvas.TextWidth(Captions[K]) div 2,
      P.Y-Canvas.TextHeight(Captions[K]) div 2,Captions[K]);
    Canvas.Font.Color:=$00EEEEEE;
    Canvas.TextOut(P.X-Canvas.TextWidth(Value) div 2,P.Y+Radius+2,Value);
    Canvas.Brush.Style:=bsSolid;
  end;
end;

function DragTextDecoration(const Initial:TTextStyle; Kind:Integer;
  const Delta:TPointF):TTextStyle;
begin
  Result:=Initial;
  case Kind of
    0:begin
        Result.OutlineWidth:=EnsureRange(Round(Initial.OutlineWidth+Delta.X/4),0,30);
        if Result.OutlineWidth=0 then Result.OutlineBlur:=0;
      end;
    1:begin
        Result.ShadowX:=EnsureRange(Round(Initial.ShadowX+Delta.X),-100,100);
        Result.ShadowY:=EnsureRange(Round(Initial.ShadowY+Delta.Y),-100,100);
        // 影を無効に戻しやすいよう、原点付近だけ吸着させる。
        if Abs(Result.ShadowX)<=2 then Result.ShadowX:=0;
        if Abs(Result.ShadowY)<=2 then Result.ShadowY:=0;
        if (Result.ShadowX=0) and (Result.ShadowY=0) then Result.ShadowBlur:=0;
      end;
    2:begin
        Result.OutlineBlur:=EnsureRange(Round(Initial.OutlineBlur+Delta.X/4),0,30);
        if (Result.OutlineBlur>0) and (Result.OutlineWidth=0) then Result.OutlineWidth:=1;
      end;
    3:Result.ShadowBlur:=EnsureRange(Round(Initial.ShadowBlur+Delta.X/4),0,30);
  end;
end;

end.
