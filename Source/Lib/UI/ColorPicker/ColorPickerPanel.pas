unit ColorPickerPanel;

// SYNC_Graphの配置と色コード編集を、フォームに依存しない部品として収集。
interface
uses System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Graphics,
  ColorPickerHueBar, ColorPickerSVArea;
type
  TColorValueFormat = (cvHex, cvRGB);
  TColorPickerPanel = class(TPanel)
  private
    FHue: TColorPickerHueBar;
    FSV: TColorPickerSVArea;
    FTitle, FCodeLabel: TLabel;
    FCode: TEdit;
    FValueFormat: TColorValueFormat;
    FOnChange: TNotifyEvent;
    function GetSelectedColor: TColor;
    procedure SetSelectedColor(Value: TColor);
    procedure SetValueFormat(Value: TColorValueFormat);
    procedure UpdateCode;
    procedure HueChanged(Sender: TObject);
    procedure SVChanged(Sender: TObject);
    procedure CodeExit(Sender: TObject);
    procedure CodeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Changed;
  protected
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshLayout;
    property SelectedColor: TColor read GetSelectedColor write SetSelectedColor;
    property ValueFormat: TColorValueFormat read FValueFormat write SetValueFormat;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses Winapi.Windows, System.SysUtils, System.Math, ColorPickerColorMath, ColorCode;
constructor TColorPickerPanel.Create(AOwner: TComponent);
begin
  inherited;
  // 子Editのハンドル生成に備え、Ownerが画面部品なら先に親を確定する。
  if AOwner is TWinControl then Parent := TWinControl(AOwner);
  BevelOuter := bvNone; ParentBackground := False; ParentColor := False;
  StyleElements := []; Color := $303030;
  ParentFont := False; Font.Name := 'Yu Gothic UI'; Font.Size := 10; Font.Color := $EEEEEE;
  Width := 320; Height := 350;
  FTitle := TLabel.Create(Self); FTitle.Parent := Self; FTitle.Caption := 'カラー';
  FSV := TColorPickerSVArea.Create(Self); FSV.Parent := Self; FSV.OnChange := SVChanged;
  FHue := TColorPickerHueBar.Create(Self); FHue.Parent := Self; FHue.OnChange := HueChanged;
  FCodeLabel := TLabel.Create(Self); FCodeLabel.Parent := Self; FCodeLabel.Caption := '色コード';
  FCode := TEdit.Create(Self); FCode.Parent := Self; FCode.StyleElements := [];
  FCode.Color := $303030; FCode.Font.Color := $EEEEEE;
  FCode.OnExit := CodeExit; FCode.OnKeyDown := CodeKeyDown;
  FCode.ShowHint := True; FCode.Hint := 'HEXまたはRGBを入力し、Enterで確定';
  SelectedColor := clRed; Resize;
end;
procedure TColorPickerPanel.Resize;
var Side, P, Top, Row: Integer;
  function S(N: Integer): Integer;
  begin Result := MulDiv(N, CurrentPPI, 96); end;
begin
  inherited;
  if FCode = nil then Exit;
  P := S(12); Top := S(36);
  Canvas.Font.Assign(Font); Row := Max(S(28), Canvas.TextHeight('国Ag') + S(8));
  Side := Max(1, Min(ClientWidth-S(60), ClientHeight-Top-Row-S(24)));
  FTitle.SetBounds(P,S(8),ClientWidth-2*P,Row);
  FSV.SetBounds(P,Top,Side,Side);
  FHue.SetBounds(P+Side+S(8),Top,S(28),Side);
  FCodeLabel.SetBounds(P,Top+Side+S(16),S(60),Row);
  FCode.SetBounds(S(76),Top+Side+S(12),Max(S(40),ClientWidth-S(88)),Row);
end;
procedure TColorPickerPanel.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin inherited; Resize; end;
procedure TColorPickerPanel.RefreshLayout;
begin Resize; end;
function TColorPickerPanel.GetSelectedColor: TColor;
begin Result := FSV.Color; end;
procedure TColorPickerPanel.SetSelectedColor(Value: TColor);
begin
  Value := ColorToRGB(Value); FHue.Color := Value;
  FSV.BaseColor := HsvToColor(ColorHue(Value),1,1); FSV.Color := Value; UpdateCode;
end;
procedure TColorPickerPanel.SetValueFormat(Value: TColorValueFormat);
begin FValueFormat := Value; UpdateCode; end;
procedure TColorPickerPanel.UpdateCode;
var C: TColor;
begin
  C := ColorToRGB(SelectedColor);
  if FValueFormat = cvHex then
    FCode.Text := Format('#%.2x%.2x%.2x',[GetRValue(C),GetGValue(C),GetBValue(C)])
  else FCode.Text := Format('%d,%d,%d',[GetRValue(C),GetGValue(C),GetBValue(C)]);
  FCode.Font.Color := $EEEEEE;
end;
procedure TColorPickerPanel.Changed;
begin UpdateCode; if Assigned(FOnChange) then FOnChange(Self); end;
procedure TColorPickerPanel.HueChanged(Sender: TObject);
var H, S, V: Double;
begin
  ColorToHsv(FSV.Color,H,S,V); FSV.BaseColor := FHue.Color;
  FSV.Color := HsvToColor(ColorHue(FHue.Color),S,V); Changed;
end;
procedure TColorPickerPanel.SVChanged(Sender: TObject);
begin Changed; end;
procedure TColorPickerPanel.CodeExit(Sender: TObject);
var C: TColor;
begin
  if not TryParseColorCode(FCode.Text,C) then
  begin FCode.Font.Color := $8080FF; Exit; end;
  SelectedColor := C; Changed;
end;
procedure TColorPickerPanel.CodeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then begin Key := 0; CodeExit(Sender); end
  else if Key = VK_ESCAPE then begin Key := 0; UpdateCode; end;
end;
end.
