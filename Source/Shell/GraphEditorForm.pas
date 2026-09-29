unit GraphEditorForm;

// 編集画面の組み立てと接続だけを担当する。閉じる操作で検証済みの内容を採用する。
interface
uses System.Classes, System.SysUtils, System.UITypes, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Graphics, System.Types, GraphModel, GraphView,
  GraphDataPanel, GraphLayoutPanel, GraphStylePanel, ToolbarIconButton,
  VectArtDarkPopupMenu, VectArtDarkMenuGroup, GraphTextToolbar,
  ColorPickerPanel, GraphSettingsPane;
type
  TGraphEditorForm=class(TForm)
  private
    FDoc:TGraphDocument;
    FInitialData:string;
    FInitialShared:TGraphShared;
    FUndoNameLayout:Integer;
    FUndoNameOffsets:TArray<TPointF>;
    FUndoAvailable:Boolean;
    FBackground:TBytes;
    FWidth,FHeight:Integer;
    FView:TGraphView;
    FData:TGraphDataPanel;
    FLayout:TGraphLayoutPanel;
    FStyles:TGraphStylePanel;
    FTextToolbar:TGraphTextToolbar;
    FPicker:TColorPickerPanel;
    FSettingsPane:TGraphSettingsPane;
    FHelp:TLabel;
    FError:TLabel;
    FTimer:TTimer;
    FBusy:Boolean;
    FViewPending:Boolean;
    FPickerEditsText:Boolean;
    FMenu:TVectArtDarkPopupMenu;
    FMenuGroup:TVectArtDarkMenuGroup;
    procedure Changed(Sender:TObject);
    procedure UpdatePreview(Sender:TObject);
    procedure ViewEdited(Sender:TObject);
    procedure BeginLabelEdit(Sender:TObject);
    procedure DecorationChanged(Sender:TObject);
    procedure SelectionChanged(Sender:TObject);
    procedure TextStyleChanged(Sender:TObject);
    procedure NameLayoutChanged(Sender:TObject);
    procedure PickerChanged(Sender:TObject);
    procedure ColorTargetChanged(Sender:TObject);
    procedure TextColorTargetChanged(Sender:TObject);
    procedure FormResized(Sender:TObject);
    procedure DrawIcon(Sender:TObject; Canvas:TCanvas; const Bounds:TRect; const State:TToolbarIconState);
    procedure ActionClick(Sender:TObject);
    procedure Closing(Sender:TObject; var CanClose:Boolean);
    procedure FormatMenu(Sender:TObject; MousePos:TPoint; var Handled:Boolean);
    procedure FormatPreset(Sender:TObject);
    procedure RenderPreview;
    procedure LoadPanels;
  protected
    procedure ChangeScale(M,D:Integer; isDpiChange:Boolean); override;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Pixels:TBytes; Width,Height:Integer; const Settings:string; const Shared:TGraphShared);
    function Settings:string;
    function Shared:TGraphShared;
  end;
implementation
uses Winapi.Windows, Vcl.Controls, System.Math, GraphSettings, GraphRenderer, GraphPainter,
  GraphAnimation, GraphComposite, DarkEditorTheme;

constructor TGraphEditorForm.Create(AOwner:TComponent);
const Hints:array[0..4] of string=('全体表示','編集前に戻す','グラフ枠を再配置',
  '文字の位置補正を初期化','直前の要素名配置を元に戻す');
var Bar:TPanel; B:TToolbarIconButton;
  I:Integer; L:TLabel;
