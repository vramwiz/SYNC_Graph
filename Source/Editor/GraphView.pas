unit GraphView;

// 背景キャンバスLibを継承し、グラフ専用の枠・文字のドラッグ編集だけを担当する。
interface
uses System.Classes, System.Types, System.SysUtils, Vcl.Controls, Vcl.Graphics,
  SyncCanvasView, GraphModel, GraphPainter;
type
  TGraphView=class(TSyncCanvasView)
  private
    FDoc:TGraphDocument;
    FLabels:TArray<TGraphLabel>;
    FTarget:Integer;
    FLast:TPointF;
    FOnEdited:TNotifyEvent;
    FOnBeginLabelEdit:TNotifyEvent;
    FOnDecorationChanged:TNotifyEvent;
    FOnSelectionChanged:TNotifyEvent;
    FSelectedLabelID:Integer;
    FActiveLabelID:Integer;
    FTextBitmap:TBitmap;
    FTextCrop:TRect;
    FTextOrigin:TRectF;
    FBackground:TBytes;
    FGraphBitmap:TBitmap;
    FGraphOrigin:TRectF;
    FGraphCrop:TRect;
    FPreviewActive:Boolean;
    FImageWidth,FImageHeight:Integer;
    FDragStart:TPointF;
    FInitialTextStyle:TTextStyle;
    function ScenePoint(X,Y:Integer):TPointF;
    function HitHandle(const Bounds:TRectF; X,Y:Integer):Integer;
    function LabelIndex(ID:Integer):Integer;
    function SelectedBounds:TRectF;
    function SelectedLabelRole:TTextRole;
    procedure DrawSelection(const Bounds:TRectF);
    procedure DrawDecorations(const Bounds:TRectF);
    function DecorationPoint(Kind:Integer; const Bounds:TRectF):TPoint;
    function HitDecoration(X,Y:Integer):Integer;
    procedure BeginDrag(const P:TPointF);
    procedure UpdateCursor(X,Y:Integer);
  protected
    procedure PaintSurround(const R:TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift:TShiftState; X,Y:Integer); override;
    procedure MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Bind(Doc:TGraphDocument; const Labels:TArray<TGraphLabel>);
    procedure CachePreview(const Background, Graph:TBytes; Width,Height:Integer);
    procedure CacheLabelPreview(const Background,Base,TextLayer:TBytes;
      Width,Height:Integer);
    property ActiveLabelID:Integer read FActiveLabelID;
    property SelectedLabelID:Integer read FSelectedLabelID;
    property SelectedRole:TTextRole read SelectedLabelRole;
    property OnEdited:TNotifyEvent read FOnEdited write FOnEdited;
    property OnBeginLabelEdit:TNotifyEvent read FOnBeginLabelEdit write FOnBeginLabelEdit;
    property OnDecorationChanged:TNotifyEvent read FOnDecorationChanged write FOnDecorationChanged;
    property OnSelectionChanged:TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;
  end;
implementation
uses System.Math, Winapi.Windows, GraphCanvasFrame;
const LabelMoveBase=1000; LabelResizeBase=100000; DecorationBase=1000000;

constructor TGraphView.Create(AOwner:TComponent);
begin
  inherited;
  FTarget:=-3;
  FSelectedLabelID:=-1;
  FActiveLabelID:=-1;
  FGraphBitmap:=Vcl.Graphics.TBitmap.Create;
  FTextBitmap:=Vcl.Graphics.TBitmap.Create;
end;

destructor TGraphView.Destroy;
begin
  FGraphBitmap.Free;
  FTextBitmap.Free;
  inherited;
end;

procedure FillLayer(Bitmap:Vcl.Graphics.TBitmap; out Crop:TRect; const Graph:TBytes;
  Width,Height:Integer);
var X,Y,L,T,R,B,A:Integer; Src,Dest:PByte;
begin
  Bitmap.SetSize(0,0);
  if Length(Graph)<>Int64(Width)*Height*4 then Exit;
  L:=Width; T:=Height; R:=-1; B:=-1;
  for Y:=0 to Height-1 do
    for X:=0 to Width-1 do
      if Graph[(NativeInt(Y)*Width+X)*4+3]<>0 then
      begin
        L:=Min(L,X); T:=Min(T,Y); R:=Max(R,X); B:=Max(B,Y);
      end;
  if R<L then Exit;
  Crop:=Rect(L,T,R+1,B+1);
  Bitmap.PixelFormat:=pf32bit;
  Bitmap.SetSize(Crop.Width,Crop.Height);
  for Y:=0 to Crop.Height-1 do
  begin
    Src:=@Graph[(NativeInt(Y+T)*Width+L)*4];
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

