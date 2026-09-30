unit GraphView;

// グラフ・文字・凡例の選択と入力を接続する。変形計算とガイド描画は専用ユニットへ委譲する。
interface
uses System.Classes, System.Types, System.SysUtils, Vcl.Controls, Vcl.Graphics,
  SyncCanvasView, GraphModel, GraphPainter, GraphTextSnap;
type
  TGraphView=class(TSyncCanvasView)
  private
    // Docはフォーム所有。Labelsと画像キャッシュはViewが保持する描画時点のコピー。
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
    FInitialLabelBounds:TRectF;
    FInitialLabelOffset:TPointF;
    FInitialLabelScale:Single;
    // 相対位置は文字サイズ単位。ドラッグ開始値から計算し、再描画・スナップで累積誤差を出さない。
    FInitialLegendOffset:TPointF;
    FInitialLegendBounds:TRectF;
    FLegendSelected:Boolean;
    FSnapFeedback:TTextSnapFeedback;
    function ScenePoint(X,Y:Integer):TPointF;
    function LabelIndex(ID:Integer):Integer;
    function SelectedBounds:TRectF;
    function SelectedLabelRole:TTextRole;
    procedure DrawDecorations(const Bounds:TRectF);
    function HitLegend(X,Y:Integer):Integer;
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
uses System.Math, GraphCanvasFrame, GraphViewBitmapCache,
  GraphViewBounds, GraphTextDecorations, GraphSnapGuides, GraphTextTransform;
const LabelMoveBase=1000; LabelResizeBase=100000; LegendMoveBase=500000; DecorationBase=1000000;

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

procedure TGraphView.CachePreview(const Background,Graph:TBytes; Width,Height:Integer);
begin
  FPreviewActive:=False;
  FBackground:=Copy(Background);
  FImageWidth:=Width; FImageHeight:=Height;
  FTextBitmap.SetSize(0,0);
  if FDoc=nil then Exit;
  FGraphOrigin:=FDoc.Bounds;
  CacheRgbaLayer(FGraphBitmap,FGraphCrop,Graph,Width,Height);
end;

procedure TGraphView.CacheLabelPreview(const Background,Base,TextLayer:TBytes;
  Width,Height:Integer);
var I:Integer;
begin
  CachePreview(Background,Base,Width,Height);
  I:=LabelIndex(FActiveLabelID);
  if I<0 then Exit;
  FTextOrigin:=FLabels[I].Bounds;
  CacheRgbaLayer(FTextBitmap,FTextCrop,TextLayer,Width,Height);
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
begin
  inherited;
  if (FDoc=nil) or (FDoc.Kind=gkNone) then Exit;
  if FPreviewActive then
  begin
    B:=FDoc.Bounds;
    if FActiveLabelID>=0 then B:=FGraphOrigin;
    DrawRgbaLayer(Canvas,FGraphBitmap,FGraphCrop,FGraphOrigin,B,PanX,PanY,Zoom);
    I:=LabelIndex(FActiveLabelID);
    if I>=0 then DrawRgbaLayer(Canvas,FTextBitmap,FTextCrop,FTextOrigin,
      FLabels[I].Bounds,PanX,PanY,Zoom);
  end;
  if FActiveLabelID>=0 then
    DrawSnapGuides(Canvas,FLabels,FSnapFeedback,PanX,PanY,Zoom,ClientWidth,ClientHeight);
  I:=LabelIndex(FSelectedLabelID);
  if FLegendSelected and (I>=0) and FLabels[I].HasLegend then
  begin
    B:=FLabels[I].LegendBounds; Canvas.Brush.Style:=bsClear;
    Canvas.Pen.Color:=$00E9B456; Canvas.Pen.Style:=psSolid;
    Canvas.Rectangle(Round(PanX+B.Left*Zoom)-3,Round(PanY+B.Top*Zoom)-3,
      Round(PanX+B.Right*Zoom)+3,Round(PanY+B.Bottom*Zoom)+3);
  end else
  begin
    DrawBoundsHandles(Canvas,SelectedBounds,PanX,PanY,Zoom);
    if I>=0 then DrawDecorations(SelectedBounds);
  end;