begin
  inherited CreateNew(AOwner); ApplyDarkEditor(Self); FBusy:=True;
  Caption:='SYNC - グラフ'; Position:=poScreenCenter;
  ClientWidth:=1280; ClientHeight:=800; Constraints.MinWidth:=1100; Constraints.MinHeight:=740;
  Font.Name:='Yu Gothic UI'; Font.Size:=10; OnCloseQuery:=Closing;
  OnResize:=FormResized;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=56; Bar.BevelOuter:=bvNone;
  for I:=0 to 4 do
  begin
    B:=TToolbarIconButton.Create(Self); B.Parent:=Bar; B.SetBounds(8+I*42,6,36,36);
    B.Tag:=I; B.Hint:=Hints[I]; B.OnDrawIcon:=DrawIcon; B.OnClick:=ActionClick;
  end;
  L:=TLabel.Create(Self); L.Parent:=Bar; L.AutoSize:=False; L.SetBounds(226,8,1020,40); L.Anchors:=[akLeft,akTop,akRight]; L.WordWrap:=True;
  L.Caption:='グラフ・文字の枠内で移動 / 周囲8点でサイズ変更 / Ctrl+ドラッグ・中ボタンで画面移動 / ホイールで倍率 / ×で採用';
  FHelp:=L;
  FTextToolbar:=TGraphTextToolbar.Create(Self); FTextToolbar.Parent:=Bar;
  FTextToolbar.SetBounds(226,6,780,44); FTextToolbar.OnChange:=TextStyleChanged;
  FTextToolbar.OnColorTargetChange:=TextColorTargetChanged;
  FError:=TLabel.Create(Self); FError.Parent:=Self; FError.Align:=alBottom;
  FError.AutoSize:=False; FError.Height:=28; FError.Font.Color:=$008080FF;
  FSettingsPane:=TGraphSettingsPane.Create(Self); FSettingsPane.Parent:=Self;
  FPicker:=FSettingsPane.Picker;
  FPicker.OnChange:=PickerChanged;
  FLayout:=FSettingsPane.LayoutPanel; FLayout.OnChange:=Changed;
  FLayout.OnNameLayoutChange:=NameLayoutChanged;
  FData:=FSettingsPane.DataPanel; FData.OnChange:=Changed;
  FStyles:=FSettingsPane.StylePanel; FStyles.OnChange:=Changed;
  FStyles.OnColorTargetChange:=ColorTargetChanged;
  OnMouseWheel:=FSettingsPane.RouteWheel;
  FSettingsPane.RefreshLayout;
  FView:=TGraphView.Create(Self); FView.Parent:=Self; FView.Align:=alClient;
  FView.OnEdited:=ViewEdited; FView.OnBeginLabelEdit:=BeginLabelEdit;
  FView.OnDecorationChanged:=DecorationChanged;
  FView.OnSelectionChanged:=SelectionChanged;
  FTimer:=TTimer.Create(Self); FTimer.Enabled:=False; FTimer.Interval:=250; FTimer.OnTimer:=UpdatePreview;
  FMenu:=TVectArtDarkPopupMenu.CreatePopup(Self,Self,200,192);
  for I:=0 to 5 do
  begin
Bar:=FMenu.AddItem('',I*32,FormatPreset); Bar.Tag:=I;
    case I of
      0:Bar.Caption:='非表示'; 1:Bar.Caption:='0'; 2:Bar.Caption:='0.0';
      3:Bar.Caption:='#,##0'; 4:Bar.Caption:='0.0kg'; 5:Bar.Caption:='約0km';
    end;
  end;
  FMenuGroup:=TVectArtDarkMenuGroup.Create(Self); FMenuGroup.RegisterMenu(FMenu);
  FLayout.ValueFormatEdit.OnContextPopup:=FormatMenu;
  FBusy:=False;
end;

destructor TGraphEditorForm.Destroy;
begin
  if FTimer<>nil then FTimer.Enabled:=False;
  FMenuGroup.Free; FDoc.Free; inherited;
end;

procedure TGraphEditorForm.ChangeScale(M,D:Integer; isDpiChange:Boolean);
begin
  inherited;
  FormResized(nil);
end;

procedure TGraphEditorForm.FormResized(Sender:TObject);
begin
  // フォームの寸法確定後に再配置し、DPI変更中の古いClientRectを使わない。
  Realign;
  if FPicker<>nil then
  begin FPicker.Parent.Realign; FPicker.RefreshLayout; end;
  if FSettingsPane<>nil then FSettingsPane.RefreshLayout;
