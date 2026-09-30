unit GraphSettings;

// 構造・装飾だけを版付きJSONへ保存する。表題・名前・単位・値は含めない。
interface
uses GraphModel;
function SaveGraph(Doc: TGraphDocument): string;
function LoadGraph(const Text: string): TGraphDocument;
implementation
uses System.Generics.Collections, System.JSON, System.SysUtils, System.Types, System.Math;

procedure Number(O:TJSONObject; const Key:string; V:Double);
begin O.AddPair(Key,TJSONNumber.Create(V)); end;

function SaveGraph(Doc:TGraphDocument):string;
var O,S:TJSONObject; A:TJSONArray; I:Integer; R:TTextRole;
begin
  O:=TJSONObject.Create;
  try
    Number(O,'version',2); Number(O,'kind',Ord(Doc.Kind));
    Number(O,'rows',Doc.Rows); Number(O,'columns',Doc.Columns);
    Number(O,'x',Doc.Bounds.Left); Number(O,'y',Doc.Bounds.Top);
    Number(O,'width',Doc.Bounds.Width); Number(O,'height',Doc.Bounds.Height);
    Number(O,'horizontal',Ord(Doc.Horizontal)); Number(O,'stacked',Ord(Doc.Stacked));
    Number(O,'rotation',Doc.Rotation); Number(O,'nameLayout',Doc.NameLayout);
    O.AddPair('minimum',Doc.Minimum); O.AddPair('maximum',Doc.Maximum);
    O.AddPair('interval',Doc.Interval); O.AddPair('format',Doc.ValueFormat);
    A:=TJSONArray.Create; O.AddPair('series',A);
    for I:=0 to High(Doc.Series) do
    begin
      S:=TJSONObject.Create; A.AddElement(S);
      Number(S,'line',Doc.Series[I].LineColor); Number(S,'fill',Doc.Series[I].FillColor);
      Number(S,'transparency',Doc.Series[I].Transparency); Number(S,'marker',Doc.Series[I].Marker); Number(S,'lineKind',Doc.Series[I].LineKind);
    end;
    A:=TJSONArray.Create; O.AddPair('text',A);
    for R:=Low(TTextRole) to High(TTextRole) do
    begin
      S:=TJSONObject.Create; A.AddElement(S);
      S.AddPair('font',Doc.TextStyles[R].Font); Number(S,'size',Doc.TextStyles[R].Size);
      Number(S,'color',Doc.TextStyles[R].Color); Number(S,'bold',Ord(Doc.TextStyles[R].Bold));
      Number(S,'italic',Ord(Doc.TextStyles[R].Italic));
      Number(S,'outlineColor',Doc.TextStyles[R].OutlineColor);
      Number(S,'outlineWidth',Doc.TextStyles[R].OutlineWidth);
      Number(S,'outlineBlur',Doc.TextStyles[R].OutlineBlur);
      Number(S,'shadowColor',Doc.TextStyles[R].ShadowColor);
      Number(S,'shadowX',Doc.TextStyles[R].ShadowX); Number(S,'shadowY',Doc.TextStyles[R].ShadowY);
      Number(S,'shadowBlur',Doc.TextStyles[R].ShadowBlur);
    end;
    A:=TJSONArray.Create; O.AddPair('lines',A);
    for I:=0 to High(Doc.Lines) do
    begin
      S:=TJSONObject.Create; A.AddElement(S);
      Number(S,'kind',Doc.Lines[I].Kind); Number(S,'color',Doc.Lines[I].Color);
      Number(S,'width',Doc.Lines[I].Width); Number(S,'outlineColor',Doc.Lines[I].OutlineColor);
      Number(S,'outlineWidth',Doc.Lines[I].OutlineWidth);
    end;
    A:=TJSONArray.Create; O.AddPair('offsets',A);
    // 未調整の位置は省略し、大きな行列でも設定文字列を肥大化させない。
    for I:=0 to High(Doc.Offsets) do
      if (Doc.Offsets[I].X<>0) or (Doc.Offsets[I].Y<>0) then
      begin
        S:=TJSONObject.Create; A.AddElement(S); Number(S,'id',I);
        Number(S,'x',Doc.Offsets[I].X); Number(S,'y',Doc.Offsets[I].Y);
      end;
    A:=TJSONArray.Create; O.AddPair('labelScales',A);
    for I:=0 to High(Doc.LabelScales) do
      if Doc.LabelScales[I]<>1 then
      begin
        S:=TJSONObject.Create; A.AddElement(S);
        Number(S,'id',I); Number(S,'scale',Doc.LabelScales[I]);
      end;
    Result:=O.ToJSON;
  finally O.Free; end;
end;

function N(O:TJSONObject;const Key:string; Default,Lo,Hi:Double):Double;
begin
  Result:=O.GetValue<Double>(Key,Default);
  if IsNan(Result) or IsInfinite(Result) or (Result<Lo) or (Result>Hi) then
    raise EConvertError.Create('設定データの範囲が不正です: '+Key);
end;

