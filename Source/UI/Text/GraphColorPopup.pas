unit GraphColorPopup;

// 既存の色相・彩度明度Libを接続する小さな色選択画面。色コードも直接入力できる。
interface
uses System.UITypes;
function PickGraphColor(var Color:TAlphaColor):Boolean;
implementation
uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.Graphics, ColorPickerHueBar, ColorPickerSVArea, ColorPickerColorMath,
  ColorCode, Winapi.Windows, DarkEditorTheme;
type
  TGraphColorForm=class(TForm)
  private
    FHue:TColorPickerHueBar;
    FArea:TColorPickerSVArea;
    FCode:TEdit;
    procedure HueChanged(Sender:TObject);
    procedure AreaChanged(Sender:TObject);
  public
    constructor Create(AOwner:TComponent); override;
  end;
constructor TGraphColorForm.Create(AOwner:TComponent);
var B:TButton;
begin
  inherited CreateNew(AOwner); ApplyDarkEditor(Self); Caption:='色'; Position:=poMainFormCenter;
  ClientWidth:=300; ClientHeight:=360; BorderStyle:=bsDialog;
  FHue:=TColorPickerHueBar.Create(Self); FHue.Parent:=Self; FHue.SetBounds(12,12,276,24);
  FArea:=TColorPickerSVArea.Create(Self); FArea.Parent:=Self; FArea.SetBounds(12,46,276,210);
  FHue.OnChange:=HueChanged; FArea.OnChange:=AreaChanged;
  FCode:=TEdit.Create(Self); FCode.Parent:=Self; FCode.SetBounds(12,270,276,32);
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='選択'; B.SetBounds(130,316,75,32);
  B.ModalResult:=mrOk; B.Default:=True;
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='取消'; B.SetBounds(213,316,75,32);
  B.ModalResult:=mrCancel; B.Cancel:=True;
end;
procedure TGraphColorForm.HueChanged(Sender:TObject);
begin FArea.BaseColor:=FHue.Color; end;
procedure TGraphColorForm.AreaChanged(Sender:TObject);
var C:TColor;
begin C:=ColorToRGB(FArea.Color); FCode.Text:=Format('#%.2x%.2x%.2x',[GetRValue(C),GetGValue(C),GetBValue(C)]); end;
function PickGraphColor(var Color:TAlphaColor):Boolean;
var F:TGraphColorForm; C:TColor;
begin
  F:=TGraphColorForm.Create(nil);
  try
    C:=RGB((Color shr 16) and 255,(Color shr 8) and 255,Color and 255);
    F.FHue.Color:=C; F.FArea.BaseColor:=C; F.FArea.Color:=C; F.AreaChanged(nil);
    Result:=F.ShowModal=mrOk;
    if Result then
    begin
      if not TryParseColorCode(F.FCode.Text,C) then raise EConvertError.Create('色コードが不正です。');
      Color:=(Color and $FF000000) or (Cardinal(GetRValue(C)) shl 16) or
        (Cardinal(GetGValue(C)) shl 8) or GetBValue(C);
    end;
  finally F.Free; end;
end;
end.
