unit GraphValues;

// 値文字列を検証して数値行列へ変換し、自動目盛と表示書式を計算する。
interface
uses System.SysUtils, GraphModel;
type
  TGraphValues = TArray<TArray<Double>>;
  TGraphScale = record Minimum, Maximum, Step: Double; end;
function ParseValues(const Text: string; Rows, Columns: Integer): TGraphValues;
function CalculateScale(Doc: TGraphDocument; const Values: TGraphValues): TGraphScale;
function FormatGraphValue(Value: Double; const Pattern: string): string;
function SplitRows(const Text: string): TArray<string>;
function ElementName(const Text: string; Index: Integer): string;
implementation
uses System.Math;

function SplitRows(const Text: string): TArray<string>;
begin
  Result := Text.Replace(#13#10,#10).Replace(#13,#10).Split([#10]);
end;

function ElementName(const Text: string; Index: Integer): string;
var Rows: TArray<string>;
begin
  Rows := SplitRows(Text);
  if (Index >= 0) and (Index < Length(Rows)) then Result := Rows[Index]
  else Result := '';
end;

function ParseValues(const Text: string; Rows, Columns: Integer): TGraphValues;
var Lines, Cells: TArray<string>; R,C: Integer; V: Double;
begin
  if (Rows<1) or (Rows>MaxGraphRows) or (Columns<1) or (Columns>MaxGraphColumns) then
    raise EConvertError.Create('要素数またはデータ数が範囲外です。');
  SetLength(Result,Rows,Columns);
  // 未入力のセルだけ仮データを使う。同じセルは常に同じ値にし、再生・再読込や
  // 構造変更で値が揺れないようにする。明示された0は後でそのまま上書きする。
  for R:=0 to Rows-1 do
    for C:=0 to Columns-1 do Result[R,C]:=20+((R*3+C*5) mod 8)*10;
  Lines := SplitRows(Text);
  for R := 0 to High(Lines) do
  begin
    Cells := Lines[R].Split([',']);
    for C := 0 to High(Cells) do
    begin
      if Trim(Cells[C])='' then Continue;
      if R>=Rows then
        raise EConvertError.Create('値の行数が要素数を超えています。');
      if C>=Columns then
        raise EConvertError.CreateFmt('%d行目の値がデータ数を超えています。',[R+1]);
      if not TryStrToFloat(Trim(Cells[C]),V,TFormatSettings.Invariant) then
        raise EConvertError.CreateFmt('%d行%d列の値が数値ではありません。',[R+1,C+1]);
      if IsNan(V) or IsInfinite(V) or (Abs(V)>1E12) then
        raise EConvertError.Create('値は有限の数値（絶対値1兆以下）で指定してください。');
      Result[R,C]:=V;
    end;
  end;
end;

function ManualValue(const Text: string; Default: Double): Double;
begin
  Result := Default;
  if Trim(Text)='' then Exit;
  if not TryStrToFloat(Text,Result,TFormatSettings.Invariant) or
    IsNan(Result) or IsInfinite(Result) or (Abs(Result)>1E12) then
    raise EConvertError.Create('目盛設定には有限の数値を指定してください。');
end;

function CalculateScale(Doc: TGraphDocument; const Values: TGraphValues): TGraphScale;
var R,C: Integer; Lo,Hi,PosSum,NegSum,Raw,Power10: Double;
begin
  Lo:=0; Hi:=0;
  for C:=0 to Doc.Columns-1 do
  begin
    PosSum:=0; NegSum:=0;
    for R:=0 to Doc.Rows-1 do
    begin
      Lo:=Min(Lo,Values[R,C]); Hi:=Max(Hi,Values[R,C]);
      if Values[R,C]>=0 then PosSum:=PosSum+Values[R,C]
      else NegSum:=NegSum+Values[R,C];
    end;
    if (Doc.Kind=gkBar) and Doc.Stacked then
    begin Lo:=Min(Lo,NegSum); Hi:=Max(Hi,PosSum); end;
  end;
  if Hi=Lo then Hi:=Lo+1;
  Result.Minimum:=ManualValue(Doc.Minimum,Lo);
  Result.Maximum:=ManualValue(Doc.Maximum,Hi);
  if (Doc.Maximum='') and (Result.Maximum<=Result.Minimum) then Result.Maximum:=Result.Minimum+1;
  if (Doc.Minimum='') and (Result.Minimum>=Result.Maximum) then Result.Minimum:=Result.Maximum-1;
  if Result.Maximum<=Result.Minimum then raise EConvertError.Create('最大値は最小値より大きくしてください。');
  Raw:=(Result.Maximum-Result.Minimum)/5;
  Power10:=Power(10,Floor(Log10(Raw)));
  Raw:=Raw/Power10;
  if Raw<=1 then Raw:=1 else if Raw<=2 then Raw:=2 else if Raw<=5 then Raw:=5 else Raw:=10;
  Result.Step:=ManualValue(Doc.Interval,Raw*Power10);
  if (Result.Step<=0) or ((Result.Maximum-Result.Minimum)/Result.Step>1000) then
    raise EConvertError.Create('目盛間隔は正数で、目盛数が1000以下になる値にしてください。');
end;

function FormatGraphValue(Value: Double; const Pattern: string): string;
var First,Last,I: Integer; Prefix,Suffix,Numeric: string;
begin
  if Pattern='' then Exit('');
  First:=0;
  for I:=1 to Length(Pattern) do
    if CharInSet(Pattern[I],['0','#']) then begin First:=I; Break; end;
  if First=0 then raise EConvertError.Create('値書式には0または#を含めてください。');
  Last:=First;
  while (Last<Length(Pattern)) and CharInSet(Pattern[Last+1],['0','#',',','.']) do Inc(Last);
  Prefix:=Copy(Pattern,1,First-1); Suffix:=Copy(Pattern,Last+1,MaxInt);
  Numeric:=Copy(Pattern,First,Last-First+1);
  Result:=Prefix+FormatFloat(Numeric,Value,TFormatSettings.Invariant)+Suffix;
end;
end.