function LoadGraph(const Text:string):TGraphDocument;
var V:TJSONValue; O,S:TJSONObject; A:TJSONArray; I,ID:Integer; R:TTextRole;
begin
  Result:=TGraphDocument.Create;
  if Text='' then Exit;
  V:=TJSONObject.ParseJSONValue(Text);
  try
    try
      if not(V is TJSONObject) then raise EConvertError.Create('設定データがJSONではありません。');
      O:=TJSONObject(V);
      // 旧キャンバステストの表示設定は、未設定グラフとして安全に移行する。
      if O.GetValue<Double>('version',0)=1 then Exit;
      if (O.GetValue<Double>('version',0)<>0) and
        (O.GetValue<Double>('version',0)<>2) then
        raise EConvertError.Create('未対応の設定データ版です。');
      Result.Kind:=TGraphKind(Trunc(N(O,'kind',0,0,4)));
      Result.ResizeStructure(Trunc(N(O,'rows',3,1,MaxGraphRows)),Trunc(N(O,'columns',3,1,MaxGraphColumns)));
      Result.Bounds:=TRectF.Create(N(O,'x',0,-100000,100000),N(O,'y',0,-100000,100000),0,0);
      Result.Bounds.Width:=N(O,'width',0,0,100000);
      Result.Bounds.Height:=N(O,'height',0,0,100000);
      Result.Horizontal:=N(O,'horizontal',0,0,1)=1; Result.Stacked:=N(O,'stacked',0,0,1)=1;
      Result.Rotation:=N(O,'rotation',0,-360,360); Result.NameLayout:=Trunc(N(O,'nameLayout',0,0,2));
      Result.Minimum:=O.GetValue<string>('minimum',''); Result.Maximum:=O.GetValue<string>('maximum','');
      Result.Interval:=O.GetValue<string>('interval',''); Result.ValueFormat:=O.GetValue<string>('format','');
      if O.GetValue('series') is TJSONArray then
      begin
        A:=O.GetValue<TJSONArray>('series');
        if A.Count>MaxGraphColumns then raise EConvertError.Create('系列設定が多すぎます。');
        if Length(Result.Series)<A.Count then SetLength(Result.Series,A.Count);
        for I:=0 to A.Count-1 do
        begin
          S:=A.Items[I] as TJSONObject;
          Result.Series[I].LineColor:=Trunc(N(S,'line',Palette(I),0,$FFFFFFFF));
          Result.Series[I].FillColor:=Trunc(N(S,'fill',Palette(I),0,$FFFFFFFF));
          Result.Series[I].Transparency:=N(S,'transparency',0,0,100);
          Result.Series[I].LineKind:=Trunc(N(S,'lineKind',1,1,3));
          Result.Series[I].Marker:=Trunc(N(S,'marker',0,0,2));
        end;
      end;
      if O.GetValue('text') is TJSONArray then
      begin
        A:=O.GetValue<TJSONArray>('text');
        if A.Count>4 then raise EConvertError.Create('文字装飾の分類数が不正です。');
        for I:=0 to A.Count-1 do
        begin
        R:=TTextRole(I);
        S:=A.Items[I] as TJSONObject;
        Result.TextStyles[R].Font:=S.GetValue<string>('font','Yu Gothic UI');
        Result.TextStyles[R].Size:=N(S,'size',28,1,500);
        Result.TextStyles[R].Color:=Trunc(N(S,'color',$FFFFFFFF,0,$FFFFFFFF));
        Result.TextStyles[R].Bold:=N(S,'bold',0,0,1)=1;
        Result.TextStyles[R].Italic:=N(S,'italic',0,0,1)=1;
        Result.TextStyles[R].OutlineColor:=Trunc(N(S,'outlineColor',$FF000000,0,$FFFFFFFF));
        Result.TextStyles[R].OutlineWidth:=N(S,'outlineWidth',1,0,30);
        Result.TextStyles[R].OutlineBlur:=N(S,'outlineBlur',0,0,30);
        Result.TextStyles[R].ShadowColor:=Trunc(N(S,'shadowColor',$B0000000,0,$FFFFFFFF));
        Result.TextStyles[R].ShadowX:=N(S,'shadowX',0,-100,100);
        Result.TextStyles[R].ShadowY:=N(S,'shadowY',0,-100,100);
        Result.TextStyles[R].ShadowBlur:=N(S,'shadowBlur',0,0,30);
        end;
      end;
      if O.GetValue('lines') is TJSONArray then
      begin
        A:=O.GetValue<TJSONArray>('lines');
        if A.Count>Length(Result.Lines) then raise EConvertError.Create('線設定の分類数が不正です。');
        for I:=0 to A.Count-1 do
        begin
        S:=A.Items[I] as TJSONObject;
        Result.Lines[I].Kind:=Trunc(N(S,'kind',1,0,3));
        Result.Lines[I].Color:=Trunc(N(S,'color',$FFCCCCCC,0,$FFFFFFFF));
        Result.Lines[I].Width:=N(S,'width',2,0,50);
        Result.Lines[I].OutlineColor:=Trunc(N(S,'outlineColor',$FF000000,0,$FFFFFFFF));
        Result.Lines[I].OutlineWidth:=N(S,'outlineWidth',0,0,30);
        end;
      end;
      if O.GetValue('offsets') is TJSONArray then
      begin
        A:=O.GetValue<TJSONArray>('offsets');
        if A.Count>Length(Result.Offsets) then raise EConvertError.Create('位置補正が多すぎます。');
        for I:=0 to A.Count-1 do
        begin
          S:=A.Items[I] as TJSONObject; ID:=Trunc(N(S,'id',0,0,High(Result.Offsets)));
          Result.Offsets[ID]:=PointF(N(S,'x',0,-100000,100000),N(S,'y',0,-100000,100000));
        end;
      end;
      if O.GetValue('labelScales') is TJSONArray then
      begin
        A:=O.GetValue<TJSONArray>('labelScales');
        if A.Count>Length(Result.LabelScales) then raise EConvertError.Create('文字倍率が多すぎます。');
        for I:=0 to A.Count-1 do
        begin
          S:=A.Items[I] as TJSONObject;
          ID:=Trunc(N(S,'id',0,0,High(Result.LabelScales)));
          Result.LabelScales[ID]:=N(S,'scale',1,0.1,20);
        end;
      end;
    except Result.Free; raise; end;
  finally V.Free; end;
end;
end.
