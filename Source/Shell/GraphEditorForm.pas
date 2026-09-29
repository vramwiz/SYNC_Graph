unit GraphEditorForm;

// 編集画面の組み立てと接続だけを担当する。閉じる操作で検証済みの内容を採用する。
interface
uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.Graphics, System.Types, GraphModel, GraphView,
  GraphDataPanel, GraphLayoutPanel, GraphStylePanel, ToolbarIconButton,
  VectArtDarkPopupMenu, VectArtDarkMenuGroup;
type
  TGraphEditorForm=class(TForm)
  private
    FDoc:TGraphDocument;
    FInitialData:string;
    FInitialShared:TGraphShared;
    FBackground:TBytes;
    FWidth,FHeight:Integer;
    FView:TGraphView;
    FData:TGraphDataPanel;
    FLayout:TGraphLayoutPanel;
    FStyles:TGraphStylePanel;
    FError:TLabel;
    FTimer:TTimer;
    FBusy:Boolean;
    FMenu:TVectArtDarkPopupMenu;
    FMenuGroup:TVectArtDarkMenuGroup;
    procedure Changed(Sender:TObject);
    procedure UpdatePreview(Sender:TObject);
    procedure ViewEdited(Sender:TObject);
    procedure DrawIcon(Sender:TObject; Canvas:TCanvas; const Bounds:TRect; const State:TToolbarIconState);
    procedure ActionClick(Sender:TObject);
    procedure Closing(Sender:TObject; var CanClose:Boolean);
    procedure FormatMenu(Sender:TObject; MousePos:TPoint; var Handled:Boolean);
    procedure FormatPreset(Sender:TObject);
    procedure RenderPreview;
    procedure LoadPanels;
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
const Hints:array[0..3] of string=('全体表示','編集前に戻す','グラフ枠を再配置','文字の位置補正を初期化');
var Bar:TPanel; B:TToolbarIconButton; I:Integer; Pages:TPageControl;
  Tab:TTabSheet; L:TLabel;
begin
  inherited CreateNew(AOwner); ApplyDarkEditor(Self); FBusy:=True;
  Caption:='SYNC - グラフ'; Position:=poScreenCenter;
  ClientWidth:=1280; ClientHeight:=800; Constraints.MinWidth:=1100; Constraints.MinHeight:=740;
  Font.Name:='Yu Gothic UI'; Font.Size:=10; OnCloseQuery:=Closing;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=56; Bar.BevelOuter:=bvNone;
  for I:=0 to 3 do
  begin
    B:=TToolbarIconButton.Create(Self); B.Parent:=Bar; B.SetBounds(8+I*42,6,36,36);
    B.Tag:=I; B.Hint:=Hints[I]; B.OnDrawIcon:=DrawIcon; B.OnClick:=ActionClick;
  end;
  L:=TLabel.Create(Self); L.Parent:=Bar; L.AutoSize:=False; L.SetBounds(190,8,1060,40); L.Anchors:=[akLeft,akTop,akRight]; L.WordWrap:=True;
  L.Caption:='枠・文字をドラッグ / 右下でサイズ変更 / Ctrl+ドラッグ・中ボタンで移動 / ホイールで倍率 / ×で採用';
  FError:=TLabel.Create(Self); FError.Parent:=Self; FError.Align:=alBottom;
  FError.AutoSize:=False; FError.Height:=28; FError.Font.Color:=$008080FF;
  Pages:=TPageControl.Create(Self); Pages.Parent:=Self; Pages.Align:=alRight; Pages.Width:=460; Pages.TabHeight:=34;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='構造・配置';
  FLayout:=TGraphLayoutPanel.Create(Self); FLayout.Parent:=Tab; FLayout.Align:=alClient; FLayout.OnChange:=Changed;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='文字・値';
  FData:=TGraphDataPanel.Create(Self); FData.Parent:=Tab; FData.Align:=alClient; FData.OnChange:=Changed;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='装飾';
  FStyles:=TGraphStylePanel.Create(Self); FStyles.Parent:=Tab; FStyles.Align:=alClient; FStyles.OnChange:=Changed;
  FView:=TGraphView.Create(Self); FView.Parent:=Self; FView.Align:=alClient; FView.OnEdited:=ViewEdited;
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
  FLayout.Grid.OnContextPopup:=FormatMenu;
  FBusy:=False;
end;

destructor TGraphEditorForm.Destroy;
begin
  if FTimer<>nil then FTimer.Enabled:=False;
  FMenuGroup.Free; FDoc.Free; inherited;
end;

procedure TGraphEditorForm.Load(const Pixels:TBytes; Width,Height:Integer;
  const Settings:string; const Shared:TGraphShared);
