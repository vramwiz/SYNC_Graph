unit GraphRenderer;

// 編集画面と映像出力で同じ描画を使用し、RGBAは呼出側所有の配列として返す。
interface
uses System.SysUtils, GraphModel, GraphAnimation, GraphPainter;
function RenderGraph(Doc:TGraphDocument; const Shared:TGraphShared;
  const Animation:TGraphAnimation; Width,Height:Integer;
  out Labels:TArray<TGraphLabel>; OnlyLabelID:Integer=-1;
  ExcludeLabelID:Integer=-1):TBytes;
implementation
uses System.Types, System.Skia, GraphValues, GraphCartesian, GraphPolar;

function RenderGraph(Doc:TGraphDocument; const Shared:TGraphShared;
  const Animation:TGraphAnimation; Width,Height:Integer;
  out Labels:TArray<TGraphLabel>; OnlyLabelID:Integer;
  ExcludeLabelID:Integer):TBytes;
var Surface:ISkSurface; P:TGraphPainter; Values:TGraphValues; B:TRectF;
begin
  Result:=nil; Labels:=nil;
  if Doc.Kind=gkNone then Exit;
  if (Width<=0) or (Height<=0) or (Int64(Width)*Height>33554432) then
    raise EArgumentException.Create('描画サイズが範囲外です。');
  Values:=ParseValues(Shared.Values,Doc.Rows,Doc.Columns);
  Surface:=TSkSurface.MakeRaster(Width,Height);
  if Surface=nil then raise EOutOfMemory.Create('描画領域を確保できません。');
  Surface.Canvas.Clear(0);
  P:=TGraphPainter.Create(Surface.Canvas,Doc,Animation.Opacity);
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
    Labels:=P.Labels.ToArray;
    SetLength(Result,NativeInt(Width)*Height*4);
    // ホストABIは非乗算RGBA。Skia内部の乗算アルファから明示的に変換する。
    if not Surface.ReadPixels(TSkImageInfo.Create(Width,Height,TSkColorType.RGBA8888,
      TSkAlphaType.Unpremul),@Result[0],Width*4) then
      raise EInvalidOp.Create('描画画像を読み出せません。');
  finally P.Free; end;
end;
end.