procedure TGraphView.CachePreview(const Background,Graph:TBytes; Width,Height:Integer);
begin
  FPreviewActive:=False;
  FBackground:=Copy(Background);
  FImageWidth:=Width; FImageHeight:=Height;
  FTextBitmap.SetSize(0,0);
  if FDoc=nil then Exit;
  FGraphOrigin:=FDoc.Bounds;
  FillLayer(FGraphBitmap,FGraphCrop,Graph,Width,Height);
end;

procedure TGraphView.CacheLabelPreview(const Background,Base,TextLayer:TBytes;
  Width,Height:Integer);
var I:Integer;
begin
  CachePreview(Background,Base,Width,Height);
  I:=LabelIndex(FActiveLabelID);
  if I<0 then Exit;
  FTextOrigin:=FLabels[I].Bounds;
  FillLayer(FTextBitmap,FTextCrop,TextLayer,Width,Height);
end;

procedure TGraphView.Bind(Doc:TGraphDocument; const Labels:TArray<TGraphLabel>);
begin
  FDoc:=Doc; FLabels:=Labels;
  if (FSelectedLabelID>=0) and (LabelIndex(FSelectedLabelID)<0) then
  begin
    FSelectedLabelID:=-1;
    if Assigned(FOnSelectionChanged) then FOnSelectionChanged(Self);
  end;
  Invalidate;
end;

function TGraphView.ScenePoint(X,Y:Integer):TPointF;
begin Result:=PointF((X-PanX)/Zoom,(Y-PanY)/Zoom); end;

procedure TGraphView.PaintSurround(const R:TRect);
begin DrawCanvasFrame(Canvas,R); end;

procedure TGraphView.Paint;
var B:TRectF; I:Integer;
  procedure DrawLayer(Bitmap:Vcl.Graphics.TBitmap; const Crop:TRect;
    const Origin,Current:TRectF);
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
begin
  inherited;
  if (FDoc=nil) or (FDoc.Kind=gkNone) then Exit;
  if FPreviewActive then
  begin
    B:=FDoc.Bounds;
    if FActiveLabelID>=0 then B:=FGraphOrigin;
    DrawLayer(FGraphBitmap,FGraphCrop,FGraphOrigin,B);
    I:=LabelIndex(FActiveLabelID);
    if I>=0 then DrawLayer(FTextBitmap,FTextCrop,FTextOrigin,FLabels[I].Bounds);
  end;
  DrawSelection(SelectedBounds);
  if LabelIndex(FSelectedLabelID)>=0 then DrawDecorations(SelectedBounds);
end;

procedure TGraphView.DrawSelection(const Bounds:TRectF);
var R:TRect; I,HX,HY:Integer;
begin
  R:=Rect(Round(PanX+Bounds.Left*Zoom),Round(PanY+Bounds.Top*Zoom),
    Round(PanX+Bounds.Right*Zoom),Round(PanY+Bounds.Bottom*Zoom));
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=$00E9B456; Canvas.Pen.Style:=psDot;
  Canvas.Rectangle(R); Canvas.Pen.Style:=psSolid;
  Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=$00E9B456;
  for I:=0 to 7 do
  begin
    case I of
      0,3,5:HX:=R.Left;
      1,6:HX:=(R.Left+R.Right) div 2;
    else HX:=R.Right; end;
    case I of
      0,1,2:HY:=R.Top;
      3,4:HY:=(R.Top+R.Bottom) div 2;
    else HY:=R.Bottom; end;
    Canvas.Rectangle(HX-5,HY-5,HX+6,HY+6);
  end;
end;

function TGraphView.DecorationPoint(Kind:Integer; const Bounds:TRectF):TPoint;
var Step,Margin,StartX,Y:Integer;
begin
  Step:=MulDiv(34,CurrentPPI,96);
  Margin:=MulDiv(20,CurrentPPI,96);
  StartX:=EnsureRange(Round(PanX+Bounds.Left*Zoom)+Margin,
    Margin,Max(Margin,ClientWidth-Margin-3*Step));
  Y:=EnsureRange(Round(PanY+Bounds.Bottom*Zoom)+MulDiv(28,CurrentPPI,96),
    Margin,Max(Margin,ClientHeight-Margin));
  Result:=Point(StartX+Kind*Step,Y);
end;