begin
  FDoc:=LoadGraph(Settings); FInitialShared:=Shared;
  FWidth:=Width; FHeight:=Height;
  if (FWidth<=0) or (FHeight<=0) then begin FWidth:=1920; FHeight:=1080; end;
  if Int64(FWidth)*FHeight>33554432 then raise EArgumentException.Create('編集画像のサイズが大きすぎます。');
  FBackground:=Copy(Pixels);
  if Length(FBackground)<>Int64(FWidth)*FHeight*4 then SetLength(FBackground,NativeInt(FWidth)*FHeight*4);
  if (FDoc.Bounds.Width=0) or (FDoc.Bounds.Height=0) then FDoc.ResetBounds(FWidth,FHeight);
  FInitialData:=SaveGraph(FDoc);
  LoadPanels; FData.Load(Shared,FDoc); RenderPreview; FView.Fit;
end;

procedure TGraphEditorForm.LoadPanels;
begin
  FBusy:=True;
  try FLayout.Load(FDoc); FStyles.Load(FDoc); finally FBusy:=False; end;
end;

procedure TGraphEditorForm.Changed(Sender:TObject);
begin
  if FBusy then Exit;
  if Sender=FStyles then UpdatePreview(nil) else FTimer.Enabled:=True;
end;

procedure TGraphEditorForm.UpdatePreview(Sender:TObject);
var S:TGraphShared; OldRows,OldCols:Integer; OldKind:TGraphKind; Check:TGraphDocument;
begin
  FTimer.Enabled:=False;
  try
    S:=FData.ReadShared; OldRows:=FDoc.Rows; OldCols:=FDoc.Columns; OldKind:=FDoc.Kind;
    FStyles.Apply; FLayout.Apply(FDoc);
    Check:=LoadGraph(SaveGraph(FDoc)); Check.Free;
    if (OldRows<>FDoc.Rows) or (OldCols<>FDoc.Columns) or (OldKind<>FDoc.Kind) then
    begin FData.Load(S,FDoc); FStyles.Load(FDoc); end;
    RenderPreview; FError.Caption:='';
  except on E:Exception do FError.Caption:=E.Message; end;
end;

procedure TGraphEditorForm.RenderPreview;
var Output,Image:TBytes; Labels:TArray<TGraphLabel>; Animation:TGraphAnimation;
begin
  Animation:=Default(TGraphAnimation);
  Output:=RenderGraph(FDoc,FData.ReadShared,Animation,FWidth,FHeight,Labels);
  Image:=Copy(FBackground); CompositeRgba(Image,Output);
  FView.SetRgba(Image,FWidth,FHeight); FView.Bind(FDoc,Labels);
end;

procedure TGraphEditorForm.ViewEdited(Sender:TObject);
begin
  FLayout.Load(FDoc);
  try RenderPreview; except on E:Exception do FError.Caption:=E.Message; end;
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
  end;
end;

procedure TGraphEditorForm.ActionClick(Sender:TObject);
var Tag:Integer;
begin
  Tag:=TToolbarIconButton(Sender).Tag;
  if Tag=0 then begin FView.Fit; Exit; end;
  FTimer.Enabled:=False;
  case Tag of
    1:begin
      FDoc.Free; FDoc:=LoadGraph(FInitialData);
      FData.ClearCache; FData.Load(FInitialShared,FDoc);
    end;
    2:FDoc.ResetBounds(FWidth,FHeight);
    3:FDoc.ResetOffsets;
  end;
  LoadPanels; RenderPreview; FError.Caption:='';
end;

procedure TGraphEditorForm.Closing(Sender:TObject; var CanClose:Boolean);
begin UpdatePreview(nil); CanClose:=FError.Caption=''; end;
function TGraphEditorForm.Settings:string;
begin Result:=SaveGraph(FDoc); end;
function TGraphEditorForm.Shared:TGraphShared;
begin Result:=FData.ReadShared; end;
procedure TGraphEditorForm.FormatMenu(Sender:TObject; MousePos:TPoint; var Handled:Boolean);
begin
  Handled:=FLayout.Grid.Row=12;
  if Handled then FMenu.OpenAtScreenPoint(FLayout.Grid.ClientToScreen(MousePos));
end;
procedure TGraphEditorForm.FormatPreset(Sender:TObject);
begin
  if TPanel(Sender).Tag=0 then FLayout.Grid.Cells[1,12]:=''
  else FLayout.Grid.Cells[1,12]:=TPanel(Sender).Caption;
  FMenu.Close; Changed(nil);
end;
end.
