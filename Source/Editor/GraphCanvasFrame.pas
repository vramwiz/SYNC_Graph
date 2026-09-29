unit GraphCanvasFrame;

// 灰色の作業面上に影とトンボを描く。編集専用で映像レンダラーには依存しない。
interface
uses Vcl.Graphics, System.Types;
procedure DrawCanvasFrame(Canvas:TCanvas; const R:TRect);
implementation
uses Winapi.Windows;
procedure DrawCanvasFrame(Canvas:TCanvas; const R:TRect);
var I,X,Y,SX,SY:Integer;
begin
  Canvas.Pen.Style:=psClear;
  for I:=8 downto 1 do
  begin
    Canvas.Brush.Color:=RGB(75-I*3,75-I*3,75-I*3);
    Canvas.Rectangle(R.Left+I,R.Top+I,R.Right+I,R.Bottom+I);
  end;
  Canvas.Pen.Style:=psSolid; Canvas.Pen.Color:=$00D0D0D0;
  for SX:=0 to 1 do for SY:=0 to 1 do
  begin
    if SX=0 then X:=R.Left else X:=R.Right;
    if SY=0 then Y:=R.Top else Y:=R.Bottom;
    Canvas.MoveTo(X-18,Y); Canvas.LineTo(X-5,Y);
    Canvas.MoveTo(X+5,Y); Canvas.LineTo(X+18,Y);
    Canvas.MoveTo(X,Y-18); Canvas.LineTo(X,Y-5);
    Canvas.MoveTo(X,Y+5); Canvas.LineTo(X,Y+18);
  end;
end;
end.
