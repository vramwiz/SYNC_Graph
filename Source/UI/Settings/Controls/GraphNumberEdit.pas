unit GraphNumberEdit;

// 通常は数値を描画し、直接入力するときだけ重ねたTEditを表示する。
interface

uses System.Classes, System.Types, Vcl.StdCtrls, Vcl.Controls;

type
  TGraphNumberEdit = class(TCustomControl)
  private
    FEdit: TEdit;
    FValue, FBeforeEdit: string;
    FMinimum, FMaximum: Double;
    FAllowEmpty, FEditing: Boolean;
    FOnChange: TNotifyEvent;
    function GetText: string;
    procedure SetText(const Value: string);
    function DigitAt(const ScreenPoint: TPoint): Integer;
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditExit(Sender: TObject);
    procedure EndEdit(Commit: Boolean);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    function AdjustAt(const ScreenPoint: TPoint; WheelDelta: Integer): Boolean;
    procedure BeginEdit;
    property Editing: Boolean read FEditing;
    property Text: string read GetText write SetText;
    property Minimum: Double read FMinimum write FMinimum;
    property Maximum: Double read FMaximum write FMaximum;
    property AllowEmpty: Boolean read FAllowEmpty write FAllowEmpty;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Font;
  end;

implementation

uses System.SysUtils, System.Math, Winapi.Windows, Vcl.Graphics;

constructor TGraphNumberEdit.Create(AOwner: TComponent);
begin
  inherited;
  FMinimum:=-1.0E12; FMaximum:=1.0E12;
  ParentColor:=False; Color:=$00303030; Font.Color:=$00EEEEEE;
  TabStop:=True;
  FEdit:=TEdit.Create(Self); FEdit.Parent:=Self;
  FEdit.Align:=alClient; FEdit.Visible:=False;
  FEdit.StyleElements:=[]; FEdit.Color:=Color; FEdit.Font.Assign(Font);
  FEdit.OnKeyDown:=EditKeyDown; FEdit.OnExit:=EditExit;
end;

function TGraphNumberEdit.GetText:string;
begin
  if FEditing then Result:=FEdit.Text else Result:=FValue;
end;

procedure TGraphNumberEdit.SetText(const Value:string);
begin
  if FValue=Value then Exit;
  FValue:=Value;
  if FEditing then FEdit.Text:=Value;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphNumberEdit.Paint;
var R:TRect;
begin
  R:=ClientRect;
  Canvas.Brush.Color:=Color; Canvas.FillRect(R);
  Canvas.Pen.Color:=$00606060; Canvas.Pen.Width:=1;
  Canvas.Rectangle(R);
  Canvas.Font.Assign(Font); Canvas.Brush.Style:=bsClear;
  Canvas.TextOut(4,(ClientHeight-Canvas.TextHeight('0')) div 2,FValue);
  Canvas.Brush.Style:=bsSolid;
end;

procedure TGraphNumberEdit.Resize;
begin
  inherited;
  if FEdit<>nil then FEdit.BoundsRect:=ClientRect;
end;

function TGraphNumberEdit.DigitAt(const ScreenPoint:TPoint):Integer;
var P:TPoint; I,X,W:Integer;
begin
  Result:=-1;
  if FEditing then Exit;
  P:=ScreenToClient(ScreenPoint);
  if not PtInRect(ClientRect,P) then Exit;
  Canvas.Font.Assign(Font);
  X:=4;
  for I:=1 to Length(FValue) do
  begin
    W:=Canvas.TextWidth(FValue[I]);
    if (P.X>=X) and (P.X<X+W) then
    begin
      if CharInSet(FValue[I],['0'..'9']) then Result:=I;
      Exit;
    end;
    Inc(X,W);
    if X>=ClientWidth then Exit;
  end;
end;

function TGraphNumberEdit.AdjustAt(const ScreenPoint:TPoint;
  WheelDelta:Integer):Boolean;
var Digit,Dot,Decimals,Exponent,I,Steps:Integer;
  Value,Increment:Double; S,Pattern:string;
begin
  Digit:=DigitAt(ScreenPoint);
  if (Digit<0) or (WheelDelta=0) then Exit(False);
  Result:=True;
  S:=Trim(FValue);
  if (S='') and FAllowEmpty then Exit;
  if not TryStrToFloat(S,Value,TFormatSettings.Invariant) then Exit;
  Dot:=Pos('.',S);
  if Dot=0 then Dot:=Length(S)+1;
  Decimals:=Max(0,Length(S)-Dot);
  Exponent:=0;
  if Digit<Dot then
  begin
    for I:=Digit+1 to Dot-1 do
      if CharInSet(S[I],['0'..'9']) then Inc(Exponent);
  end
  else
  begin
    for I:=Dot+1 to Digit do
      if CharInSet(S[I],['0'..'9']) then Dec(Exponent);
  end;
  Steps:=WheelDelta div WHEEL_DELTA;
  if Steps=0 then Steps:=Sign(WheelDelta);
  Increment:=Power(10,Exponent)*Steps;
  Value:=EnsureRange(Value+Increment,FMinimum,FMaximum);
  if Decimals=0 then Pattern:='0'
  else Pattern:='0.'+StringOfChar('0',Decimals);
  Text:=FormatFloat(Pattern,Value,TFormatSettings.Invariant);
end;

function TGraphNumberEdit.DoMouseWheel(Shift:TShiftState; WheelDelta:Integer;
  MousePos:TPoint):Boolean;
begin
  Result:=AdjustAt(MousePos,WheelDelta);
  if not Result then Result:=inherited DoMouseWheel(Shift,WheelDelta,MousePos);
end;

procedure TGraphNumberEdit.BeginEdit;
begin
  if FEditing then Exit;
  FBeforeEdit:=FValue; FEditing:=True;
  FEdit.Font.Assign(Font); FEdit.Text:=FValue;
  FEdit.Visible:=True; FEdit.BringToFront;
  FEdit.SetFocus; FEdit.SelectAll;
end;

procedure TGraphNumberEdit.EndEdit(Commit:Boolean);
var NewValue:string;
begin
  if not FEditing then Exit;
  if Commit then NewValue:=FEdit.Text else NewValue:=FBeforeEdit;
  FEditing:=False;
  FEdit.Visible:=False;
  Text:=NewValue;
end;

procedure TGraphNumberEdit.EditKeyDown(Sender:TObject; var Key:Word;
  Shift:TShiftState);
begin
  if Key=VK_RETURN then begin Key:=0; EndEdit(True); end
  else if Key=VK_ESCAPE then begin Key:=0; EndEdit(False); end;
end;

procedure TGraphNumberEdit.EditExit(Sender:TObject);
begin EndEdit(True); end;

procedure TGraphNumberEdit.MouseDown(Button:TMouseButton; Shift:TShiftState;
  X,Y:Integer);
begin
  inherited;
  if Button=mbLeft then BeginEdit;
end;

procedure TGraphNumberEdit.KeyDown(var Key:Word; Shift:TShiftState);
begin
  inherited;
  if (Key=VK_RETURN) or (Key=VK_F2) then
  begin Key:=0; BeginEdit; end;
end;

end.
