unit GraphSettingsPane;

// 設定欄の配置と縦スクロールを所有し、各パネルの値編集は委譲する。
interface

uses System.Classes, System.Types, Vcl.ExtCtrls, Vcl.Controls,
  ColorPickerPanel, VerticalScrollBarControl, GraphLayoutPanel,
  GraphDataPanel, GraphStylePanel, GraphColorStylePanel;

type
  TGraphSettingsPane=class(TPanel)
  private
    FPicker:TColorPickerPanel;
    FViewport,FContent:TPanel;
    FScroll:TVerticalScrollBarControl;
    FLayout:TGraphLayoutPanel;
    FData:TGraphDataPanel;
    FStyles:TGraphStylePanel;
    FColors:TGraphColorStylePanel;
    procedure Scrolled(Sender:TObject);
    procedure ViewportResized(Sender:TObject);
  public
    constructor Create(AOwner:TComponent); override;
    procedure RefreshLayout;
    procedure RouteWheel(Sender:TObject; Shift:TShiftState;
      WheelDelta:Integer; MousePos:TPoint; var Handled:Boolean);
    property Picker:TColorPickerPanel read FPicker;
    property LayoutPanel:TGraphLayoutPanel read FLayout;
    property DataPanel:TGraphDataPanel read FData;
    property ColorPanel:TGraphColorStylePanel read FColors;
    property StylePanel:TGraphStylePanel read FStyles;
  end;

implementation

uses Winapi.Windows, System.Math, GraphNumberEdit, HorizontalTrackBarControl;

function ChildAtScreen(Root:TWinControl; const ScreenPoint:TPoint):TControl;
var I:Integer; P:TPoint; Child:TControl;
begin
  P:=Root.ScreenToClient(ScreenPoint);
  for I:=Root.ControlCount-1 downto 0 do
  begin
    Child:=Root.Controls[I];
    if not Child.Visible or not PtInRect(Child.BoundsRect,P) then Continue;
    if Child is TWinControl then
      Exit(ChildAtScreen(TWinControl(Child),ScreenPoint));
    Exit(Child);
  end;
  Result:=Root;
end;

constructor TGraphSettingsPane.Create(AOwner:TComponent);
  function S(Value:Integer):Integer;
  begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  inherited;
  // 子の数値欄が生成中にWindowsハンドルを使うため、先にフォームへ接続する。
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=S(312); Align:=alRight; BevelOuter:=bvNone;
  FPicker:=TColorPickerPanel.Create(Self); FPicker.Parent:=Self;
  FPicker.Align:=alBottom; FPicker.Height:=S(224);
  FPicker.ValueFormat:=cvHex;
  FViewport:=TPanel.Create(Self); FViewport.Parent:=Self;
  FViewport.Align:=alClient; FViewport.BevelOuter:=bvNone;
  FViewport.OnResize:=ViewportResized;
  FContent:=TPanel.Create(Self); FContent.Parent:=FViewport;
  FContent.BevelOuter:=bvNone; FContent.Color:=$00303030;
  FScroll:=TVerticalScrollBarControl.Create(Self); FScroll.Parent:=FViewport;
  FScroll.Align:=alRight; FScroll.Width:=S(14); FScroll.SmallChange:=S(48);
  FScroll.OnChange:=Scrolled;
  FLayout:=TGraphLayoutPanel.Create(FContent); FLayout.Parent:=FContent;
  FData:=TGraphDataPanel.Create(FContent); FData.Parent:=FContent;
  FColors:=TGraphColorStylePanel.Create(FContent);
  FStyles:=TGraphStylePanel.Create(FContent); FStyles.Parent:=FContent;
  RefreshLayout;
end;

procedure TGraphSettingsPane.ViewportResized(Sender:TObject);
begin RefreshLayout; end;

procedure TGraphSettingsPane.RefreshLayout;
var W,H,ViewHeight,Gap,Step:Integer;
begin
  if (FContent=nil) or (FScroll=nil) or
    (FLayout=nil) or (FData=nil) or (FStyles=nil) or (FColors=nil) then Exit;
  Gap:=MulDiv(8,CurrentPPI,96); Step:=MulDiv(48,CurrentPPI,96);
  W:=Max(1,FViewport.ClientWidth-FScroll.Width);
  H:=FLayout.Height+FData.Height+FColors.Height+FStyles.Height+4*Gap;
  ViewHeight:=Max(1,FViewport.ClientHeight);
  FScroll.SmallChange:=Step;
  FScroll.LargeChange:=Max(Step,ViewHeight-Step);
  FScroll.SetRange(Max(0,H-ViewHeight),ViewHeight);
  FContent.SetBounds(0,-FScroll.Position,W,H);
  FLayout.SetBounds(0,0,W,FLayout.Height);
  FData.SetBounds(0,FLayout.Height+Gap,W,FData.Height);
  FColors.SetBounds(0,FLayout.Height+FData.Height+2*Gap,W,FColors.Height);
  FStyles.SetBounds(0,FColors.Top+FColors.Height+Gap,W,FStyles.Height);
  FPicker.RefreshLayout;
end;

procedure TGraphSettingsPane.Scrolled(Sender:TObject);
begin
  if FContent<>nil then FContent.Top:=-FScroll.Position;
end;

procedure TGraphSettingsPane.RouteWheel(Sender:TObject; Shift:TShiftState;
  WheelDelta:Integer; MousePos:TPoint; var Handled:Boolean);
var P:TPoint; Target:TControl; Slider:THorizontalTrackBarControl;
begin
  P:=ScreenToClient(MousePos);
  if not PtInRect(ClientRect,P) then Exit;
  // フォームが前面でなくても設定欄自身の子階層から対象を判定する。
  Target:=ChildAtScreen(Self,MousePos);
  if Target is TGraphNumberEdit then
    if TGraphNumberEdit(Target).AdjustAt(MousePos,WheelDelta) then
    begin Handled:=True; Exit; end;
  if Target is THorizontalTrackBarControl then
  begin
    Slider:=THorizontalTrackBarControl(Target);
    Slider.Position:=Slider.Position+Sign(WheelDelta)*Slider.SmallChange;
    Handled:=True; Exit;
  end;
  // 数字以外の位置では桁調整を行わず、設定欄をスクロールする。
  FScroll.Position:=FScroll.Position-Sign(WheelDelta)*FScroll.SmallChange;
  Handled:=True;
end;

end.
