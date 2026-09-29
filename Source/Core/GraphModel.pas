unit GraphModel;

// グラフ専用の構造と装飾。共有文字・値はホストから別レコードで受け取る。
interface

uses System.Types, System.UITypes, System.SysUtils;

const
  MaxGraphRows = 64;
  MaxGraphColumns = 256;

type
  TGraphKind = (gkNone, gkRadar, gkLine, gkBar, gkPie);
  TTextRole = (trTitle, trName, trUnit, trValue);
  TLineStyle = record
    Kind: Integer;
    Color, OutlineColor: TAlphaColor;
    Width, OutlineWidth: Single;
  end;
  TTextStyle = record
    Font: string;
    Size: Single;
    Color, OutlineColor, ShadowColor: TAlphaColor;
    Bold, Italic: Boolean;
    OutlineWidth, OutlineBlur, ShadowBlur, ShadowX, ShadowY: Single;
  end;
  TSeriesStyle = record
    LineColor, FillColor: TAlphaColor;
    Transparency: Single;
    Marker: Integer;
  end;
  TGraphShared = record
    Title, Names, Units, Values: string;
  end;
  TGraphDocument = class
  public
    Kind: TGraphKind;
    Rows, Columns: Integer;
    Bounds: TRectF;
    Horizontal, Stacked: Boolean;
    Rotation: Single;
    NameLayout: Integer;
    Minimum, Maximum, Interval, ValueFormat: string;
    TextStyles: array[TTextRole] of TTextStyle;
    Lines: array[0..5] of TLineStyle; // X軸・Y軸・目盛線・外枠・系列線・円区切り線の順。
    Series: TArray<TSeriesStyle>;
    Offsets: TArray<TPointF>;
    constructor Create;
    procedure ResizeStructure(ARows, AColumns: Integer);
    procedure ResetBounds(Width, Height: Integer);
    procedure ResetOffsets;
    function SeriesCount: Integer;
  end;

function DefaultShared: TGraphShared;
function Palette(Index: Integer): TAlphaColor;

implementation

uses System.Math;

function Palette(Index: Integer): TAlphaColor;
const Colors: array[0..7] of TAlphaColor = ($FF56B4E9,$FFE69F00,$FF009E73,
  $FFCC79A7,$FFF0E442,$FFD55E00,$FF879BFF,$FFEEEEEE);
begin
  Result := Colors[Index mod Length(Colors)];
end;

function DefaultShared: TGraphShared;
begin
  Result.Title := 'グラフ名';
  Result.Names := '要素1'#13#10'要素2'#13#10'要素3';
  Result.Units := '単位';
  Result.Values := '0,0,0'#13#10'0,0,0'#13#10'0,0,0';
end;

constructor TGraphDocument.Create;
var Role: TTextRole; I: Integer;
begin
  inherited;
  Rows := 3;
  Columns := 3;
  for Role := Low(TTextRole) to High(TTextRole) do
  begin
    TextStyles[Role].Font := 'Yu Gothic UI';
    TextStyles[Role].Size := 28;
    TextStyles[Role].Color := $FFFFFFFF;
    TextStyles[Role].OutlineColor := $FF000000;
    TextStyles[Role].ShadowColor := $B0000000;
  end;
  TextStyles[trTitle].Size := 42;
  for I := 0 to High(Lines) do
  begin
    Lines[I].Kind := 1;
    Lines[I].Color := $FFCCCCCC;
    Lines[I].Width := 2;
    Lines[I].OutlineColor := $FF000000;
  end;
  Lines[2].Color := $607F7F7F;
  Lines[3].Kind := 0;
  ResizeStructure(Rows, Columns);
end;

procedure TGraphDocument.ResizeStructure(ARows, AColumns: Integer);
var I, OldCount: Integer;
begin
  Rows := EnsureRange(ARows, 1, MaxGraphRows);
  Columns := EnsureRange(AColumns, 1, MaxGraphColumns);
  // 構造縮小時も装飾・補正を捨てず、再拡大時にユーザー値を復元する。
  OldCount := Length(Series);
  if OldCount < Max(Rows, Columns) then
    SetLength(Series, Max(Rows, Columns));
  for I := OldCount to High(Series) do
  begin
    Series[I].LineColor := Palette(I);
    Series[I].FillColor := Palette(I);
  end;
  if Length(Offsets) < 2 + MaxGraphRows + MaxGraphRows * MaxGraphColumns then
    SetLength(Offsets, 2 + MaxGraphRows + MaxGraphRows * MaxGraphColumns);
end;

procedure TGraphDocument.ResetBounds(Width, Height: Integer);
begin
  Bounds := RectF(Width*0.15, Height*0.2, Width*0.85, Height*0.8);
end;

procedure TGraphDocument.ResetOffsets;
var I: Integer;
begin
  for I := 0 to High(Offsets) do Offsets[I] := PointF(0,0);
end;

function TGraphDocument.SeriesCount: Integer;
begin
  if Kind = gkRadar then Result := Columns else Result := Rows;
end;

end.
