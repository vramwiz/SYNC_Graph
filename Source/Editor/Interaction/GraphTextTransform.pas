unit GraphTextTransform;

// 文字枠のハンドル操作を個別倍率とオフセットへ変換する。
// Docは呼出側所有。ドラッグ開始時の値を基準にし、吸着後も微小移動で固着しないようにする。
interface
uses System.Types, GraphModel, GraphPainter, GraphTextSnap;
function ResizeGraphText(Doc:TGraphDocument; I:Integer; Role:TTextRole;
  const Labels:TArray<TGraphLabel>; const OldB:TRectF; const InitialOffset,D:TPointF;
  InitialScale:Single; Handle:Integer; var Feedback:TTextSnapFeedback):TRectF;
implementation
uses System.Math, GraphViewBounds;
function ResizeGraphText(Doc:TGraphDocument; I:Integer; Role:TTextRole;
  const Labels:TArray<TGraphLabel>; const OldB:TRectF; const InitialOffset,D:TPointF;
  InitialScale:Single; Handle:Integer; var Feedback:TTextSnapFeedback):TRectF;
var NewB:TRectF; WX,HY,Factor:Single;
begin
  NewB:=OldB;
  ResizeBoundsHandle(NewB,Handle,D,10);
  WX:=NewB.Width/OldB.Width; HY:=NewB.Height/OldB.Height;
  if Abs(WX-1)>=Abs(HY-1) then Factor:=WX else Factor:=HY;
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
