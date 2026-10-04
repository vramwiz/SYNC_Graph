unit GraphHostParameters;

// ホストの項目登録と現在値のコピー。文字列ポインターはコールバック外へ持ち出さない。
interface
uses AviUtl2FilterTypes, GraphModel, GraphAnimation;
const
  GraphEffectName='グラフ';
  GraphSettingsName='設定データ';
  SharedNames:array[0..3] of string=('表題','要素名','単位','値');
procedure RegisterGraphParameters(Callback:TFilterItemButtonCallback);
function CurrentShared:TGraphShared;
function CurrentSettings:string;
function CurrentAnimation:TGraphAnimation;
implementation
uses PluginFilterTable, System.SysUtils;
var
  Button:TFILTER_ITEM_BUTTON;
  Data,Title,Units:TFILTER_ITEM_STRING;
  Names,Values:TFILTER_ITEM_TEXT;
  TransitionMode,GraphMode:TFILTER_ITEM_SELECT;
  Progress,ZoomPercent:TFILTER_ITEM_TRACK;
  TransitionList:array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  GraphModeList:array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  Initial:TGraphShared;
procedure RegisterGraphParameters(Callback:TFilterItemButtonCallback);
begin
  Initial:=DefaultShared;
  AddButton(Button,'設定',Callback); AddString(Title,'表題',PChar(Initial.Title));
  AddText(Names,'要素名',Initial.Names); AddString(Units,'単位',PChar(Initial.Units));
  AddText(Values,'値',Initial.Values); AddString(Data,GraphSettingsName,'');
  // AddTextの引数は一時WideStringになり得るため、登録後は寿命の長い所有文字列を参照する。
  Names.Value:=PChar(Initial.Names); Values.Value:=PChar(Initial.Values);
  ClearSelectList;
  AddSelectList(TransitionList,'なし',0);
  AddSelectList(TransitionList,'列',1);
  AddSelectList(TransitionList,'行',2);
  AddSelectList(TransitionList,'セル列方向',3);
  AddSelectList(TransitionList,'セル行方向',4);
  AddSelect(TransitionMode,'推移方法',0,@TransitionList[0]);
  AddSelectList(GraphModeList,'なし',0);
  AddSelectList(GraphModeList,'フェード',1);
  AddSelectList(GraphModeList,'伸長',2);
  AddSelect(GraphMode,'アニメーション',0,@GraphModeList[0]);
  // SDKのトラック上限は登録時に固定。実際の終点は要素数×データ数×100。
  AddTrack(Progress,'進行',0,0,MaxGraphRows*MaxGraphColumns*100,0.01);
  AddTrack(ZoomPercent,'演出 拡大率',100,100,300,1);
end;
function CopyText(P:PWideChar):string;
begin if P=nil then Result:='' else Result:=string(P); end;
function CurrentShared:TGraphShared;
begin
  Result.Title:=CopyText(Title.Value); Result.Names:=CopyText(Names.Value);
  Result.Units:=CopyText(Units.Value); Result.Values:=CopyText(Values.Value);
end;
function CurrentSettings:string;
begin Result:=CopyText(Data.Value); end;
function CurrentAnimation:TGraphAnimation;
begin
  Result:=Default(TGraphAnimation);
  Result.TransitionMode:=TransitionMode.Value;
  Result.GraphMode:=GraphMode.Value;
  Result.Progress:=Progress.Value;
  Result.ZoomPercent:=ZoomPercent.Value;
end;
end.
