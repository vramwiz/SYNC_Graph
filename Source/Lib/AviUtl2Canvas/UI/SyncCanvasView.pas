unit SyncCanvasView;

// A reusable snapshot canvas. Pan and zoom change only the editor viewport.
interface

uses
  System.Classes, System.Types, System.SysUtils, Vcl.Controls, Vcl.Graphics;

type
  TSyncCanvasView = class(TCustomControl)
  private
    FBitmap: TBitmap;
    FZoom, FPanX, FPanY: Double;
    FLastMouse: TPoint;
    FDragging: Boolean;
    FOnViewChanged: TNotifyEvent;
    procedure Changed;
  protected
    procedure PaintSurround(const R: TRect); virtual;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetRgba(const Pixels: TBytes; Width, Height: Integer);
    procedure SetView(Zoom, PanX, PanY: Double);
    procedure ZoomAt(Factor: Double; const ClientPoint: TPoint);
    procedure PanBy(DX, DY: Integer);
    procedure Fit;
    property Zoom: Double read FZoom;
    property PanX: Double read FPanX;
    property PanY: Double read FPanY;
    property OnViewChanged: TNotifyEvent read FOnViewChanged write FOnViewChanged;
  end;

implementation

uses System.Math, Winapi.Windows;

constructor TSyncCanvasView.Create(AOwner: TComponent);
begin
  inherited;
  FBitmap := Vcl.Graphics.TBitmap.Create;
  FZoom := 1;
  DoubleBuffered := True;
  TabStop := True;
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TSyncCanvasView.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TSyncCanvasView.Changed;
begin
  Invalidate;
  if Assigned(FOnViewChanged) then FOnViewChanged(Self);
end;

procedure TSyncCanvasView.SetView(Zoom, PanX, PanY: Double);
begin
  if IsNan(Zoom) or IsInfinite(Zoom) or IsNan(PanX) or IsInfinite(PanX) or
    IsNan(PanY) or IsInfinite(PanY) then
    raise EArgumentException.Create('Invalid viewport values');
  FZoom := EnsureRange(Zoom, 0.01, 32.0);
  FPanX := EnsureRange(PanX, -1000000.0, 1000000.0);
  FPanY := EnsureRange(PanY, -1000000.0, 1000000.0);
  Changed;
end;

procedure TSyncCanvasView.SetRgba(const Pixels: TBytes; Width, Height: Integer);
var X, Y, C, A, Background: Integer; Src, Dest: PByte;
begin
  if (Width <= 0) or (Height <= 0) then
  begin
    FBitmap.SetSize(0, 0);
    Changed;
    Exit;
  end;
  if (Width > 16384) or (Height > 16384) or
    (Length(Pixels) <> Int64(Width) * Height * 4) then
    raise EArgumentException.Create('Invalid RGBA buffer size');
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(Width, Height);
  // Convert once, including transparency over a checkerboard. Paint does no pixel scans.
  for Y := 0 to Height - 1 do
  begin
    Src := @Pixels[NativeInt(Y) * Width * 4];
    Dest := FBitmap.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Background := 0; // 編集表示の透明部分は黒。出力画像には含めない。
      A := Src[3];
      for C := 0 to 2 do Dest[C] := (Integer(Src[2-C]) * A + Background * (255-A)) div 255;
      Dest[3] := 255;
      Inc(Src, 4);
      Inc(Dest, 4);
    end;
  end;
  Changed;
end;

procedure TSyncCanvasView.PaintSurround(const R: TRect);
begin
  // 利用側が影・トンボなど編集用の外側装飾を追加できる。
end;

procedure TSyncCanvasView.Paint;
var R: TRect; Saved: Integer;
begin
  Canvas.Brush.Color := $00505050;
  Canvas.FillRect(ClientRect);
  if FBitmap.Empty then
  begin
    Canvas.Font.Color := clWhite;
    Canvas.TextOut(24, 24, '背景を取得できません。AviUtl2で対象フレームを表示し、設定を開き直してください。');
    Exit;
  end;
  R := Rect(Round(FPanX), Round(FPanY), Round(FPanX + FBitmap.Width * FZoom),
    Round(FPanY + FBitmap.Height * FZoom));
  PaintSurround(R);
  Saved := SaveDC(Canvas.Handle);
  try
    SetStretchBltMode(Canvas.Handle, COLORONCOLOR);
    StretchBlt(Canvas.Handle, R.Left, R.Top, R.Width, R.Height,
      FBitmap.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height, SRCCOPY);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := clSilver;
    Canvas.Rectangle(R.Left-1, R.Top-1, R.Right+1, R.Bottom+1);
    Canvas.Brush.Style := bsSolid;
  finally
    RestoreDC(Canvas.Handle, Saved);
  end;
end;

procedure TSyncCanvasView.Fit;
var Scale: Double;
begin
  if FBitmap.Empty then Exit;
  Scale := EnsureRange(Min(Max(1, ClientWidth-64) / FBitmap.Width,
    Max(1, ClientHeight-64) / FBitmap.Height), 0.01, 32.0);
  SetView(Scale, (ClientWidth-FBitmap.Width*Scale)/2,
    (ClientHeight-FBitmap.Height*Scale)/2);
end;

procedure TSyncCanvasView.ZoomAt(Factor: Double; const ClientPoint: TPoint);
var NewZoom, Ratio: Double;
begin
  NewZoom := EnsureRange(FZoom * Factor, 0.01, 32.0);
  Ratio := NewZoom / FZoom;
  SetView(NewZoom, ClientPoint.X-(ClientPoint.X-FPanX)*Ratio,
    ClientPoint.Y-(ClientPoint.Y-FPanY)*Ratio);
end;

procedure TSyncCanvasView.PanBy(DX, DY: Integer);
begin
  SetView(FZoom, FPanX+DX, FPanY+DY);
end;

function TSyncCanvasView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  ZoomAt(Power(1.1, WheelDelta/120), ScreenToClient(MousePos));
  Result := True;
end;

procedure TSyncCanvasView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button in [mbLeft, mbMiddle] then
  begin
    SetFocus;
    FDragging := True;
    FLastMouse := Point(X, Y);
    MouseCapture := True;
  end;
end;

procedure TSyncCanvasView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDragging and MouseCapture then
  begin
    PanBy(X-FLastMouse.X, Y-FLastMouse.Y);
    FLastMouse := Point(X, Y);
  end;
end;

procedure TSyncCanvasView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button in [mbLeft, mbMiddle] then
  begin
    FDragging := False;
    MouseCapture := False;
  end;
end;

end.
