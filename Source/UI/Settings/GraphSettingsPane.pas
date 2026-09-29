unit GraphSettingsPane;

// 設定欄の配置と縦スクロールを所有し、各パネルの値編集は委譲する。
interface

uses System.Classes, System.Types, Vcl.ExtCtrls, Vcl.Controls,
  ColorPickerPanel, VerticalScrollBarControl, GraphLayoutPanel,
  GraphDataPanel, GraphStylePanel;

type
  TGraphSettingsPane=class(TPanel)
  private
    FPicker:TColorPickerPanel;
    FViewport,FContent:TPanel;
    FScroll:TVerticalScrollBarControl;
    FLayout:TGraphLayoutPanel;
    FData:TGraphDataPanel;
    FStyles:TGraphStylePanel;
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
    property StylePanel:TGraphStylePanel read FStyles;
  end;

implementation

uses System.Math, GraphNumberEdit, HorizontalTrackBarControl;

constructor TGraphSettingsPane.Create(AOwner:TComponent);
begin
  inherited;
  // 子の数値欄が生成中にWindowsハンドルを使うため、先にフォームへ接続する。
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=312; Align:=alRight; BevelOuter:=bvNone;
  FPicker:=TColorPickerPanel.Create(Self); FPicker.Parent:=Self;
  FPicker.Align:=alBottom; FPicker.Height:=224;
  FPicker.ValueFormat:=cvHex;
  FViewport:=TPanel.Create(Self); FViewport.Parent:=Self;
  FViewport.Align:=alClient; FViewport.BevelOuter:=bvNone;
  FViewport.OnResize:=ViewportResized;
  FContent:=TPanel.Create(Self); FContent.Parent:=FViewport;
  FContent.BevelOuter:=bvNone; FContent.Color:=$00303030;
  FScroll:=TVerticalScrollBarControl.Create(Self); FScroll.Parent:=FViewport;
  FScroll.Align:=alRight; FScroll.Width:=14; FScroll.SmallChange:=48;
  FScroll.OnChange:=Scrolled;
  FLayout:=TGraphLayoutPanel.Create(FContent); FLayout.Parent:=FContent;
  FData:=TGraphDataPanel.Create(FContent); FData.Parent:=FContent;
  FStyles:=TGraphStylePanel.Create(FContent); FStyles.Parent:=FContent;
  RefreshLayout;
end;

procedure TGraphSettingsPane.ViewportResized(Sender:TObject);
begin RefreshLayout; end;

procedure TGraphSettingsPane.RefreshLayout;
var W,H,ViewHeight:Integer;
begin
  if (FContent=nil) or (FScroll=nil) or
    (FLayout=nil) or (FData=nil) or (FStyles=nil) then Exit;
  W:=Max(1,FViewport.ClientWidth-FScroll.Width);
  H:=FLayout.Height+FData.Height+FStyles.Height+24;
  ViewHeight:=Max(1,FViewport.ClientHeight);
  FScroll.LargeChange:=Max(48,ViewHeight-48);
  FScroll.SetRange(Max(0,H-ViewHeight),ViewHeight);
  FContent.SetBounds(0,-FScroll.Position,W,H);
  FLayout.SetBounds(0,0,W,FLayout.Height);
  FData.SetBounds(0,FLayout.Height+8,W,FData.Height);
  FStyles.SetBounds(0,FLayout.Height+FData.Height+16,W,FStyles.Height);
  FPicker.RefreshLayout;
end;

procedure TGraphSettingsPane.Scrolled(Sender:TObject);
begin
  if FContent<>nil then FContent.Top:=-FScroll.Position;
end;

procedure TGraphSettingsPane.RouteWheel(Sender:TObject; Shift:TShiftState;
  WheelDelta:Integer; MousePos:TPoint; var Handled:Boolean);
var P:TPoint; Target:TWinControl; Slider:THorizontalTrackBarControl;
begin
  P:=ScreenToClient(MousePos);
  if not PtInRect(ClientRect,P) then Exit;
  Target:=FindVCLWindow(MousePos);
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
