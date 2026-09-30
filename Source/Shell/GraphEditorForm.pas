unit GraphEditorForm;

// 編集画面の組み立てと接続だけを担当する。閉じる操作では不正入力を復旧用に保管し、検証済みの内容を採用する。
interface
uses System.Classes, System.SysUtils, System.UITypes, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Graphics, System.Types, GraphModel, GraphView,
  GraphDataPanel, GraphLayoutPanel, GraphStylePanel, GraphColorStylePanel, ToolbarIconButton,
  VectArtDarkPopupMenu, VectArtDarkMenuGroup, GraphTextToolbar,
  ColorPickerPanel, GraphSettingsPane, GraphEditState, GraphEditorPreview;
type
  TGraphEditorForm=class(TForm)
  private
    FDoc:TGraphDocument;
    FState:TGraphEditState;
    FRecoveryPath:string;
    FPreview:TGraphEditorPreview;
    FView:TGraphView;
    FData:TGraphDataPanel;
    FLayout:TGraphLayoutPanel;
    FStyles:TGraphStylePanel;
    FColors:TGraphColorStylePanel;
    FPickerEditsSeries:Boolean;
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
    procedure StyleEditFinished(Sender:TObject);
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
    constructor CreateForPPI(AOwner:TComponent; DesignPPI:Integer);
    destructor Destroy; override;
    procedure Load(const Pixels:TBytes; Width,Height:Integer; const Settings:string; const Shared:TGraphShared);
    property RecoveryPath:string read FRecoveryPath;
    function Settings:string;
    function Shared:TGraphShared;
  end;
implementation
uses Winapi.Windows, Vcl.Controls, System.Math, GraphSettings, DarkEditorTheme, GraphEditorRecovery;

constructor TGraphEditorForm.Create(AOwner:TComponent);
begin CreateForPPI(AOwner,0); end;

constructor TGraphEditorForm.CreateForPPI(AOwner:TComponent; DesignPPI:Integer);
const Hints:array[0..4] of string=('全体表示','編集前に戻す','グラフ枠を再配置',
  '文字の位置補正を初期化','直前の要素名配置を元に戻す');
var Bar:TPanel; B:TToolbarIconButton; I:Integer; L:TLabel;
  function S(Value:Integer):Integer;
  begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  inherited CreateNew(AOwner);
  FState:=TGraphEditState.Create; FPreview:=TGraphEditorPreview.Create; ApplyDarkEditor(Self); FBusy:=True;
  Caption:='SYNC - グラフ'; Position:=poScreenCenter;
  // スタイルと位置の設定で再生成されるハンドルのDPIを先に確定する。
  HandleNeeded;
  if DesignPPI>0 then begin ScaleForPPI(DesignPPI); Scaled:=False; end;
  ClientWidth:=S(1280); ClientHeight:=S(800); Constraints.MinWidth:=S(1100); Constraints.MinHeight:=S(740);
  Font.Name:='Yu Gothic UI'; Font.Height:=-S(13); OnCloseQuery:=Closing;
  OnResize:=FormResized;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=S(56); Bar.BevelOuter:=bvNone;
  for I:=0 to 4 do
  begin
    B:=TToolbarIconButton.Create(Self); B.Parent:=Bar; B.SetBounds(S(8+I*42),S(6),S(36),S(36));
    B.Tag:=I; B.Hint:=Hints[I]; B.OnDrawIcon:=DrawIcon; B.OnClick:=ActionClick;
  end;
  L:=TLabel.Create(Self); L.Parent:=Bar; L.AutoSize:=False; L.SetBounds(S(226),S(8),S(1020),S(40)); L.Anchors:=[akLeft,akTop,akRight]; L.WordWrap:=True;
  L.Caption:='グラフ・文字の枠内で移動 / 周囲8点でサイズ変更 / Ctrl+ドラッグ・中ボタンで画面移動 / ホイールで倍率 / ×で採用';
  FHelp:=L;
  FTextToolbar:=TGraphTextToolbar.Create(Self); FTextToolbar.Parent:=Bar;
  FTextToolbar.SetBounds(S(226),S(6),S(780),S(44)); FTextToolbar.OnChange:=TextStyleChanged;
  FTextToolbar.OnColorTargetChange:=TextColorTargetChanged;
  FError:=TLabel.Create(Self); FError.Parent:=Self; FError.Align:=alBottom;
  FError.AutoSize:=False; FError.Height:=S(28); FError.Font.Color:=$008080FF;
  FSettingsPane:=TGraphSettingsPane.Create(Self); FSettingsPane.Parent:=Self;
  FPicker:=FSettingsPane.Picker;
  FPicker.OnChange:=PickerChanged;
  FLayout:=FSettingsPane.LayoutPanel; FLayout.OnChange:=Changed;
  FLayout.OnNameLayoutChange:=NameLayoutChanged;
  FData:=FSettingsPane.DataPanel; FData.OnChange:=Changed;
  FColors:=FSettingsPane.ColorPanel; FColors.OnChange:=Changed;
  FColors.OnColorTargetChange:=ColorTargetChanged;
  FStyles:=FSettingsPane.StylePanel; FStyles.OnChange:=Changed;
  FStyles.OnColorTargetChange:=ColorTargetChanged;
  FStyles.OnEditFinished:=StyleEditFinished;
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
  FormResized(nil);
  FBusy:=False;
end;

