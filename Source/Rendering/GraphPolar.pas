unit GraphPolar;

// N角形・円の専用描画。系列進行は描画時に求め、履歴やタイマーを持たない。
interface
uses GraphModel, GraphValues, GraphAnimation, GraphPainter;
procedure DrawPolar(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
implementation
uses System.Types, System.Math, System.SysUtils;

procedure DrawPolar(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
var D:TGraphDocument; Center:TPointF; Radius,Angle,Start,Sweep,Total,F,T:Double;
  R,C,I,Steps:Integer; Points:TArray<TPointF>; S:TGraphScale; Style:TSeriesStyle; A,Q:TPointF;
  function Polar(Degrees,Distance:Double):TPointF;
  begin Result:=PointF(Center.X+Cos(DegToRad(Degrees))*Distance,Center.Y+Sin(DegToRad(Degrees))*Distance); end;
begin
  D:=P.Doc; Center:=D.Bounds.CenterPoint;
  Radius:=Min(D.Bounds.Width,D.Bounds.Height)/2;
  if D.Kind=gkRadar then
  begin
    if D.Rows<3 then raise EConvertError.Create('N角形は要素数を3以上にしてください。');
    S:=CalculateScale(D,Values);
    T:=Ceil(S.Minimum/S.Step)*S.Step; I:=0;
    while (T<=S.Maximum) and (I<=1000) do
    begin
      F:=(T-S.Minimum)/(S.Maximum-S.Minimum);
      for R:=0 to D.Rows-1 do
        P.Line(Polar(-90+D.Rotation+R*360/D.Rows,Radius*F),
          Polar(-90+D.Rotation+(R+1)*360/D.Rows,Radius*F),D.Lines[2]);
      T:=T+S.Step; Inc(I);
    end;
    for R:=0 to D.Rows-1 do
    begin
      Angle:=-90+D.Rotation+R*360/D.Rows;
      P.Line(Center,Polar(Angle,Radius),D.Lines[0]);
      F:=1.15; if D.NameLayout=1 then F:=0.85 else if D.NameLayout=2 then F:=1.3;
      P.Text(ElementName(Shared.Names,R),trName,2+R,Polar(Angle,Radius*F));
    end;
    for C:=0 to D.Columns-1 do
    begin
      SetLength(Points,D.Rows); Style:=D.Series[C];
      for R:=0 to D.Rows-1 do
      begin
        F:=EnsureRange((Values[R,C]-S.Minimum)/(S.Maximum-S.Minimum),0.0,1.0)*Animation.Element(C);
        Points[R]:=Polar(-90+D.Rotation+R*360/D.Rows,Radius*F);
      end;
      if Animation.Element(C)>0 then
      begin
        P.Path(Points,True,Style.FillColor,Style.LineColor,1-Style.Transparency/100);
        for R:=0 to D.Rows-1 do
          P.Text(FormatGraphValue(Values[R,C],D.ValueFormat),trValue,
            2+MaxGraphRows+R*MaxGraphColumns+C,Points[R]);
      end;
    end;
  end else
  begin
    Total:=0;
    for R:=0 to D.Rows-1 do
    begin
      if Values[R,0]<0 then raise EConvertError.Create('円グラフの値は0以上にしてください。');
      Total:=Total+Values[R,0];
    end;
    if Total=0 then Exit;
    Start:=-90+D.Rotation;
    for R:=0 to D.Rows-1 do
    begin
      Sweep:=Values[R,0]/Total*360; Style:=D.Series[R];
      F:=Animation.Element(R); Steps:=Max(1,Ceil(Sweep*F/2));
      if (F>0) and (Sweep>0) then
      begin
        SetLength(Points,Steps+2); Points[0]:=Center;
        for I:=0 to Steps do Points[I+1]:=Polar(Start+Sweep*F*I/Steps,Radius);
        P.Path(Points,True,Style.FillColor,Style.LineColor,1-Style.Transparency/100);
        Angle:=Start+Sweep/2; T:=0.65;
        if D.NameLayout<>0 then T:=1.18;
        A:=Polar(Angle,Radius*T);
        if D.NameLayout=2 then
        begin Q:=Polar(Angle,Radius*0.9); P.Line(Q,A,D.Lines[0]); end;
        P.Text(ElementName(Shared.Names,R),trName,2+R,A);
        P.Text(FormatGraphValue(Values[R,0],D.ValueFormat),trValue,
          2+MaxGraphRows+R*MaxGraphColumns,Polar(Angle,Radius*0.45));
      end;
      Start:=Start+Sweep;
    end;
  end;
end;
end.