function TGraphView.HitDecoration(X,Y:Integer):Integer;
var I,K,Radius:Integer; P:TPoint; B:TRectF;
begin
  Result:=-1;
  I:=LabelIndex(FSelectedLabelID);
  if I<0 then Exit;
  B:=FLabels[I].Bounds;
  Radius:=MulDiv(13,CurrentPPI,96);
  for K:=0 to 3 do
  begin
    P:=DecorationPoint(K,B);
    if (Abs(X-P.X)<=Radius) and (Abs(Y-P.Y)<=Radius) then Exit(K);
  end;
end;

procedure TGraphView.DrawDecorations(const Bounds:TRectF);
const Captions:array[0..3] of string=('縁','影','縁ぼ','影ぼ');
var K,I,Radius:Integer; P:TPoint; S:TTextStyle; Active:Boolean; Value:string;
begin
  I:=LabelIndex(FSelectedLabelID);
  if I<0 then Exit;
  S:=FDoc.TextStyles[FLabels[I].Role];
  Radius:=MulDiv(12,CurrentPPI,96);
  Canvas.Font.Name:='Yu Gothic UI'; Canvas.Font.Size:=8;
  Canvas.Pen.Color:=$00E9B456;
  for K:=0 to 3 do
  begin
    P:=DecorationPoint(K,Bounds);
    case K of
      0:begin Active:=S.OutlineWidth>0; Value:=IntToStr(Round(S.OutlineWidth)); end;
      1:begin Active:=(S.ShadowX<>0) or (S.ShadowY<>0); Value:=Format('%d,%d',[Round(S.ShadowX),Round(S.ShadowY)]); end;
      2:begin Active:=S.OutlineBlur>0; Value:=IntToStr(Round(S.OutlineBlur)); end;
    else Active:=S.ShadowBlur>0; Value:=IntToStr(Round(S.ShadowBlur)); end;
    if Active then Canvas.Brush.Color:=$004A3B24 else Canvas.Brush.Color:=$00303030;
    Canvas.Ellipse(P.X-Radius,P.Y-Radius,P.X+Radius+1,P.Y+Radius+1);
    Canvas.Brush.Style:=bsClear; Canvas.Font.Color:=$00E9B456;
    Canvas.TextOut(P.X-Canvas.TextWidth(Captions[K]) div 2,
      P.Y-Canvas.TextHeight(Captions[K]) div 2,Captions[K]);
    Canvas.Font.Color:=$00EEEEEE;
    Canvas.TextOut(P.X-Canvas.TextWidth(Value) div 2,P.Y+Radius+2,Value);
    Canvas.Brush.Style:=bsSolid;
  end;
end;

function TGraphView.LabelIndex(ID:Integer):Integer;
var I:Integer;
begin
  Result:=-1;
  for I:=0 to High(FLabels) do
    if FLabels[I].ID=ID then Exit(I);
end;

function TGraphView.SelectedBounds:TRectF;
var I:Integer;
begin
  I:=LabelIndex(FSelectedLabelID);
  if I>=0 then Result:=FLabels[I].Bounds else Result:=FDoc.Bounds;
end;

function TGraphView.SelectedLabelRole:TTextRole;
var I:Integer;
begin
  I:=LabelIndex(FSelectedLabelID);
  if I>=0 then Result:=FLabels[I].Role else Result:=trTitle;
end;

function TGraphView.HitHandle(const Bounds:TRectF; X,Y:Integer):Integer;
var B:TRectF; L,T,R,D,CX,CY:Integer;
begin
  Result:=-3;
  if (FDoc=nil) or (FDoc.Kind=gkNone) then Exit;
  B:=Bounds;
  L:=Round(PanX+B.Left*Zoom); T:=Round(PanY+B.Top*Zoom);
  R:=Round(PanX+B.Right*Zoom); D:=Round(PanY+B.Bottom*Zoom);
  CX:=(L+R) div 2; CY:=(T+D) div 2;
  if (Abs(X-L)<=7) and (Abs(Y-T)<=7) then Result:=0
  else if (Abs(X-CX)<=7) and (Abs(Y-T)<=7) then Result:=1
  else if (Abs(X-R)<=7) and (Abs(Y-T)<=7) then Result:=2
  else if (Abs(X-L)<=7) and (Abs(Y-CY)<=7) then Result:=3
  else if (Abs(X-R)<=7) and (Abs(Y-CY)<=7) then Result:=4
  else if (Abs(X-L)<=7) and (Abs(Y-D)<=7) then Result:=5
  else if (Abs(X-CX)<=7) and (Abs(Y-D)<=7) then Result:=6
  else if (Abs(X-R)<=7) and (Abs(Y-D)<=7) then Result:=7;
