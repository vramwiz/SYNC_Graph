unit GraphViewBitmapCache;

// ドラッグ中の追従表示に使う画像を、透明画素を除いて保持・合成する。
interface

uses System.Classes, System.SysUtils, System.Types, Vcl.Graphics;

procedure CacheRgbaLayer(Bitmap:Vcl.Graphics.TBitmap; out Crop:TRect; const Pixels:TBytes;
  Width,Height:Integer);
procedure DrawRgbaLayer(Canvas:TCanvas; Bitmap:Vcl.Graphics.TBitmap; const Crop:TRect;
  const Origin,Current:TRectF; PanX,PanY,Zoom:Single);

implementation

uses System.Math, Winapi.Windows;

procedure CacheRgbaLayer(Bitmap:Vcl.Graphics.TBitmap; out Crop:TRect; const Pixels:TBytes;
  Width,Height:Integer);
var X,Y,L,T,R,B,A:Integer; Src,Dest:PByte;
begin
  Bitmap.SetSize(0,0);
  if (Width<=0) or (Height<=0) or
    (Length(Pixels)<>Int64(Width)*Height*4) then Exit;
  L:=Width; T:=Height; R:=-1; B:=-1;
  for Y:=0 to Height-1 do
    for X:=0 to Width-1 do
      if Pixels[(NativeInt(Y)*Width+X)*4+3]<>0 then
      begin
        L:=Min(L,X); T:=Min(T,Y); R:=Max(R,X); B:=Max(B,Y);
      end;
  if R<L then Exit;
  Crop:=Rect(L,T,R+1,B+1);
  Bitmap.PixelFormat:=pf32bit;
  Bitmap.SetSize(Crop.Width,Crop.Height);
  // 入力は呼出元所有のRGBA。UIスレッド上で呼出元所有のBitmapへBGRAでコピーし、
  // AlphaBlend用にRGBだけ前乗算する。元のバッファは変更しない。
  for Y:=0 to Crop.Height-1 do
  begin
    Src:=@Pixels[(NativeInt(Y+T)*Width+L)*4];
    Dest:=Bitmap.ScanLine[Y];
    for X:=0 to Crop.Width-1 do
    begin
      A:=Src[3];
      Dest[0]:=(Integer(Src[2])*A+127) div 255;
      Dest[1]:=(Integer(Src[1])*A+127) div 255;
      Dest[2]:=(Integer(Src[0])*A+127) div 255;
      Dest[3]:=A;
      Inc(Src,4); Inc(Dest,4);
    end;
  end;
end;

procedure DrawRgbaLayer(Canvas:TCanvas; Bitmap:Vcl.Graphics.TBitmap; const Crop:TRect;
  const Origin,Current:TRectF; PanX,PanY,Zoom:Single);
var SX,SY:Double; Target:TRect; Blend:TBlendFunction;
begin
  if Bitmap.Empty or (Origin.Width<=0) or (Origin.Height<=0) then Exit;
  SX:=Current.Width/Origin.Width; SY:=Current.Height/Origin.Height;
  Target:=Rect(
    Round(PanX+(Current.Left+(Crop.Left-Origin.Left)*SX)*Zoom),
    Round(PanY+(Current.Top+(Crop.Top-Origin.Top)*SY)*Zoom),
    Round(PanX+(Current.Left+(Crop.Right-Origin.Left)*SX)*Zoom),
    Round(PanY+(Current.Top+(Crop.Bottom-Origin.Top)*SY)*Zoom));
  Blend.BlendOp:=AC_SRC_OVER; Blend.BlendFlags:=0;
  Blend.SourceConstantAlpha:=255; Blend.AlphaFormat:=AC_SRC_ALPHA;
  if (Target.Width>0) and (Target.Height>0) then
    AlphaBlend(Canvas.Handle,Target.Left,Target.Top,Target.Width,Target.Height,
      Bitmap.Canvas.Handle,0,0,Bitmap.Width,Bitmap.Height,Blend);
end;

end.