end;

function TGraphView.HitLegend(X,Y:Integer):Integer;
var I:Integer; P:TPointF;
begin
  Result:=-1; P:=ScenePoint(X,Y);
  for I:=High(FLabels) downto 0 do
    if FLabels[I].HasLegend and FLabels[I].LegendBounds.Contains(P) then Exit(I);
end;
function TGraphView.HitDecoration(X,Y:Integer):Integer;
var I:Integer;
begin
  Result:=-1;
  I:=LabelIndex(FSelectedLabelID);
  if I<0 then Exit;
  Result:=HitTextDecoration(X,Y,FLabels[I].Bounds,
    CurrentPPI,ClientWidth,ClientHeight,PanX,PanY,Zoom);
end;

procedure TGraphView.DrawDecorations(const Bounds:TRectF);
var I:Integer;
begin
  I:=LabelIndex(FSelectedLabelID);
  if I<0 then Exit;
  DrawTextDecorations(Canvas,Bounds,FDoc.TextStyles[FLabels[I].Role],
    CurrentPPI,ClientWidth,ClientHeight,PanX,PanY,Zoom);
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

procedure TGraphView.UpdateCursor(X,Y:Integer);
var H,I:Integer; P:TPointF;
begin
  if HitLegend(X,Y)>=0 then begin Cursor:=crSizeAll; Exit; end;
  H:=HitDecoration(X,Y);
  if H>=0 then
  begin
    if H=1 then Cursor:=crSizeAll else Cursor:=crSizeWE;
    Exit;
  end;
  H:=-3;
  I:=LabelIndex(FSelectedLabelID);
  if I>=0 then H:=HitBoundsHandle(FLabels[I].Bounds,X,Y,PanX,PanY,Zoom);
  P:=ScenePoint(X,Y);
  if H=-3 then
  begin
    for I:=High(FLabels) downto 0 do
      if FLabels[I].Bounds.Contains(P) then
      begin Cursor:=crSizeAll; Exit; end;
    H:=HitBoundsHandle(FDoc.Bounds,X,Y,PanX,PanY,Zoom);
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
  FSnapFeedback:=Default(TTextSnapFeedback); FSnapFeedback.SizeID:=-1;
  SetFocus; FLast:=P; FDragStart:=P; MouseCapture:=True;
  FActiveLabelID:=-1;
  if FTarget>=DecorationBase then
  begin
    I:=LabelIndex(FSelectedLabelID);
    if I>=0 then FInitialTextStyle:=FDoc.TextStyles[FLabels[I].Role];
    Exit;
  end;
  if FTarget>=LegendMoveBase then
  begin
    FActiveLabelID:=FTarget-LegendMoveBase;
    FInitialLegendOffset:=FDoc.LegendOffsets[FActiveLabelID-2];
    I:=LabelIndex(FActiveLabelID); FInitialLegendBounds:=FLabels[I].LegendBounds;
    FPreviewActive:=False; Exit;
  end;
  if FTarget>=LabelResizeBase then FActiveLabelID:=(FTarget-LabelResizeBase) div 8
  else if FTarget>=LabelMoveBase then FActiveLabelID:=FTarget-LabelMoveBase;
  I:=LabelIndex(FActiveLabelID);
  if I>=0 then
  begin
    FInitialLabelBounds:=FLabels[I].Bounds;
    FInitialLabelOffset:=FDoc.Offsets[FActiveLabelID];
    FInitialLabelScale:=FDoc.LabelScales[FActiveLabelID];
  end;
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
    PreviousSelection:=FSelectedLabelID; FLegendSelected:=False;
    P:=ScenePoint(X,Y);
    I:=HitLegend(X,Y);
    if I>=0 then
    begin FSelectedLabelID:=FLabels[I].ID; FLegendSelected:=True;
      FTarget:=LegendMoveBase+FSelectedLabelID; end;
    if FTarget=-3 then
    begin H:=HitDecoration(X,Y); if H>=0 then FTarget:=DecorationBase+H; end;
    I:=LabelIndex(FSelectedLabelID);
    if (FTarget=-3) and (I>=0) then
    begin
      H:=HitBoundsHandle(FLabels[I].Bounds,X,Y,PanX,PanY,Zoom);
      if H>=0 then FTarget:=LabelResizeBase+FSelectedLabelID*8+H;
    end;
    if FTarget=-3 then
      for I:=High(FLabels) downto 0 do
        if FLabels[I].Bounds.Contains(P) then
        begin FSelectedLabelID:=FLabels[I].ID; FTarget:=LabelMoveBase+FSelectedLabelID; Break; end;
    if FTarget=-3 then
    begin
      FSelectedLabelID:=-1;
      FTarget:=HitBoundsHandle(FDoc.Bounds,X,Y,PanX,PanY,Zoom);
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
var P,D:TPointF; I,H:Integer; NewB:TRectF; Factor:Single;
    Role:TTextRole;
