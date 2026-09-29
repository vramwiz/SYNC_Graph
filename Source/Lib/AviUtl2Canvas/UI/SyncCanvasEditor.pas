unit SyncCanvasEditor;

// Minimal editor and versioned host-persisted viewport settings.
interface

uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.StdCtrls, SyncCanvasView;

type
  TSyncCanvasEditor = class(TForm)
  private
    FView: TSyncCanvasView;
    FValue: TEdit;
    FStatus: TLabel;
    procedure FitClick(Sender: TObject);
    procedure ViewChanged(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadSnapshot(const Pixels: TBytes; Width, Height: Integer;
      const Data, Status: string);
    function SaveData: string;
    property View: TSyncCanvasView read FView;
  end;

implementation

uses System.JSON, Vcl.Controls, Vcl.ExtCtrls;

constructor TSyncCanvasEditor.Create(AOwner: TComponent);
var Bar: TPanel; Button: TButton; HintLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'SYNC - グラフ';
  Position := poScreenCenter;
  ClientWidth := 960;
  ClientHeight := 640;
  Constraints.MinWidth := 600;
  Constraints.MinHeight := 400;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 44;
  Button := TButton.Create(Self);
  Button.Parent := Bar;
  Button.SetBounds(8, 8, 96, 28);
  Button.Caption := '全体表示';
  Button.OnClick := FitClick;
  FValue := TEdit.Create(Self);
  FValue.Parent := Bar;
  FValue.SetBounds(116, 9, 220, 26);
  FValue.TextHint := 'メモ（設定に保存）';
  HintLabel := TLabel.Create(Self);
  HintLabel.Parent := Bar;
  HintLabel.SetBounds(350, 13, 500, 20);
  HintLabel.Caption := 'ドラッグ: 移動 / ホイール: 拡大縮小 / 閉じる: 保存';
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.AutoSize := False;
  FStatus.Height := 28;
  FView := TSyncCanvasView.Create(Self);
  FView.Parent := Self;
  FView.Align := alClient;
  FView.OnViewChanged := ViewChanged;
  ActiveControl := FView;
end;

procedure TSyncCanvasEditor.FitClick(Sender: TObject);
begin
  FView.Fit;
  FView.SetFocus;
end;

procedure TSyncCanvasEditor.ViewChanged(Sender: TObject);
begin
  FStatus.Caption := Format('倍率 %.1f%% | 位置 %.1f, %.1f | %s',
    [FView.Zoom*100, FView.PanX, FView.PanY, FStatus.Hint]);
end;

procedure TSyncCanvasEditor.LoadSnapshot(const Pixels: TBytes; Width, Height: Integer;
  const Data, Status: string);
var Json: TJSONValue; Obj: TJSONObject;
begin
  FStatus.Hint := Status;
  FView.SetRgba(Pixels, Width, Height);
  FView.Fit;
  if Data = '' then Exit;
  Json := TJSONObject.ParseJSONValue(Data);
  try
    if not (Json is TJSONObject) then raise EConvertError.Create('Invalid saved canvas data');
    Obj := TJSONObject(Json);
    if Obj.GetValue<Integer>('version', 0) <> 1 then
      raise EConvertError.Create('Unsupported canvas data version');
    FView.SetView(Obj.GetValue<Double>('zoom'), Obj.GetValue<Double>('panX'),
      Obj.GetValue<Double>('panY'));
    FValue.Text := Obj.GetValue<string>('value', '');
  finally
    Json.Free;
  end;
end;

function TSyncCanvasEditor.SaveData: string;
var Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('version', TJSONNumber.Create(1));
    Obj.AddPair('zoom', TJSONNumber.Create(FView.Zoom));
    Obj.AddPair('panX', TJSONNumber.Create(FView.PanX));
    Obj.AddPair('panY', TJSONNumber.Create(FView.PanY));
    Obj.AddPair('value', FValue.Text);
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

end.
