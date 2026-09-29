unit GraphTextToolbar;

// 選択した文字の分類に対する書体・基本装飾を、編集画面上部で直接変更する。
interface
uses System.Classes, System.Types, System.UITypes, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Graphics, GraphModel, DarkComboBox, ToolbarIconButton;
type
  TGraphTextToolbar=class(TPanel)
  private
    FDoc:TGraphDocument;
    FRole:TTextRole;
    FBusy:Boolean;
    FOnChange:TNotifyEvent;
    FRoleLabel:TLabel;
    FFont:TDarkComboBox;
    FButtons:array[0..4] of TToolbarIconButton;
    procedure FontChanged(Sender:TObject);
    procedure ToolClick(Sender:TObject);
    procedure DrawTool(Sender:TObject; Canvas:TCanvas; const Bounds:TRect;
      const State:TToolbarIconState);
  public
    constructor Create(AOwner:TComponent); override;
    procedure Bind(Doc:TGraphDocument; Role:TTextRole);
    procedure Refresh;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses System.SysUtils, Vcl.Forms, Vcl.Controls, Winapi.Windows, System.Skia,
  GraphColorPopup;

constructor TGraphTextToolbar.Create(AOwner:TComponent);
const Hints:array[0..4] of string=('太字','斜体','文字色','縁取り色','影色');
var I:Integer; Name:string; Face:ISkTypeface;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  BevelOuter:=bvNone; Height:=44; Visible:=False;
  FRoleLabel:=TLabel.Create(Self); FRoleLabel.Parent:=Self;
  FRoleLabel.AutoSize:=False; FRoleLabel.SetBounds(0,11,70,28);
  FRoleLabel.Font.Color:=$00EEEEEE;
  FFont:=TDarkComboBox.Create(Self); FFont.Parent:=Self;
  FFont.SetBounds(72,4,230,34); FFont.OnChange:=FontChanged;
  FFont.Font.Color:=$00EEEEEE;
  // GDIの一覧にはSkiaが解決できないフォントも含まれる。
  for Name in Screen.Fonts do
  begin
    if (Name='') or (Name[1]='@') then Continue;
    try
      Face:=TSkTypeface.MakeFromName(Name,TSkFontStyle.Normal);
      if (Face<>nil) and SameText(Face.FamilyName,Name) then FFont.Items.Add(Name);
    except
      // 列挙できても描画エンジン側で開けないフォントは候補に含めない。
    end;
  end;
  for I:=0 to 4 do
  begin
    FButtons[I]:=TToolbarIconButton.Create(Self);
    FButtons[I].Parent:=Self; FButtons[I].SetBounds(310+I*40,3,36,36);
    FButtons[I].Tag:=I; FButtons[I].Hint:=Hints[I];
    FButtons[I].OnDrawIcon:=DrawTool; FButtons[I].OnClick:=ToolClick;
  end;
end;

procedure TGraphTextToolbar.Bind(Doc:TGraphDocument; Role:TTextRole);
begin
  FDoc:=Doc; FRole:=Role; Visible:=Doc<>nil;
  Refresh;
end;

procedure TGraphTextToolbar.Refresh;
const Names:array[TTextRole] of string=('表題','要素名','単位','値・目盛');
var S:TTextStyle; I:Integer;
begin
  if FDoc=nil then Exit;
  FBusy:=True;
  try
    S:=FDoc.TextStyles[FRole];
    FRoleLabel.Caption:=Names[FRole];
    I:=FFont.Items.IndexOf(S.Font);
    FFont.ItemIndex:=I;
    if I<0 then FFont.TextHint:=S.Font+'（描画不可）'
    else FFont.TextHint:='';
    FButtons[0].Selected:=S.Bold;
    FButtons[1].Selected:=S.Italic;
    for I:=2 to 4 do FButtons[I].Invalidate;
  finally FBusy:=False; end;
end;

procedure TGraphTextToolbar.FontChanged(Sender:TObject);
begin
  if FBusy or (FDoc=nil) or (FFont.ItemIndex<0) then Exit;
  FDoc.TextStyles[FRole].Font:=FFont.Items[FFont.ItemIndex];
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphTextToolbar.ToolClick(Sender:TObject);
var Tag:Integer; S:TTextStyle; C:TAlphaColor; Changed:Boolean;
begin
  if FDoc=nil then Exit;
  Tag:=TToolbarIconButton(Sender).Tag;
  S:=FDoc.TextStyles[FRole]; Changed:=True;
  case Tag of
    0:S.Bold:=not S.Bold;
    1:S.Italic:=not S.Italic;
    2:begin C:=S.Color; Changed:=PickGraphColor(C); if Changed then S.Color:=C; end;
    3:begin C:=S.OutlineColor; Changed:=PickGraphColor(C); if Changed then S.OutlineColor:=C; end;
    4:begin C:=S.ShadowColor; Changed:=PickGraphColor(C); if Changed then S.ShadowColor:=C; end;
  end;
  if not Changed then Exit;
  FDoc.TextStyles[FRole]:=S;
  Refresh;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphTextToolbar.DrawTool(Sender:TObject; Canvas:TCanvas;
  const Bounds:TRect; const State:TToolbarIconState);
var Tag:Integer; S:TTextStyle; C:TAlphaColor; R:TRect;
begin
  Tag:=TToolbarIconButton(Sender).Tag;
  if (FDoc=nil) or (Tag<0) or (Tag>4) then Exit;
  S:=FDoc.TextStyles[FRole];
  if Tag=0 then
  begin Canvas.Font.Style:=[fsBold]; Canvas.Font.Size:=14;
    Canvas.TextOut(Bounds.Left+3,Bounds.Top-2,'B'); Exit; end;
  if Tag=1 then
  begin Canvas.Font.Style:=[fsItalic]; Canvas.Font.Size:=14;
    Canvas.TextOut(Bounds.Left+5,Bounds.Top-2,'I'); Exit; end;
  case Tag of
    2:C:=S.Color; 3:C:=S.OutlineColor;
  else C:=S.ShadowColor; end;
  R:=Bounds; InflateRect(R,-2,-3);
  Canvas.Brush.Style:=bsSolid;
  Canvas.Brush.Color:=RGB((C shr 16) and 255,(C shr 8) and 255,C and 255);
  Canvas.Pen.Color:=State.Foreground;
  Canvas.Rectangle(R);
end;
end.
