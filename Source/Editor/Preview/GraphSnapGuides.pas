unit GraphSnapGuides;

// 吸着先の枠・座標線・等間隔の両矢印を編集キャンバスだけへ描く。
// CanvasとLabelsは呼出側所有で、この呼出し中だけ参照する。保存・映像出力には関与しない。
interface
uses System.Types, Vcl.Graphics, GraphPainter, GraphTextSnap;
procedure DrawSnapGuides(Canvas:TCanvas; const Labels:TArray<TGraphLabel>;
  const Feedback:TTextSnapFeedback; PanX,PanY,Zoom:Single; ClientWidth,ClientHeight:Integer);
implementation
procedure DrawSpacingGuides(Canvas:TCanvas; const Feedback:TTextSnapFeedback;
  PanX,PanY,Zoom:Single);
var Positions:array[0..2] of Integer; I,J,Temp,LinePos:Integer;
  Horizontal:Boolean;
  procedure Line(A,B:Integer);
  begin
    if Horizontal then begin Canvas.MoveTo(A,LinePos); Canvas.LineTo(B,LinePos); end
    else begin Canvas.MoveTo(LinePos,A); Canvas.LineTo(LinePos,B); end;
  end;
  procedure Arrow(Position,Direction:Integer);
  begin
    if Horizontal then
    begin
      Canvas.MoveTo(Position+Direction*5,LinePos-4); Canvas.LineTo(Position,LinePos);
      Canvas.LineTo(Position+Direction*5,LinePos+4);
    end else
    begin
      Canvas.MoveTo(LinePos-4,Position+Direction*5); Canvas.LineTo(LinePos,Position);
      Canvas.LineTo(LinePos+4,Position+Direction*5);
    end;
  end;
begin
  if not Feedback.Spacing then Exit;
  Horizontal:=Feedback.Horizontal;
  for I:=0 to 2 do
    if Horizontal then Positions[I]:=Round(PanX+Feedback.SpacingPoints[I].X*Zoom)
    else Positions[I]:=Round(PanY+Feedback.SpacingPoints[I].Y*Zoom);
  for I:=0 to 1 do for J:=I+1 to 2 do
    if Positions[J]<Positions[I] then
    begin Temp:=Positions[I]; Positions[I]:=Positions[J]; Positions[J]:=Temp; end;
  if Horizontal then LinePos:=Round(PanY+Feedback.SpacingPoints[0].Y*Zoom)+24
  else LinePos:=Round(PanX+Feedback.SpacingPoints[0].X*Zoom)+24;
  Canvas.Pen.Style:=psSolid;
  for I:=0 to 1 do
  begin
    Line(Positions[I],Positions[I+1]);
    Arrow(Positions[I],1); Arrow(Positions[I+1],-1);
  end;
end;

procedure DrawSnapGuides(Canvas:TCanvas; const Labels:TArray<TGraphLabel>;
  const Feedback:TTextSnapFeedback; PanX,PanY,Zoom:Single; ClientWidth,ClientHeight:Integer);
var B:TRectF; I,X,Y:Integer;
begin
    Canvas.Pen.Color:=$0000DFFF; Canvas.Pen.Style:=psDash;
    Canvas.Brush.Style:=bsClear;
    I:=-1;
    for X:=0 to High(Labels) do if Labels[X].ID=Feedback.SizeID then begin I:=X; Break; end;
    if I>=0 then
    begin
      B:=Labels[I].Bounds;
      Canvas.Rectangle(Round(PanX+B.Left*Zoom)-3,Round(PanY+B.Top*Zoom)-3,
        Round(PanX+B.Right*Zoom)+3,Round(PanY+B.Bottom*Zoom)+3);
    end;
    if Feedback.HasX then
    begin X:=Round(PanX+Feedback.X*Zoom); Canvas.MoveTo(X,0); Canvas.LineTo(X,ClientHeight); end;
    if Feedback.HasY then
    begin Y:=Round(PanY+Feedback.Y*Zoom); Canvas.MoveTo(0,Y); Canvas.LineTo(ClientWidth,Y); end;
    DrawSpacingGuides(Canvas,Feedback,PanX,PanY,Zoom);
    Canvas.Pen.Style:=psSolid;
end;
end.
