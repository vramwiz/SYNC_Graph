unit GraphAnimationFocus;

// 現在進行中のセルから、演出拡大の中心となる描画位置を求める。
interface

uses System.Types, GraphModel, GraphValues, GraphAnimation;

function CurrentGraphFocus(Doc:TGraphDocument; const Values:TGraphValues;
  const Animation:TGraphAnimation):TPointF;

implementation

uses System.Math;

function CurrentGraphFocus(Doc:TGraphDocument; const Values:TGraphValues;
  const Animation:TGraphAnimation):TPointF;
var Row,Column,I:Integer; B:TRectF; Scale:TGraphScale;
  Shape,Value,Base,Category,Radius,Angle,Total,Start:Double;
begin
  B:=Doc.Bounds; Result:=B.CenterPoint;
  Animation.ActiveCell(Doc.Rows,Doc.Columns,Row,Column);
  Shape:=Animation.ShapeProgress(Row,Column,Doc.Rows,Doc.Columns);
  if Doc.Kind=gkPie then
  begin
    Total:=0; Start:=-90+Doc.Rotation;
    for I:=0 to Doc.Rows-1 do Total:=Total+Max(0,Values[I,0]);
    if Total<=0 then Exit;
    for I:=0 to Row-1 do Start:=Start+Values[I,0]/Total*360;
    Angle:=DegToRad(Start+Values[Row,0]/Total*180*Shape);
    Radius:=Min(B.Width,B.Height)*0.3;
    Exit(PointF(Result.X+Cos(Angle)*Radius,Result.Y+Sin(Angle)*Radius));
  end;
  Scale:=CalculateScale(Doc,Values);
  if Doc.Kind=gkRadar then
  begin
    Radius:=Min(B.Width,B.Height)/2;
    Radius:=Radius*EnsureRange((Values[Row,Column]-Scale.Minimum)/
      (Scale.Maximum-Scale.Minimum),0.0,1.0)*Shape;
    Angle:=DegToRad(-90+Doc.Rotation+Row*360/Doc.Rows);
    Exit(PointF(Result.X+Cos(Angle)*Radius,Result.Y+Sin(Angle)*Radius));
  end;
  Value:=Values[Row,Column]*Shape;
  if Doc.Kind=gkBar then
  begin
    Base:=0;
    if Doc.Stacked then
      for I:=0 to Row-1 do
        if (Values[I,Column]>=0)=(Values[Row,Column]>=0) then
          Base:=Base+Values[I,Column]*
            Animation.ShapeProgress(I,Column,Doc.Rows,Doc.Columns);
    Value:=Base+Value;
    Category:=(Column+0.5)/Doc.Columns;
  end
  else if Doc.Columns=1 then Category:=0.5
  else Category:=Column/(Doc.Columns-1);
  Value:=EnsureRange((Value-Scale.Minimum)/(Scale.Maximum-Scale.Minimum),0.0,1.0);
  if Doc.Horizontal then Result:=PointF(B.Left+B.Width*Value,B.Top+B.Height*Category)
  else Result:=PointF(B.Left+B.Width*Category,B.Bottom-B.Height*Value);
end;

end.
