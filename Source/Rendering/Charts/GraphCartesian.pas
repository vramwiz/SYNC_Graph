unit GraphCartesian;

// 折れ線・棒・積み重ね棒の座標と目盛。縦横は同じ正規化座標から変換する。
interface
uses GraphModel, GraphValues, GraphAnimation, GraphPainter;
procedure DrawCartesian(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
implementation
uses System.Types, System.Math, System.SysUtils;

procedure DrawCartesian(P:TGraphPainter; const Shared:TGraphShared;
  const Values:TGraphValues; const Animation:TGraphAnimation);
var D:TGraphDocument; S:TGraphScale; B:TRectF; R,C,I:Integer;
  T,V,CurrentValue,Base,Top,Shape,CellAlpha,NameAlpha,UnitSize,Width,Start:Double;
  A,Q,Prev,PointNow:TPointF; PosSum,NegSum:TArray<Double>; Style:TSeriesStyle; SeriesLine:TLineStyle;
  function Map(Category,Value:Double):TPointF;
  var F:Double;
  begin
    F:=EnsureRange((Value-S.Minimum)/(S.Maximum-S.Minimum),0.0,1.0);
    if D.Horizontal then Result:=PointF(B.Left+F*B.Width,B.Top+Category*B.Height)
    else Result:=PointF(B.Left+Category*B.Width,B.Bottom-F*B.Height);
  end;
begin
  D:=P.Doc; B:=D.Bounds; S:=CalculateScale(D,Values);
  T:=Ceil(S.Minimum/S.Step)*S.Step; I:=0;
  while (T<=S.Maximum+S.Step*0.00001) and (I<=1000) do
  begin
    A:=Map(0,T); Q:=Map(1,T); P.Line(A,Q,D.Lines[2]);
    if D.Horizontal then P.Text(FormatFloat('0.##',T,TFormatSettings.Invariant),trValue,-1,PointF(A.X,B.Bottom+30))
    else P.Text(FormatFloat('0.##',T,TFormatSettings.Invariant),trValue,-1,PointF(B.Left-45,A.Y+8));
    T:=T+S.Step; Inc(I);
  end;
  P.Line(Map(0,0),Map(1,0),D.Lines[0]);
  P.Line(Map(0,S.Minimum),Map(0,S.Maximum),D.Lines[1]);
  SetLength(PosSum,D.Columns); SetLength(NegSum,D.Columns);
  UnitSize:=1/D.Columns;
  for R:=0 to D.Rows-1 do
  begin
    Style:=D.Series[R]; NameAlpha:=0;
    SeriesLine:=D.Lines[4]; SeriesLine.Kind:=Style.LineKind; SeriesLine.Color:=Style.LineColor;
    for C:=0 to D.Columns-1 do
    begin
      V:=Values[R,C]; Base:=0;
      Shape:=Animation.ShapeProgress(R,C,D.Rows,D.Columns);
      CellAlpha:=Animation.CellOpacity(R,C,D.Rows,D.Columns);
      NameAlpha:=Max(NameAlpha,CellAlpha);
      CurrentValue:=V*Shape;
      if D.Kind=gkBar then
      begin
        if D.Stacked then
        begin
          if V>=0 then Base:=PosSum[C] else Base:=NegSum[C];
          Width:=UnitSize*0.7; Start:=C*UnitSize+UnitSize*0.15;
        end else
        begin Width:=UnitSize*0.7/D.Rows; Start:=C*UnitSize+UnitSize*0.15+R*Width; end;
        Top:=Base+CurrentValue;
        if CellAlpha>0 then
        begin
          A:=Map(Start,Base); Q:=Map(Start+Width*0.92,Top);
          P.Box(RectF(Min(A.X,Q.X),Min(A.Y,Q.Y),Max(A.X,Q.X),Max(A.Y,Q.Y)),
            Style.FillColor,D.Lines[4].Color,(1-Style.Transparency/100)*CellAlpha);
          PointNow:=Map(Start+Width/2,Top);
          P.Text(FormatGraphValue(CurrentValue,D.ValueFormat),trValue,
            2+MaxGraphRows+R*MaxGraphColumns+C,PointF(PointNow.X,PointNow.Y-8),CellAlpha);
        end;
        if V>=0 then PosSum[C]:=Top else NegSum[C]:=Top;
      end else
      begin
        if D.Columns=1 then T:=0.5 else T:=C/(D.Columns-1);
        PointNow:=Map(T,CurrentValue);
        if (C>0) and (CellAlpha>0) then
          P.Line(Prev,PointNow,SeriesLine,
            (1-Style.Transparency/100)*CellAlpha);
        if CellAlpha>0 then
        begin
          P.Marker(PointNow,Style.Marker,Style.LineColor,
            (1-Style.Transparency/100)*CellAlpha);
          P.Text(FormatGraphValue(CurrentValue,D.ValueFormat),trValue,
            2+MaxGraphRows+R*MaxGraphColumns+C,
            PointF(PointNow.X,PointNow.Y-10),CellAlpha);
        end;
        Prev:=PointNow;
      end;
    end;
    // 系列名は標準の凡例位置を基準とし、個別の相対位置だけを保存する。
    case D.NameLayout of
      1: A:=PointF(B.Right+95,B.Top+R*38+30);
      2: A:=PointF(B.Left+R*150+75,B.Top-20);
    else A:=PointF(B.Left+R*150+75,B.Bottom+65); end;
    if D.Kind=gkBar then P.Marker(PointF(A.X-60,A.Y-8),1,Style.FillColor,NameAlpha)
    else P.Marker(PointF(A.X-60,A.Y-8),1,Style.LineColor,NameAlpha);
    P.Text(ElementName(Shared.Names,R),trName,2+R,A,NameAlpha);
  end;
end;
end.
