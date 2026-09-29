unit GraphView;

// 背景キャンバスLibを継承し、グラフ専用の枠・文字のドラッグ編集だけを担当する。
interface
uses System.Classes, System.Types, System.SysUtils, Vcl.Controls,
  SyncCanvasView, GraphModel, GraphPainter;
type
  TGraphView=class(TSyncCanvasView)
  private
    FDoc:TGraphDocument;
    FLabels:TArray<TGraphLabel>;
    FTarget:Integer;
    FLast:TPointF;
    FOnEdited:TNotifyEvent;
    function ScenePoint(X,Y:Integer):TPointF;
  protected
    procedure PaintSurround(const R:TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift:TShiftState; X,Y:Integer); override;
    procedure MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
  public
    constructor Create(AOwner:TComponent); override;
    procedure Bind(Doc:TGraphDocument; const Labels:TArray<TGraphLabel>);
    property OnEdited:TNotifyEvent read FOnEdited write FOnEdited;
  end;
implementation
uses System.Math, Vcl.Graphics, GraphCanvasFrame;

constructor TGraphView.Create(AOwner:TComponent);
begin inherited; FTarget:=-3; end;

procedure TGraphView.Bind(Doc:TGraphDocument; const Labels:TArray<TGraphLabel>);
begin FDoc:=Doc; FLabels:=Labels; Invalidate; end;

function TGraphView.ScenePoint(X,Y:Integer):TPointF;
begin Result:=PointF((X-PanX)/Zoom,(Y-PanY)/Zoom); end;

procedure TGraphView.PaintSurround(const R:TRect);
begin DrawCanvasFrame(Canvas,R); end;

procedure TGraphView.Paint;
var R:TRect; B:TRectF;
begin
  inherited;
  if (FDoc=nil) or (FDoc.Kind=gkNone) then Exit;
  B:=FDoc.Bounds;
  R:=Rect(Round(PanX+B.Left*Zoom),Round(PanY+B.Top*Zoom),
    Round(PanX+B.Right*Zoom),Round(PanY+B.Bottom*Zoom));
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=$00E9B456; Canvas.Pen.Style:=psDot;
  Canvas.Rectangle(R); Canvas.Pen.Style:=psSolid;
  Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=$00E9B456;
  Canvas.Rectangle(R.Right-5,R.Bottom-5,R.Right+5,R.Bottom+5);
end;

procedure TGraphView.MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var P:TPointF; I:Integer;
begin
  FTarget:=-3;
  if (Button=mbLeft) and not(ssCtrl in Shift) and (FDoc<>nil) and (FDoc.Kind<>gkNone) then
  begin
    P:=ScenePoint(X,Y);
    if (Abs(P.X-FDoc.Bounds.Right)*Zoom<9) and (Abs(P.Y-FDoc.Bounds.Bottom)*Zoom<9) then FTarget:=-2
    else
    begin
      for I:=High(FLabels) downto 0 do
        if FLabels[I].Bounds.Contains(P) then begin FTarget:=FLabels[I].ID; Break; end;
      if (FTarget=-3) and FDoc.Bounds.Contains(P) then FTarget:=-1;
    end;
    if FTarget<>-3 then
    begin SetFocus; FLast:=P; MouseCapture:=True; Exit; end;
  end;
  inherited;
end;

procedure TGraphView.MouseMove(Shift:TShiftState; X,Y:Integer);
var P,D:TPointF;
begin
  if (FTarget=-3) or not MouseCapture then begin inherited; Exit; end;
  P:=ScenePoint(X,Y); D:=P-FLast; FLast:=P;
  case FTarget of
    -2: begin
      FDoc.Bounds.Right:=Max(FDoc.Bounds.Left+40,FDoc.Bounds.Right+D.X);
      FDoc.Bounds.Bottom:=Max(FDoc.Bounds.Top+40,FDoc.Bounds.Bottom+D.Y);
    end;
    -1:FDoc.Bounds.Offset(D.X,D.Y);
  else FDoc.Offsets[FTarget]:=FDoc.Offsets[FTarget]+D; end;
  if Assigned(FOnEdited) then FOnEdited(Self);
end;

procedure TGraphView.MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin FTarget:=-3; inherited; end;
end.