end;

procedure TGraphEditorForm.PickerChanged(Sender:TObject);
var C:TColor;
begin
  if FBusy then Exit;
  C:=ColorToRGB(FPicker.SelectedColor);
  if FPickerEditsText then
    FTextToolbar.SetSelectedColor($FF000000 or (Cardinal(GetRValue(C)) shl 16) or
      (Cardinal(GetGValue(C)) shl 8) or GetBValue(C))
  else
    FStyles.SetSelectedColor($FF000000 or (Cardinal(GetRValue(C)) shl 16) or
      (Cardinal(GetGValue(C)) shl 8) or GetBValue(C));
end;

procedure TGraphEditorForm.ColorTargetChanged(Sender:TObject);
var C:TAlphaColor;
begin
  FPickerEditsText:=False;
  C:=FStyles.SelectedColor;
  FPicker.SelectedColor:=RGB((C shr 16) and $FF,(C shr 8) and $FF,C and $FF);
end;

procedure TGraphEditorForm.TextColorTargetChanged(Sender:TObject);
var C:TAlphaColor;
begin
  FPickerEditsText:=True;
  C:=FTextToolbar.SelectedColor;
  FPicker.SelectedColor:=RGB((C shr 16) and $FF,(C shr 8) and $FF,C and $FF);
end;

procedure TGraphEditorForm.Load(const Pixels:TBytes; Width,Height:Integer;
  const Settings:string; const Shared:TGraphShared);
var LoadWarning:string;
begin
  LoadWarning:='';
  try FDoc:=LoadGraph(Settings)
  except on E:Exception do
    begin
      // 壊れた設定でも編集画面を開き、ユーザーが修正できるよう初期値へ復旧する。
      FDoc:=TGraphDocument.Create;
      LoadWarning:='設定を初期値で補完しました: '+E.Message;
    end;
  end;
  FInitialShared:=Shared;
  FWidth:=Width; FHeight:=Height;
  if (FWidth<=0) or (FHeight<=0) then begin FWidth:=1920; FHeight:=1080; end;
  if Int64(FWidth)*FHeight>33554432 then raise EArgumentException.Create('編集画像のサイズが大きすぎます。');
  FBackground:=Copy(Pixels);
  if Length(FBackground)<>Int64(FWidth)*FHeight*4 then SetLength(FBackground,NativeInt(FWidth)*FHeight*4);
  if (FDoc.Bounds.Width=0) or (FDoc.Bounds.Height=0) then FDoc.ResetBounds(FWidth,FHeight);
  FInitialData:=SaveGraph(FDoc);
  LoadPanels; FData.Load(Shared,FDoc); FSettingsPane.RefreshLayout;
  RenderPreview; FView.Fit;
  FError.Caption:=LoadWarning;
end;

procedure TGraphEditorForm.LoadPanels;
begin
  FBusy:=True;
  try FLayout.Load(FDoc); FStyles.Load(FDoc); SelectionChanged(nil);
  finally FBusy:=False; end;
end;

procedure TGraphEditorForm.Changed(Sender:TObject);
begin
  if FBusy then Exit;
  FViewPending:=False;
  FTimer.Interval:=250;
  if Sender=FStyles then UpdatePreview(nil) else FTimer.Enabled:=True;
end;

procedure TGraphEditorForm.UpdatePreview(Sender:TObject);
var S:TGraphShared; OldRows,OldCols,OldNameLayout,I:Integer;
  OldKind:TGraphKind; Check:TGraphDocument;
