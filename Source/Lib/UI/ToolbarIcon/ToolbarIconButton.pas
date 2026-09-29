// Common toolbar interaction and chrome; icon artwork belongs to the caller.
unit ToolbarIconButton;
interface
uses System.Classes, System.Types, Vcl.Controls, Vcl.Graphics, Winapi.Messages;
type
  TToolbarIconState = record
    Enabled, Hot, Pressed, Selected, Focused: Boolean;
    PPI: Integer;
    Foreground: TColor;
  end;
  TDrawToolbarIconEvent = procedure(Sender: TObject; ACanvas: TCanvas;
    const Bounds: TRect; const State: TToolbarIconState) of object;
  TToolbarIconButton = class(TCustomControl)
  private
    FHot, FArmed, FKeyArmed, FSelected, FAutoToggle: Boolean;
    FOnDrawIcon: TDrawToolbarIconEvent;
    procedure SetSelected(Value: Boolean);
    procedure SetDrawIcon(Value: TDrawToolbarIconEvent);
    procedure CancelPress;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure WMCancelMode(var Message: TMessage); message WM_CANCELMODE;
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
    procedure WMGetDlgCode(var Message: TMessage); message WM_GETDLGCODE;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
  protected
    procedure Paint; override;
    // Override without inherited to replace the event-based painter.
    procedure DrawIcon(ACanvas: TCanvas; const Bounds: TRect;
      const State: TToolbarIconState); virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
  published
    property Align;
    property AlignWithMargins;
    property Anchors;
    property Constraints;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Selected: Boolean read FSelected write SetSelected default False;
    property AutoToggle: Boolean read FAutoToggle write FAutoToggle default False;
    property OnDrawIcon: TDrawToolbarIconEvent read FOnDrawIcon write SetDrawIcon;
    property OnClick;
  end;
implementation
uses Winapi.Windows, System.Math;
constructor TToolbarIconButton.Create(AOwner: TComponent);
begin
  inherited;
  // 捕捉は本クラスが管理する。VCLの自動解放がMouseUpより先に押下状態を消すのを防ぐ。
  ControlStyle := (ControlStyle+[csOpaque])-[csClickEvents,csDoubleClicks,csCaptureMouse];
  DoubleBuffered := True; TabStop := True; ShowHint := True;
  SetBounds(0,0,36,36);
end;
procedure TToolbarIconButton.SetSelected(Value: Boolean);
begin
  if FSelected=Value then Exit;
  FSelected := Value; Invalidate;
end;
procedure TToolbarIconButton.SetDrawIcon(Value: TDrawToolbarIconEvent);
begin
  FOnDrawIcon := Value; Invalidate;
end;
procedure TToolbarIconButton.Click;
begin
  if not Enabled then Exit;
  if FAutoToggle then Selected := not Selected;
  inherited;
end;
procedure TToolbarIconButton.CancelPress;
begin
  FArmed := False; FKeyArmed := False;
  if MouseCapture then MouseCapture := False;
  Invalidate;
end;
procedure TToolbarIconButton.CMMouseEnter(var Message: TMessage);
begin inherited; FHot := True; Invalidate; end;
procedure TToolbarIconButton.CMMouseLeave(var Message: TMessage);
begin inherited; FHot := False; Invalidate; end;
procedure TToolbarIconButton.CMEnabledChanged(var Message: TMessage);
begin inherited; if not Enabled then CancelPress; Invalidate; end;
procedure TToolbarIconButton.WMCancelMode(var Message: TMessage);
begin CancelPress; inherited; end;
procedure TToolbarIconButton.WMCaptureChanged(var Message: TMessage);
begin inherited; FArmed := False; Invalidate; end;
procedure TToolbarIconButton.WMGetDlgCode(var Message: TMessage);
begin
  inherited;
  if Message.WParam in [VK_SPACE,VK_RETURN,VK_ESCAPE] then
    Message.Result := Message.Result or DLGC_WANTMESSAGE;