end;

procedure TGraphView.UpdateCursor(X,Y:Integer);
var H,I:Integer; P:TPointF;
begin
  H:=HitDecoration(X,Y);
  if H>=0 then
  begin
    if H=1 then Cursor:=crSizeAll else Cursor:=crSizeWE;
    Exit;
  end;
  H:=-3;
  I:=LabelIndex(FSelectedLabelID);
  if I>=0 then H:=HitHandle(FLabels[I].Bounds,X,Y);
  P:=ScenePoint(X,Y);
  if H=-3 then
  begin
    for I:=High(FLabels) downto 0 do
      if FLabels[I].Bounds.Contains(P) then
      begin Cursor:=crSizeAll; Exit; end;
    H:=HitHandle(FDoc.Bounds,X,Y);
  end;
  case H of
    0,7:Cursor:=crSizeNWSE;
    1,6:Cursor:=crSizeNS;
    2,5:Cursor:=crSizeNESW;
    3,4:Cursor:=crSizeWE;
  else
    begin
      Cursor:=crDefault;
      if (FDoc<>nil) and (FDoc.Kind<>gkNone) then
      begin
        if FDoc.Bounds.Contains(P) then Cursor:=crSizeAll;
      end;
    end;
  end;
end;

procedure TGraphView.BeginDrag(const P:TPointF);
var I:Integer;
begin
  SetFocus; FLast:=P; FDragStart:=P; MouseCapture:=True;
  FActiveLabelID:=-1;
  if FTarget>=DecorationBase then
  begin
    I:=LabelIndex(FSelectedLabelID);
    if I>=0 then FInitialTextStyle:=FDoc.TextStyles[FLabels[I].Role];
    Exit;
  end;
  if FTarget>=LabelResizeBase then FActiveLabelID:=(FTarget-LabelResizeBase) div 8
  else if FTarget>=LabelMoveBase then FActiveLabelID:=FTarget-LabelMoveBase;
  if (FActiveLabelID>=0) and Assigned(FOnBeginLabelEdit) then
    FOnBeginLabelEdit(Self);
  if not FGraphBitmap.Empty then
  begin FPreviewActive:=True; SetRgba(FBackground,FImageWidth,FImageHeight); end;
end;

procedure TGraphView.MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var P:TPointF; I,H,PreviousSelection:Integer;
begin
  FTarget:=-3;
  if (Button=mbLeft) and not(ssCtrl in Shift) and (FDoc<>nil) and (FDoc.Kind<>gkNone) then
  begin
    PreviousSelection:=FSelectedLabelID;
    P:=ScenePoint(X,Y);
    H:=HitDecoration(X,Y);
    if H>=0 then FTarget:=DecorationBase+H;
    I:=LabelIndex(FSelectedLabelID);
    if (FTarget=-3) and (I>=0) then
    begin
      H:=HitHandle(FLabels[I].Bounds,X,Y);
      if H>=0 then FTarget:=LabelResizeBase+FSelectedLabelID*8+H;
    end;
    if FTarget=-3 then
      for I:=High(FLabels) downto 0 do
        if FLabels[I].Bounds.Contains(P) then
        begin FSelectedLabelID:=FLabels[I].ID; FTarget:=LabelMoveBase+FSelectedLabelID; Break; end;
    if FTarget=-3 then
    begin
      FSelectedLabelID:=-1;
      FTarget:=HitHandle(FDoc.Bounds,X,Y);
      if (FTarget=-3) and FDoc.Bounds.Contains(P) then FTarget:=-1;
    end;
    if (PreviousSelection<>FSelectedLabelID) and Assigned(FOnSelectionChanged) then
      FOnSelectionChanged(Self);
    if FTarget<>-3 then
    begin BeginDrag(P); Invalidate; Exit; end;
    Invalidate;
  end;
  inherited;
end;

procedure TGraphView.MouseMove(Shift:TShiftState; X,Y:Integer);
var P,D:TPointF; I,H:Integer; OldB,NewB:TRectF; Factor,WX,HY:Single;
    S:TTextStyle; Role:TTextRole;
  procedure ResizeBounds(var B:TRectF; Handle:Integer; const Delta:TPointF;
    Minimum:Single);
  begin
    if Handle in [0,3,5] then B.Left:=Min(B.Right-Minimum,B.Left+Delta.X);
    if Handle in [2,4,7] then B.Right:=Max(B.Left+Minimum,B.Right+Delta.X);
    if Handle in [0,1,2] then B.Top:=Min(B.Bottom-Minimum,B.Top+Delta.Y);
    if Handle in [5,6,7] then B.Bottom:=Max(B.Top+Minimum,B.Bottom+Delta.Y);
  end;
