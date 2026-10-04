unit GraphRenderer;

// 編集画面と映像出力で同じ描画を使用し、RGBAは呼出側所有の配列として返す。
interface
uses System.SysUtils, GraphModel, GraphAnimation, GraphPainter;
function RenderGraph(Doc:TGraphDocument; const Shared:TGraphShared;
  const Animation:TGraphAnimation; Width,Height:Integer;
  out Labels:TArray<TGraphLabel>; OnlyLabelID:Integer=-1;
  ExcludeLabelID:Integer=-1):TBytes;
implementation
uses System.Types, System.Skia, GraphValues, GraphCartesian, GraphPolar,
  GraphAnimationFocus, GraphFloatState;

function RenderGraphPixels(Doc:TGraphDocument; const Shared:TGraphShared;
  const Animation:TGraphAnimation; Width,Height:Integer;
  out Labels:TArray<TGraphLabel>; OnlyLabelID:Integer;
  ExcludeLabelID:Integer):TBytes;
var Surface:ISkSurface; P:TGraphPainter; Values:TGraphValues; B:TRectF;
  Focus:TPointF; Zoom:Single; Zoomed:Boolean;
begin
  Result:=nil; Labels:=nil;
  if Doc.Kind=gkNone then Exit;
  if (Width<=0) or (Height<=0) or (Int64(Width)*Height>33554432) then
    raise EArgumentException.Create('描画サイズが範囲外です。');
  Values:=ParseValues(Shared.Values,Doc.Rows,Doc.Columns);
  Surface:=TSkSurface.MakeRaster(Width,Height);
  if Surface=nil then raise EOutOfMemory.Create('描画領域を確保できません。');
  Surface.Canvas.Clear(0);
  Zoom:=Animation.ZoomScale; Zoomed:=Zoom>1;
  if Zoomed then
  begin
    Focus:=CurrentGraphFocus(Doc,Values,Animation);
    Surface.Canvas.Save;
    // 映像の外へ拡大描画が漏れないように、変換前のフレームで切り取る。
    Surface.Canvas.ClipRect(RectF(0,0,Width,Height));
    Surface.Canvas.Translate(Focus.X,Focus.Y);
    Surface.Canvas.Scale(Zoom,Zoom);
    Surface.Canvas.Translate(-Focus.X,-Focus.Y);
  end;
  P:=TGraphPainter.Create(Surface.Canvas,Doc,1);
  try
    P.OnlyLabelID:=OnlyLabelID;
    P.ExcludeLabelID:=ExcludeLabelID;
    if Doc.Kind in [gkRadar,gkPie] then DrawPolar(P,Shared,Values,Animation)
    else DrawCartesian(P,Shared,Values,Animation);
    B:=Doc.Bounds;
    P.Line(B.TopLeft,PointF(B.Right,B.Top),Doc.Lines[3]);
    P.Line(PointF(B.Right,B.Top),B.BottomRight,Doc.Lines[3]);
    P.Line(B.BottomRight,PointF(B.Left,B.Bottom),Doc.Lines[3]);
    P.Line(PointF(B.Left,B.Bottom),B.TopLeft,Doc.Lines[3]);
    P.Text(Shared.Title,trTitle,0,PointF(B.CenterPoint.X,B.Top-55));
    P.Text(Shared.Units,trUnit,1,PointF(B.Left-40,B.Top-15));
    // 文字は全形状の後に描く。拡大変換を解除する前なので文字も同じ座標系に従う。
    P.FlushText;
    Labels:=P.Labels.ToArray;
    SetLength(Result,NativeInt(Width)*Height*4);
    // ホストABIは非乗算RGBA。Skia内部の乗算アルファから明示的に変換する。
    if not Surface.ReadPixels(TSkImageInfo.Create(Width,Height,TSkColorType.RGBA8888,
      TSkAlphaType.Unpremul),@Result[0],Width*4) then
      raise EInvalidOp.Create('描画画像を読み出せません。');
  finally
    P.Free;
    if Zoomed then Surface.Canvas.Restore;
  end;
end;

function RenderGraph(Doc:TGraphDocument; const Shared:TGraphShared;
  const Animation:TGraphAnimation; Width,Height:Integer;
  out Labels:TArray<TGraphLabel>; OnlyLabelID:Integer;
  ExcludeLabelID:Integer):TBytes;
var PreviousMXCSR:Cardinal;
begin
  // Skiaの初期化は最初のスレッドだけ例外をマスクする。再生スレッドでも
  // ネイティブ描画中は同じ条件にし、除算等の内部計算で映像出力を中断させない。
  // 下位関数のSkia参照解放まで終えてから、呼出元のマスク・丸め・状態を戻す。
  PreviousMXCSR:=BeginGraphFloatScope;
  try
    Result:=RenderGraphPixels(Doc,Shared,Animation,Width,Height,Labels,
      OnlyLabelID,ExcludeLabelID);
  finally RestoreGraphFloatScope(PreviousMXCSR); end;
end;
end.