end;
procedure TToolbarIconButton.WMSetFocus(var Message: TWMSetFocus);
begin inherited; Invalidate; end;
procedure TToolbarIconButton.WMKillFocus(var Message: TWMKillFocus);
begin inherited; CancelPress; end;
procedure TToolbarIconButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin
  inherited;
  if (Button<>mbLeft) or not Enabled then Exit;
  if CanFocus then SetFocus;
  FHot := PtInRect(ClientRect,Point(X,Y)); FArmed := True;
  MouseCapture := True; Invalidate;
end;
procedure TToolbarIconButton.MouseMove(Shift: TShiftState; X,Y: Integer);
begin
  inherited;
  FHot := PtInRect(ClientRect,Point(X,Y)); Invalidate;
end;
procedure TToolbarIconButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var Invoke: Boolean;
begin
  inherited;
  if Button<>mbLeft then Exit;
  Invoke := FArmed and MouseCapture and Enabled and PtInRect(ClientRect,Point(X,Y));
  CancelPress;
  if Invoke then Click;
end;
procedure TToolbarIconButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Key=VK_ESCAPE then begin CancelPress; Key := 0; Exit; end;
  if Enabled and (Key in [VK_SPACE,VK_RETURN]) and (Shift=[]) then
  begin FKeyArmed := True; Key := 0; Invalidate; end;
end;
procedure TToolbarIconButton.KeyUp(var Key: Word; Shift: TShiftState);
var Invoke: Boolean;
begin
  inherited;
  if not (Key in [VK_SPACE,VK_RETURN]) then Exit;
  Invoke := FKeyArmed and Enabled and Focused;
  FKeyArmed := False; Key := 0; Invalidate;
  if Invoke then Click;
end;
procedure TToolbarIconButton.DrawIcon(ACanvas: TCanvas; const Bounds: TRect;
  const State: TToolbarIconState);
begin
  if Assigned(FOnDrawIcon) then FOnDrawIcon(Self,ACanvas,Bounds,State);
end;
procedure TToolbarIconButton.Paint;
var State: TToolbarIconState; R: TRect; Padding, Saved: Integer;
  PenCopy: TPen; BrushCopy: TBrush; FontCopy: TFont;
begin
  State.Enabled := Enabled; State.Hot := FHot and Enabled;
  State.Pressed := Enabled and ((FArmed and FHot) or FKeyArmed);
  State.Selected := FSelected; State.Focused := Focused; State.PPI := CurrentPPI;
  State.Foreground := $00EEEEEE;
  Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := $00383838;
  if FSelected then Canvas.Brush.Color := $00613D12;
  if State.Hot then Canvas.Brush.Color := $00484848;
  if State.Pressed then Canvas.Brush.Color := $00202020;
  if not Enabled then begin Canvas.Brush.Color := $002E2E2E; State.Foreground := $00757575; end;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Style := psSolid; Canvas.Pen.Width := 1; Canvas.Pen.Color := $00606060;
  if FSelected or Focused then Canvas.Pen.Color := $00D69C4A;
  Canvas.Brush.Style := bsClear; Canvas.Rectangle(ClientRect);
  Padding := MulDiv(7,CurrentPPI,96);
  R := ClientRect; InflateRect(R,-Padding,-Padding);
  if (R.Width<=0) or (R.Height<=0) then Exit;
  // Restore both GDI and VCL cached drawing properties after application artwork.
  PenCopy := TPen.Create; BrushCopy := TBrush.Create; FontCopy := TFont.Create;
  try
    PenCopy.Assign(Canvas.Pen); BrushCopy.Assign(Canvas.Brush); FontCopy.Assign(Canvas.Font);
    Saved := SaveDC(Canvas.Handle);
    try
      IntersectClipRect(Canvas.Handle,R.Left,R.Top,R.Right,R.Bottom);
      Canvas.Pen.Color := State.Foreground; Canvas.Font.Color := State.Foreground;
      DrawIcon(Canvas,R,State);
    finally
      RestoreDC(Canvas.Handle,Saved);
      Canvas.Pen.Assign(PenCopy); Canvas.Brush.Assign(BrushCopy); Canvas.Font.Assign(FontCopy);
    end;
  finally PenCopy.Free; BrushCopy.Free; FontCopy.Free; end;
  if Focused then begin R := ClientRect; InflateRect(R,-3,-3); Canvas.DrawFocusRect(R); end;
end;
end.
