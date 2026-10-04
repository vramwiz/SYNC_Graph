unit GraphPolar;

// N角形・円の専用描画。系列進行は描画時に求め、履歴やタイマーを持たない。
interface
uses GraphModel, GraphValues, GraphAnimation, GraphPainter;
procedure DrawPolar(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
implementation
uses System.Types, System.Math, System.SysUtils, GraphRadarGeometry;

procedure DrawPolar(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
var Geometry:TGraphRadarGeometry; D:TGraphDocument; Center:TPointF; Radius,Angle,Start,Sweep,Total,F,T:Double;
  Shape,CellAlpha,PairAlpha,FillAlpha:Single; AllStarted:Boolean;
  R,C,I,Steps,Pass:Integer; Points:TArray<TPointF>; S:TGraphScale; Style:TSeriesStyle; Edge:TLineStyle; A,Q:TPointF;
  function Polar(Degrees,Distance:Double):TPointF;
  begin
    if D.Kind=gkRadar then Exit(Geometry.PointAt(Degrees,Distance/Radius));
    Result:=PointF(Center.X+Cos(DegToRad(Degrees))*Distance,Center.Y+Sin(DegToRad(Degrees))*Distance);
  end;
  procedure DrawRadarAxes;
  var R,I:Integer; T,F,Angle:Double; A:TPointF;
  begin
    T:=Ceil(S.Minimum/S.Step)*S.Step; I:=0;
    while (T<=S.Maximum) and (I<=1000) do
    begin
      F:=(T-S.Minimum)/(S.Maximum-S.Minimum);
      for R:=0 to D.Rows-1 do
        P.Line(Polar(-90+D.Rotation+R*360/D.Rows,Radius*F),
          Polar(-90+D.Rotation+(R+1)*360/D.Rows,Radius*F),D.Lines[2]);
      // 目盛値は最初の放射軸にだけ添え、各軸に重複して配置しない。
      A:=Polar(-90+D.Rotation,Radius*F);
      P.Text(FormatFloat('0.##',T,TFormatSettings.Invariant),trValue,-1,PointF(A.X-24,A.Y));
      T:=T+S.Step; Inc(I);
    end;
    for R:=0 to D.Rows-1 do
    begin
      Angle:=-90+D.Rotation+R*360/D.Rows;
      P.Line(Center,Polar(Angle,Radius),D.Lines[0]);
      F:=1.15; if D.NameLayout=1 then F:=0.85 else if D.NameLayout=2 then F:=1.3;
      P.Text(ElementName(Shared.Names,R),trName,2+R,Polar(Angle,Radius*F));
    end;
  end;
begin
  D:=P.Doc; Center:=D.Bounds.CenterPoint;
  Radius:=Min(D.Bounds.Width,D.Bounds.Height)/2;
  if D.Kind=gkRadar then
  begin
    Geometry:=TGraphRadarGeometry.Fit(D.Bounds,D.Rows,D.Rotation);
    Center:=Geometry.Center; Radius:=1;
    S:=CalculateScale(D,Values);
    // 面、輪郭、値の順に全データを描き、後の面が先の輪郭を覆うのを防ぐ。
    for Pass:=0 to 2 do
    begin
    // 面と全データの輪郭の後に軸・目盛線を重ね、一致する位置でも基準線を見失わない。
    if Pass=2 then DrawRadarAxes;
    for C:=0 to D.Columns-1 do
    begin
      SetLength(Points,D.Rows); Style:=D.Series[C];
      Edge:=D.Lines[4]; Edge.Color:=Style.LineColor;
      // 全データの面を同じ不透明度にし、最背面も他のデータと対等に混色する。
      // 既存透明度・進行フェードは別に乗算し、輪郭には自動透過補正を適用しない。
      FillAlpha:=0.4;
      AllStarted:=True;
      for R:=0 to D.Rows-1 do
      begin
        Shape:=Animation.ShapeProgress(R,C,D.Rows,D.Columns);
        CellAlpha:=Animation.CellOpacity(R,C,D.Rows,D.Columns);
        if CellAlpha<=0 then AllStarted:=False;
        F:=EnsureRange((Values[R,C]-S.Minimum)/(S.Maximum-S.Minimum),0.0,1.0)*Shape;
        Points[R]:=Polar(-90+D.Rotation+R*360/D.Rows,Radius*F);
      end;
      // 隣の頂点が動き始めた時点で、中心と2頂点で囲む面を描く。
      for R:=1 to D.Rows-1 do
      begin
        PairAlpha:=Min(Animation.CellOpacity(R-1,C,D.Rows,D.Columns),
          Animation.CellOpacity(R,C,D.Rows,D.Columns))*(1-Style.Transparency/100);
        if (Pass=0) and (PairAlpha>0) then
          P.Path([Center,Points[R-1],Points[R]],True,Style.FillColor,0,PairAlpha*FillAlpha,Style.FillPattern);
        if Pass=1 then P.Line(Points[R-1],Points[R],Edge,PairAlpha);
      end;
      if AllStarted then
      begin
        PairAlpha:=Min(Animation.CellOpacity(D.Rows-1,C,D.Rows,D.Columns),
          Animation.CellOpacity(0,C,D.Rows,D.Columns))*(1-Style.Transparency/100);
        if Pass=0 then
          P.Path([Center,Points[High(Points)],Points[0]],True,Style.FillColor,0,PairAlpha*FillAlpha,Style.FillPattern);
        if Pass=1 then P.Line(Points[High(Points)],Points[0],Edge,PairAlpha);
      end;
      if Pass=2 then
      for R:=0 to D.Rows-1 do
      begin
        Shape:=Animation.ShapeProgress(R,C,D.Rows,D.Columns);
        CellAlpha:=Animation.CellOpacity(R,C,D.Rows,D.Columns);
        P.Text(FormatGraphValue(S.Minimum+(Values[R,C]-S.Minimum)*Shape,
          D.ValueFormat),trValue,2+MaxGraphRows+R*MaxGraphColumns+C,
          Points[R],CellAlpha);
      end;
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
      Shape:=Animation.ShapeProgress(R,0,D.Rows,1);
      CellAlpha:=Animation.CellOpacity(R,0,D.Rows,1);
      Steps:=Max(1,Ceil(Sweep*Shape/2));
      if (CellAlpha>0) and (Sweep>0) then
      begin
        SetLength(Points,Steps+2); Points[0]:=Center;
        for I:=0 to Steps do Points[I+1]:=Polar(Start+Sweep*Shape*I/Steps,Radius);
        P.Path(Points,True,Style.FillColor,Style.LineColor,
          (1-Style.Transparency/100)*CellAlpha,Style.FillPattern);
        Angle:=Start+Sweep*Shape/2; T:=0.65;
        if D.NameLayout<>0 then T:=1.18;
        A:=Polar(Angle,Radius*T);
        if D.NameLayout=2 then
        begin Q:=Polar(Angle,Radius*0.9); P.Line(Q,A,D.Lines[0],CellAlpha); end;
        P.Text(ElementName(Shared.Names,R),trName,2+R,A,CellAlpha);
        P.Text(FormatGraphValue(Values[R,0]*Shape,D.ValueFormat),trValue,
          2+MaxGraphRows+R*MaxGraphColumns,Polar(Angle,Radius*0.45),CellAlpha);
      end;
      Start:=Start+Sweep;
    end;
  end;
end;
end.