begin
  FTimer.Enabled:=False;
  try
    if FViewPending then
    begin
      FViewPending:=False;
      RenderPreview;
      FBusy:=True;
      try FLayout.Load(FDoc); finally FBusy:=False; end;
      FError.Caption:='';
      Exit;
    end;
    S:=FData.ReadShared; OldRows:=FDoc.Rows; OldCols:=FDoc.Columns;
    OldKind:=FDoc.Kind; OldNameLayout:=FDoc.NameLayout;
    FStyles.Apply; FLayout.Apply(FDoc);
    if FDoc.NameLayout<>OldNameLayout then
      for I:=2 to Min(1+FDoc.Rows,High(FDoc.Offsets)) do
        FDoc.Offsets[I]:=PointF(0,0);
    Check:=LoadGraph(SaveGraph(FDoc)); Check.Free;
    if (OldRows<>FDoc.Rows) or (OldCols<>FDoc.Columns) or (OldKind<>FDoc.Kind) then
    begin FData.Load(S,FDoc); FStyles.Load(FDoc); FSettingsPane.RefreshLayout; end;
    RenderPreview; FError.Caption:='';
  except on E:Exception do FError.Caption:=E.Message; end;
end;

procedure TGraphEditorForm.RenderPreview;
var Output,Image:TBytes; Labels:TArray<TGraphLabel>; Animation:TGraphAnimation;
begin
  Animation:=Default(TGraphAnimation);
  Output:=RenderGraph(FDoc,FData.ReadShared,Animation,FWidth,FHeight,Labels);
  Image:=Copy(FBackground); CompositeRgba(Image,Output);
  FView.SetRgba(Image,FWidth,FHeight);
  FView.Bind(FDoc,Labels);
  FView.CachePreview(FBackground,Output,FWidth,FHeight);
end;

procedure TGraphEditorForm.ViewEdited(Sender:TObject);
begin
  // ドラッグ中はViewのキャッシュ画像を追従させ、終了時だけ正確に再描画する。
  FTimer.Enabled:=False;
  FViewPending:=True;
  UpdatePreview(nil);
  FStyles.RefreshValues;
  if FTextToolbar.Visible then TextColorTargetChanged(nil);
end;

procedure TGraphEditorForm.DecorationChanged(Sender:TObject);
begin
  // 装飾値のドラッグ中は更新頻度を制限して映像を再描画する。
  FViewPending:=True;
  FTimer.Interval:=50;
  if not FTimer.Enabled then FTimer.Enabled:=True;
end;

procedure TGraphEditorForm.SelectionChanged(Sender:TObject);
begin
  if (FView<>nil) and (FView.SelectedLabelID>=0) and (FDoc<>nil) then
  begin
    FTextToolbar.Bind(FDoc,FView.SelectedRole);
    TextColorTargetChanged(nil);
    FHelp.Visible:=False;
  end
  else
  begin
    FTextToolbar.Visible:=False;
    FHelp.Visible:=True;
    if FPickerEditsText then ColorTargetChanged(nil);
  end;
end;

procedure TGraphEditorForm.TextStyleChanged(Sender:TObject);
begin
  if FBusy then Exit;
  FTimer.Enabled:=False;
  FViewPending:=True;
  UpdatePreview(nil);
end;

procedure TGraphEditorForm.NameLayoutChanged(Sender:TObject);
var I:Integer;
begin
  if FBusy or (FDoc=nil) then Exit;
  FUndoNameLayout:=FDoc.NameLayout;
  SetLength(FUndoNameOffsets,FDoc.Rows);
  for I:=0 to High(FUndoNameOffsets) do
    FUndoNameOffsets[I]:=FDoc.Offsets[I+2];
  FUndoAvailable:=True;
end;

procedure TGraphEditorForm.BeginLabelEdit(Sender:TObject);
var Base,TextLayer:TBytes; Labels:TArray<TGraphLabel>; Animation:TGraphAnimation;
begin
  Animation:=Default(TGraphAnimation);
  Base:=RenderGraph(FDoc,FData.ReadShared,Animation,FWidth,FHeight,
    Labels,-1,FView.ActiveLabelID);
  TextLayer:=RenderGraph(FDoc,FData.ReadShared,Animation,FWidth,FHeight,
    Labels,FView.ActiveLabelID);
  FView.CacheLabelPreview(FBackground,Base,TextLayer,FWidth,FHeight);
