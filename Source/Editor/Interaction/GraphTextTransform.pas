unit GraphTextTransform;

// 文字枠のハンドル操作を個別倍率・位置へ変換し、値では分類の共通サイズを変更する。
// Docは呼出側所有。ドラッグ開始時の値を基準にし、吸着後も微小移動で固着しないようにする。
interface
uses System.Types, GraphModel, GraphPainter, GraphTextSnap;
function ResizeGraphText(Doc:TGraphDocument; I:Integer; Role:TTextRole;
  const Labels:TArray<TGraphLabel>; const OldB:TRectF; const InitialOffset,D:TPointF;
  InitialScale,InitialSize:Single; Handle:Integer; var Feedback:TTextSnapFeedback):TRectF;
implementation
uses System.Math, GraphViewBounds;
function ResizeGraphText(Doc:TGraphDocument; I:Integer; Role:TTextRole;
  const Labels:TArray<TGraphLabel>; const OldB:TRectF; const InitialOffset,D:TPointF;
  InitialScale,InitialSize:Single; Handle:Integer; var Feedback:TTextSnapFeedback):TRectF;
var NewB:TRectF; WX,HY,Factor,Size,ActualSize,Target,Difference,Best,Baseline:Single;
  L:TGraphLabel;
begin
  if (OldB.Width<=0) or (OldB.Height<=0) then Exit(OldB);
  NewB:=OldB;
  ResizeBoundsHandle(NewB,Handle,D,10);
  WX:=NewB.Width/OldB.Width; HY:=NewB.Height/OldB.Height;
  if Abs(WX-1)>=Abs(HY-1) then Factor:=WX else Factor:=HY;
  if Role=trValue then
  begin
    Size:=EnsureRange(InitialSize*Factor,1.0,500.0);
    ActualSize:=Size*InitialScale;
    Best:=ActualSize*0.06; Feedback:=Default(TTextSnapFeedback); Feedback.SizeID:=-1;
    // 同分類も同時に変わるので吸着先から除外し、他分類の実サイズだけに合わせる。
    for L in Labels do
      if (L.Role<>trValue) and (L.ID>=0) and (L.ID<Length(Doc.LabelScales)) then
      begin
        Target:=Doc.TextStyles[L.Role].Size*Doc.LabelScales[L.ID];
        Difference:=Abs(Target-ActualSize);
        if Difference<=Best then
        begin Best:=Difference; Size:=Target/InitialScale; Feedback.SizeID:=L.ID; end;
      end;
    Doc.TextStyles[trValue].Size:=EnsureRange(Size,1.0,500.0);
    Factor:=Doc.TextStyles[trValue].Size/InitialSize;
    // 全値の標準位置と既存の補正を保ち、共通サイズに合わせて基線から枠を更新する。
    Baseline:=OldB.Top+OldB.Height*0.8;
    Exit(RectF(OldB.CenterPoint.X-OldB.Width*Factor/2,Baseline-OldB.Height*0.8*Factor,
      OldB.CenterPoint.X+OldB.Width*Factor/2,Baseline+OldB.Height*0.2*Factor));
  end;
  Doc.LabelScales[I]:=EnsureRange(SnapTextScale(
    InitialScale*Factor,I,Role,Doc,Labels,@Feedback),0.1,20.0);
  Factor:=Doc.LabelScales[I]/InitialScale;
  // 描画の文字枠はベースラインに対して上下非対称なので、中心移動に基線の補正を加える。
  Doc.Offsets[I]:=InitialOffset+PointF(
    NewB.CenterPoint.X-OldB.CenterPoint.X,
    NewB.CenterPoint.Y-OldB.CenterPoint.Y+
      0.3*OldB.Height*(Factor-1));
  Result:=RectF(NewB.CenterPoint.X-OldB.Width*Factor/2,
    NewB.CenterPoint.Y-OldB.Height*Factor/2,
    NewB.CenterPoint.X+OldB.Width*Factor/2,
    NewB.CenterPoint.Y+OldB.Height*Factor/2);
end;
end.
