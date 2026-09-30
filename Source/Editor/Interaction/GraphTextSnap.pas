unit GraphTextSnap;

// 文字・凡例の座標揃え、等間隔、実文字サイズの吸着候補を求める。
// LabelsとDocは呼出側所有。許容距離はシーン座標、Feedbackは現在の操作に限る表示情報。
interface
uses System.Types, GraphModel, GraphPainter;
type
  TTextSnapFeedback=record
    SizeID:Integer;
    HasX,HasY:Boolean;
    X,Y:Single;
    Spacing:Boolean; Horizontal:Boolean;
    SpacingPoints:array[0..2] of TPointF;
  end;
  PTextSnapFeedback=^TTextSnapFeedback;
function SnapTextBounds(const Bounds:TRectF; ID:Integer;
  const Labels:TArray<TGraphLabel>; Tolerance:Single; Feedback:PTextSnapFeedback=nil):TRectF;
function SnapTextScale(Scale:Single; ID:Integer; Role:TTextRole;
  Doc:TGraphDocument; const Labels:TArray<TGraphLabel>; Feedback:PTextSnapFeedback=nil):Single;
function SnapLegendBounds(const Bounds:TRectF; ID:Integer;
  const Labels:TArray<TGraphLabel>; Tolerance:Single; Feedback:PTextSnapFeedback=nil):TRectF;
implementation
uses System.Math;
function SnapTextBounds(const Bounds:TRectF; ID:Integer;
  const Labels:TArray<TGraphLabel>; Tolerance:Single; Feedback:PTextSnapFeedback):TRectF;
var L:TGraphLabel; DX,DY,BestX,BestY,GuideX,GuideY:Single;
  I,J:Integer; A,B,C:TPointF; Role:TTextRole;
  procedure Candidate(X,Y,TargetX,TargetY:Single);
  begin
    if Abs(X)<Abs(BestX) then begin BestX:=X; GuideX:=TargetX; end;
    if Abs(Y)<Abs(BestY) then begin BestY:=Y; GuideY:=TargetY; end;
  end;
  procedure SpacingCandidate(Target:Single; Horizontal:Boolean);
  var Delta:Single;
  begin
    if Horizontal then Delta:=Target-C.X else Delta:=Target-C.Y;
    if Abs(Delta)>Tolerance then Exit;
    if Horizontal then begin if Abs(Delta)>=Abs(BestX) then Exit; end
    else if Abs(Delta)>=Abs(BestY) then Exit;
    if Horizontal then Candidate(Delta,Tolerance+1,Target,0)
    else Candidate(Tolerance+1,Delta,0,Target);
    if Feedback<>nil then
    begin
      Feedback^.Spacing:=True; Feedback^.Horizontal:=Horizontal;
      Feedback^.SpacingPoints[0]:=A; Feedback^.SpacingPoints[1]:=B;
      if Horizontal then Feedback^.SpacingPoints[2]:=PointF(Target,(A.Y+B.Y)/2)
      else Feedback^.SpacingPoints[2]:=PointF((A.X+B.X)/2,Target);
    end;
  end;
begin
  if Feedback<>nil then Feedback^.Spacing:=False;
  GuideX:=0; GuideY:=0;
  BestX:=Tolerance+1; BestY:=Tolerance+1;
  for L in Labels do
    if L.ID<>ID then
    begin
      Candidate(L.Bounds.Left-Bounds.Left,L.Bounds.Top-Bounds.Top,L.Bounds.Left,L.Bounds.Top);
      Candidate(L.Bounds.CenterPoint.X-Bounds.CenterPoint.X,
        L.Bounds.CenterPoint.Y-Bounds.CenterPoint.Y,L.Bounds.CenterPoint.X,L.Bounds.CenterPoint.Y);
      Candidate(L.Bounds.Right-Bounds.Right,L.Bounds.Bottom-Bounds.Bottom,L.Bounds.Right,L.Bounds.Bottom);
    end;
  // 同じ分類の文字が同じ行・列に並ぶ場合、中心間の等間隔位置を候補にする。
  Role:=trName;
  for L in Labels do if L.ID=ID then begin Role:=L.Role; Break; end;
  C:=Bounds.CenterPoint;
  for I:=0 to High(Labels)-1 do
    if (Labels[I].ID<>ID) and (Labels[I].Role=Role) then
      for J:=I+1 to High(Labels) do
        if (Labels[J].ID<>ID) and (Labels[J].Role=Role) then
        begin
          A:=Labels[I].Bounds.CenterPoint; B:=Labels[J].Bounds.CenterPoint;
          if (Abs(A.Y-B.Y)<=Tolerance) and
            (Abs(C.Y-(A.Y+B.Y)/2)<=Tolerance) and (Abs(A.X-B.X)>2*Tolerance) then
          begin
            SpacingCandidate(2*B.X-A.X,True);
            SpacingCandidate(2*A.X-B.X,True);
            SpacingCandidate((A.X+B.X)/2,True);
          end;
          if (Abs(A.X-B.X)<=Tolerance) and
            (Abs(C.X-(A.X+B.X)/2)<=Tolerance) and (Abs(A.Y-B.Y)>2*Tolerance) then
          begin
            SpacingCandidate(2*B.Y-A.Y,False);
            SpacingCandidate(2*A.Y-B.Y,False);
            SpacingCandidate((A.Y+B.Y)/2,False);
          end;
        end;
  DX:=0; DY:=0;
  if Abs(BestX)<=Tolerance then DX:=BestX;
  if Abs(BestY)<=Tolerance then DY:=BestY;
  if Feedback<>nil then
  begin
    Feedback^.HasX:=Abs(BestX)<=Tolerance; Feedback^.X:=GuideX;
    Feedback^.HasY:=Abs(BestY)<=Tolerance; Feedback^.Y:=GuideY;
  end;
  Result:=Bounds; Result.Offset(DX,DY);
end;
function SnapLegendBounds(const Bounds:TRectF; ID:Integer;
  const Labels:TArray<TGraphLabel>; Tolerance:Single; Feedback:PTextSnapFeedback):TRectF;
var Marks:TArray<TGraphLabel>; L:TGraphLabel; Count:Integer;
begin
  SetLength(Marks,Length(Labels)); Count:=0;
  for L in Labels do if L.HasLegend then
  begin
    Marks[Count]:=L; Marks[Count].Bounds:=L.LegendBounds; Inc(Count);
  end;
  SetLength(Marks,Count);
  Result:=SnapTextBounds(Bounds,ID,Marks,Tolerance,Feedback);
end;
function SnapTextScale(Scale:Single; ID:Integer; Role:TTextRole;
  Doc:TGraphDocument; const Labels:TArray<TGraphLabel>; Feedback:PTextSnapFeedback):Single;
var L:TGraphLabel; Size,Target,Difference,Best:Single;
begin
  Result:=Scale; Size:=Doc.TextStyles[Role].Size*Scale;
  Best:=Size*0.06;
  if Feedback<>nil then Feedback^.SizeID:=-1;
  for L in Labels do
    if (L.ID<>ID) and (L.ID>=0) and (L.ID<Length(Doc.LabelScales)) then
    begin
      Target:=Doc.TextStyles[L.Role].Size*Doc.LabelScales[L.ID];
      Difference:=Abs(Target-Size);
      if Difference<=Best then
      begin
        Best:=Difference;
        if Feedback<>nil then Feedback^.SizeID:=L.ID;
        Result:=Target/Doc.TextStyles[Role].Size;
      end;
    end;
end;
end.