end;

procedure TGraphEditorForm.DrawIcon(Sender:TObject; Canvas:TCanvas;
  const Bounds:TRect; const State:TToolbarIconState);
var R:TRect;
begin
  Canvas.Pen.Color:=State.Foreground; Canvas.Pen.Width:=2; Canvas.Brush.Style:=bsClear;
  R:=Bounds; InflateRect(R,-3,-3);
  case TToolbarIconButton(Sender).Tag of
    0:begin Canvas.Rectangle(R); Canvas.MoveTo(R.Left+4,R.Top+4); Canvas.LineTo(R.Right-4,R.Bottom-4); end;
    1:begin Canvas.Arc(R.Left,R.Top,R.Right,R.Bottom,R.Right,R.Top,R.Left,R.Top);
      Canvas.MoveTo(R.Left,R.Top+8); Canvas.LineTo(R.Left,R.Top); Canvas.LineTo(R.Left+8,R.Top); end;
    2:begin Canvas.Rectangle(R); Canvas.MoveTo(R.CenterPoint.X,R.Top); Canvas.LineTo(R.CenterPoint.X,R.Bottom);
      Canvas.MoveTo(R.Left,R.CenterPoint.Y); Canvas.LineTo(R.Right,R.CenterPoint.Y); end;
    3:begin Canvas.Font.Color:=State.Foreground; Canvas.Font.Size:=14; Canvas.TextOut(R.Left,R.Top,'T'); end;
    4:begin Canvas.Font.Color:=State.Foreground; Canvas.Font.Size:=15; Canvas.TextOut(R.Left,R.Top,'↶'); end;
  end;
end;

procedure TGraphEditorForm.ActionClick(Sender:TObject);
var Tag,I:Integer;
begin
  Tag:=TToolbarIconButton(Sender).Tag;
  if Tag=0 then begin FView.Fit; Exit; end;
  if (Tag=4) and not FUndoAvailable then Exit;
  FTimer.Enabled:=False;
  FViewPending:=False;
  case Tag of
    1:begin
      FDoc.Free; FDoc:=LoadGraph(FInitialData);
      FData.ClearCache; FData.Load(FInitialShared,FDoc);
      FUndoAvailable:=False;
    end;
    2:FDoc.ResetBounds(FWidth,FHeight);
    3:FDoc.ResetOffsets;
    4:begin
      FDoc.NameLayout:=FUndoNameLayout;
      for I:=0 to Min(High(FUndoNameOffsets),FDoc.Rows-1) do
        FDoc.Offsets[I+2]:=FUndoNameOffsets[I];
      FUndoAvailable:=False;
    end;
  end;
  LoadPanels; FSettingsPane.RefreshLayout; RenderPreview; FError.Caption:='';
end;

procedure TGraphEditorForm.Closing(Sender:TObject; var CanClose:Boolean);
begin UpdatePreview(nil); CanClose:=FError.Caption=''; end;
function TGraphEditorForm.Settings:string;
begin Result:=SaveGraph(FDoc); end;
function TGraphEditorForm.Shared:TGraphShared;
begin Result:=FData.ReadShared; end;
procedure TGraphEditorForm.FormatMenu(Sender:TObject; MousePos:TPoint; var Handled:Boolean);
begin
  Handled:=True;
  FMenu.OpenAtScreenPoint(FLayout.ValueFormatEdit.ClientToScreen(MousePos));
end;
procedure TGraphEditorForm.FormatPreset(Sender:TObject);
begin
  if TPanel(Sender).Tag=0 then FLayout.ValueFormatEdit.Text:=''
  else FLayout.ValueFormatEdit.Text:=TPanel(Sender).Caption;
  FMenu.Close; Changed(nil);
end;
end.
