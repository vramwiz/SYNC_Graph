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
    FOnColorTargetChange:TNotifyEvent;
    FColorTarget:Integer;
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
    function SelectedColor:TAlphaColor;
    procedure SetSelectedColor(Color:TAlphaColor);
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property OnColorTargetChange:TNotifyEvent read FOnColorTargetChange write FOnColorTargetChange;
  end;
implementation
uses System.SysUtils, Vcl.Forms, Vcl.Controls, Winapi.Windows, System.Skia, GraphFonts;

constructor TGraphTextToolbar.Create(AOwner:TComponent);
const Hints:array[0..4] of string=('太字','斜体','文字色','縁取り色','影色');
var I:Integer; Name:string; Face:ISkTypeface;
  function S(Value:Integer):Integer;
  begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  BevelOuter:=bvNone; Height:=S(44); Visible:=False;
  FRoleLabel:=TLabel.Create(Self); FRoleLabel.Parent:=Self;
  FRoleLabel.AutoSize:=False; FRoleLabel.SetBounds(S(0),S(11),S(70),S(28));
  FRoleLabel.Font.Color:=$00EEEEEE;
  FFont:=TDarkComboBox.Create(Self); FFont.Parent:=Self;
  FFont.SetBounds(S(72),S(4),S(230),S(34)); FFont.OnChange:=FontChanged;
  FFont.Font.Color:=$00EEEEEE;
  // 描画と同じ実書体の解決を使う。言語別名の一致だけでは候補を除外しない。
  for Name in Screen.Fonts do
  begin
    if (Name='') or (Name[1]='@') then Continue;
    try
      Face:=ResolveGraphTypeface(Name,TSkFontStyle.Normal);
      if Face<>nil then FFont.Items.Add(Name);
    except
      // 列挙できても描画エンジン側で開けないフォントは候補に含めない。
    end;
  end;
  for I:=0 to 4 do
  begin
    FButtons[I]:=TToolbarIconButton.Create(Self);
    FButtons[I].Parent:=Self; FButtons[I].SetBounds(S(310+I*40),S(3),S(36),S(36));
    FButtons[I].Tag:=I; FButtons[I].Hint:=Hints[I];
    FButtons[I].OnDrawIcon:=DrawTool; FButtons[I].OnClick:=ToolClick;
  end;
end;

procedure TGraphTextToolbar.Bind(Doc:TGraphDocument; Role:TTextRole);
begin
  FDoc:=Doc; FRole:=Role; FColorTarget:=2; Visible:=Doc<>nil;
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
    if I<0 then FFont.TextHint:=S.Font+'（一覧外）'
    else FFont.TextHint:='';
    FButtons[0].Selected:=S.Bold;
    FButtons[1].Selected:=S.Italic;
    for I:=2 to 4 do
    begin FButtons[I].Selected:=I=FColorTarget; FButtons[I].Invalidate; end;
  finally FBusy:=False; end;
end;

procedure TGraphTextToolbar.FontChanged(Sender:TObject);
begin
  if FBusy or (FDoc=nil) or (FFont.ItemIndex<0) then Exit;
  FDoc.TextStyles[FRole].Font:=FFont.Items[FFont.ItemIndex];
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphTextToolbar.ToolClick(Sender:TObject);
var Tag:Integer; S:TTextStyle;
begin
  if FDoc=nil then Exit;
  Tag:=TToolbarIconButton(Sender).Tag;
  if Tag>=2 then
  begin
    FColorTarget:=Tag;
    Refresh;
    if Assigned(FOnColorTargetChange) then FOnColorTargetChange(Self);
    Exit;
  end;
  S:=FDoc.TextStyles[FRole];
  case Tag of
    0:S.Bold:=not S.Bold;
    1:S.Italic:=not S.Italic;
  end;
  FDoc.TextStyles[FRole]:=S;
  Refresh;
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TGraphTextToolbar.SelectedColor:TAlphaColor;
begin
  Result:=$FFFFFFFF;
  if FDoc=nil then Exit;
  case FColorTarget of
    3:Result:=FDoc.TextStyles[FRole].OutlineColor;
    4:Result:=FDoc.TextStyles[FRole].ShadowColor;
  else Result:=FDoc.TextStyles[FRole].Color;
  end;
end;

procedure TGraphTextToolbar.SetSelectedColor(Color:TAlphaColor);
var S:TTextStyle; Old:TAlphaColor;
begin
  if FDoc=nil then Exit;
  S:=FDoc.TextStyles[FRole]; Old:=SelectedColor;
  Color:=(Old and $FF000000) or (Color and $00FFFFFF);
  if Color=Old then Exit;
  case FColorTarget of
    3:S.OutlineColor:=Color;
    4:S.ShadowColor:=Color;
  else S.Color:=Color;
  end;
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