begin
  if (FTarget=-3) or not MouseCapture then
  begin
    inherited;
    if not (ssCtrl in Shift) then UpdateCursor(X,Y) else Cursor:=crDefault;
    Exit;
  end;
  P:=ScenePoint(X,Y); D:=P-FLast; FLast:=P;
  if (FTarget>=LegendMoveBase) and (FTarget<DecorationBase) then
  begin
    I:=FTarget-LegendMoveBase; D:=P-FDragStart;
    Factor:=FDoc.TextStyles[trName].Size*FDoc.LabelScales[I];
    NewB:=FInitialLegendBounds; NewB.Offset(D.X,D.Y);
    NewB:=SnapLegendBounds(NewB,I,FLabels,10,@FSnapFeedback);
    D:=PointF(NewB.Left-FInitialLegendBounds.Left,NewB.Top-FInitialLegendBounds.Top);
    FDoc.LegendOffsets[I-2]:=FInitialLegendOffset+PointF(D.X/Factor,D.Y/Factor);
    H:=LabelIndex(I); if H>=0 then FLabels[H].LegendBounds:=NewB;
    if Assigned(FOnDecorationChanged) then FOnDecorationChanged(Self);
    Invalidate; Exit;
  end;
  if FTarget>=DecorationBase then
  begin
    I:=LabelIndex(FSelectedLabelID);
    if I<0 then Exit;
    Role:=FLabels[I].Role;
    D:=P-FDragStart;
    FDoc.TextStyles[Role]:=DragTextDecoration(FInitialTextStyle,
      FTarget-DecorationBase,D);
    Invalidate;
    if Assigned(FOnDecorationChanged) then FOnDecorationChanged(Self);
    Exit;
  end;
  if FTarget=-1 then FDoc.Bounds.Offset(D.X,D.Y)
  else if FTarget in [0..7] then ResizeBoundsHandle(FDoc.Bounds,FTarget,D,40)
  else
  begin
    if FTarget>=LabelResizeBase then
    begin I:=(FTarget-LabelResizeBase) div 8; H:=(FTarget-LabelResizeBase) mod 8; end
    else begin I:=FTarget-LabelMoveBase; H:=-1; end;
    if (I>=0) and (I<Length(FDoc.Offsets)) then
    begin
      if H<0 then
      begin
        D:=P-FDragStart; NewB:=FInitialLabelBounds; NewB.Offset(D.X,D.Y);
        NewB:=SnapTextBounds(NewB,I,FLabels,10,@FSnapFeedback);
        FDoc.Offsets[I]:=FInitialLabelOffset+PointF(
          NewB.Left-FInitialLabelBounds.Left,NewB.Top-FInitialLabelBounds.Top);
        H:=LabelIndex(I);
        if H>=0 then FLabels[H].Bounds:=NewB;
      end
      else
      begin
        H:=LabelIndex(I);
        if H>=0 then
        begin
          FLabels[H].Bounds:=ResizeGraphText(FDoc,I,FLabels[H].Role,FLabels,
            FInitialLabelBounds,FInitialLabelOffset,P-FDragStart,FInitialLabelScale,
            (FTarget-LabelResizeBase) mod 8,FSnapFeedback);
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