destructor TGraphEditorForm.Destroy;
begin
  if FTimer<>nil then FTimer.Enabled:=False;
  FMenuGroup.Free; FDoc.Free; FState.Free; FPreview.Free; inherited;
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
  else if FPickerEditsSeries then
    FColors.SetSelectedColor($FF000000 or (Cardinal(GetRValue(C)) shl 16) or
      (Cardinal(GetGValue(C)) shl 8) or GetBValue(C))
  else
    FStyles.SetSelectedColor($FF000000 or (Cardinal(GetRValue(C)) shl 16) or
      (Cardinal(GetGValue(C)) shl 8) or GetBValue(C));
end;

procedure TGraphEditorForm.ColorTargetChanged(Sender:TObject);
var C:TAlphaColor;
begin
  FPickerEditsText:=False;
  FPickerEditsSeries:=Sender=FColors;
  if FPickerEditsSeries then C:=FColors.SelectedColor else C:=FStyles.SelectedColor;
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
  FPreview.Initialize(Pixels,Width,Height);
  if (FDoc.Bounds.Width=0) or (FDoc.Bounds.Height=0) then FDoc.ResetBounds(FPreview.Width,FPreview.Height);
  FState.Initialize(FDoc,Shared); FRecoveryPath:='';
  LoadPanels; FData.Load(Shared,FDoc); FSettingsPane.RefreshLayout;
  RenderPreview; FView.Fit;
  FError.Caption:=LoadWarning;
end;

procedure TGraphEditorForm.LoadPanels;
begin
  FBusy:=True;
  try FLayout.Load(FDoc); FStyles.Load(FDoc); FColors.Load(FDoc); SelectionChanged(nil);
  finally FBusy:=False; end;
end;

procedure TGraphEditorForm.Changed(Sender:TObject);
begin
  if FBusy then Exit;
  FViewPending:=False;
  if (Sender=FStyles) and FStyles.WidthChanging then
  begin
    // 連続操作はタイマーでまとめる。既存の待機中入力も同時に確定する。
    FTimer.Interval:=60;
    if not FTimer.Enabled then FTimer.Enabled:=True;
    Exit;
  end;
  FTimer.Interval:=250;
  if (Sender=FStyles) or (Sender=FColors) then UpdatePreview(nil) else FTimer.Enabled:=True;
end;

procedure TGraphEditorForm.StyleEditFinished(Sender:TObject);
begin
  if not FBusy then UpdatePreview(nil);
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
    begin FData.Load(S,FDoc); FStyles.Load(FDoc); FColors.Load(FDoc); FSettingsPane.RefreshLayout; end;
    RenderPreview; FError.Caption:='';
  except on E:Exception do FError.Caption:=E.Message; end;
end;

procedure TGraphEditorForm.RenderPreview;
begin
  FPreview.Draw(FDoc,FData.ReadShared,FView);
  FState.MarkValid(FDoc,FData.ReadShared);
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
begin
  if not FBusy and (FDoc<>nil) then FState.CaptureNameLayout(FDoc);
end;

procedure TGraphEditorForm.BeginLabelEdit(Sender:TObject);
begin
  FPreview.PrepareLabel(FDoc,FData.ReadShared,FView);
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
var Tag:Integer;
begin
  Tag:=TToolbarIconButton(Sender).Tag;
  if Tag=0 then begin FView.Fit; Exit; end;
  if (Tag=4) and not FState.UndoAvailable then Exit;
  FTimer.Enabled:=False;
  FViewPending:=False;
  case Tag of
    1:begin
      FDoc.Free; FDoc:=FState.RestoreInitial;
      FData.ClearCache; FData.Load(FState.InitialShared,FDoc);
    end;
    2:FDoc.ResetBounds(FPreview.Width,FPreview.Height);
    3:FDoc.ResetOffsets;
    4:FState.UndoNameLayout(FDoc);
  end;
  LoadPanels; FSettingsPane.RefreshLayout; RenderPreview; FError.Caption:='';
end;

procedure TGraphEditorForm.Closing(Sender:TObject; var CanClose:Boolean);
var Inputs,Error,StorageError:string; Current:TGraphShared;
begin
  CanClose:=True; StorageError:='';
  // 検証時の構造更新で入力欄が再生成される前に、生入力を確保する。
  try Inputs:=CaptureEditorInputs(FSettingsPane);
  except on E:Exception do begin Inputs:='[]'; StorageError:=E.Message; end; end;
  Current:=FData.ReadShared;
  UpdatePreview(nil); FTimer.Enabled:=False;
  FState.ClosedWithError:=FError.Caption<>'';
  if not FState.ClosedWithError then Exit;
  Error:=FError.Caption;
  try
    FRecoveryPath:=SaveEditorRecovery(Inputs,Error,SaveGraph(FDoc),FState.ValidSettings,Current,FState.ValidShared);
  except on E:Exception do StorageError:=E.Message; end;
  if StorageError<>'' then
    MessageBox(Handle,PChar('復旧用データを完全には保管できませんでした: '+StorageError+#13#10+
      '画面は最後の有効な設定で閉じます。'), 'SYNC - グラフ',MB_OK or MB_ICONWARNING);
end;
function TGraphEditorForm.Settings:string;
begin
  Result:=FState.AcceptedSettings(FDoc);
end;
function TGraphEditorForm.Shared:TGraphShared;
begin
  Result:=FState.AcceptedShared(FData.ReadShared);
end;
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