begin
  if (FTarget=-3) or not MouseCapture then
  begin
    inherited;
    if not (ssCtrl in Shift) then UpdateCursor(X,Y) else Cursor:=crDefault;
    Exit;
  end;
  P:=ScenePoint(X,Y); D:=P-FLast; FLast:=P;
  if FTarget>=DecorationBase then
  begin
    I:=LabelIndex(FSelectedLabelID);
    if I<0 then Exit;
    Role:=FLabels[I].Role;
    S:=FInitialTextStyle;
    D:=P-FDragStart;
    case FTarget-DecorationBase of
      0:begin
          S.OutlineWidth:=EnsureRange(Round(S.OutlineWidth+D.X/4),0,30);
          if S.OutlineWidth=0 then S.OutlineBlur:=0;
        end;
      1:begin
          S.ShadowX:=EnsureRange(Round(S.ShadowX+D.X),-100,100);
          S.ShadowY:=EnsureRange(Round(S.ShadowY+D.Y),-100,100);
          if Abs(S.ShadowX)<=2 then S.ShadowX:=0;
          if Abs(S.ShadowY)<=2 then S.ShadowY:=0;
          if (S.ShadowX=0) and (S.ShadowY=0) then S.ShadowBlur:=0;
        end;
      2:begin
          S.OutlineBlur:=EnsureRange(Round(S.OutlineBlur+D.X/4),0,30);
          if (S.OutlineBlur>0) and (S.OutlineWidth=0) then S.OutlineWidth:=1;
        end;
      3:S.ShadowBlur:=EnsureRange(Round(S.ShadowBlur+D.X/4),0,30);
    end;
    FDoc.TextStyles[Role]:=S;
    Invalidate;
    if Assigned(FOnDecorationChanged) then FOnDecorationChanged(Self);
    Exit;
  end;
  if FTarget=-1 then FDoc.Bounds.Offset(D.X,D.Y)
  else if FTarget in [0..7] then ResizeBounds(FDoc.Bounds,FTarget,D,40)
  else
  begin
    if FTarget>=LabelResizeBase then
    begin I:=(FTarget-LabelResizeBase) div 8; H:=(FTarget-LabelResizeBase) mod 8; end
    else begin I:=FTarget-LabelMoveBase; H:=-1; end;
    if (I>=0) and (I<Length(FDoc.Offsets)) then
    begin
      if H<0 then
      begin
        FDoc.Offsets[I]:=FDoc.Offsets[I]+D;
        H:=LabelIndex(I);
        if H>=0 then FLabels[H].Bounds.Offset(D.X,D.Y);
      end
      else
      begin
        H:=LabelIndex(I);
        if H>=0 then
        begin
          OldB:=FLabels[H].Bounds; NewB:=OldB;
          ResizeBounds(NewB,(FTarget-LabelResizeBase) mod 8,D,10);
          WX:=NewB.Width/OldB.Width; HY:=NewB.Height/OldB.Height;
          if Abs(WX-1)>=Abs(HY-1) then Factor:=WX else Factor:=HY;
          Factor:=EnsureRange(Factor,0.1/FDoc.LabelScales[I],20/FDoc.LabelScales[I]);
          FDoc.LabelScales[I]:=FDoc.LabelScales[I]*Factor;
          FDoc.Offsets[I]:=FDoc.Offsets[I]+PointF(
            NewB.CenterPoint.X-OldB.CenterPoint.X,
            NewB.CenterPoint.Y-OldB.CenterPoint.Y+
              0.3*OldB.Height*(Factor-1));
          FLabels[H].Bounds:=RectF(NewB.CenterPoint.X-OldB.Width*Factor/2,
            NewB.CenterPoint.Y-OldB.Height*Factor/2,
            NewB.CenterPoint.X+OldB.Width*Factor/2,
            NewB.CenterPoint.Y+OldB.Height*Factor/2);
        end;
      end;
    end;
  end;
  Invalidate;
end;

procedure TGraphView.MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var WasEditing:Boolean;
begin
  WasEditing:=FTarget<>-3;
  FTarget:=-3;
  inherited;
  UpdateCursor(X,Y);
  if WasEditing and Assigned(FOnEdited) then FOnEdited(Self);
  FActiveLabelID:=-1;
end;
end.
