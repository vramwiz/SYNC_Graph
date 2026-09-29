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
function CurrentAnimation(Video:PFILTER_PROC_VIDEO):TGraphAnimation;
implementation
uses PluginFilterTable, System.SysUtils;
var
  Button:TFILTER_ITEM_BUTTON;
  Data,Title,Units:TFILTER_ITEM_STRING;
  Names,Values:TFILTER_ITEM_TEXT;
  EnterMode,ExitMode,ElementMode:TFILTER_ITEM_SELECT;
  EnterTime,ExitTime,Progress:TFILTER_ITEM_TRACK;
  EnterList,ExitList,ElementList:array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  Initial:TGraphShared;
procedure RegisterGraphParameters(Callback:TFilterItemButtonCallback);
begin
  Initial:=DefaultShared;
  AddButton(Button,'設定',Callback); AddString(Title,'表題',PChar(Initial.Title));
  AddText(Names,'要素名',Initial.Names); AddString(Units,'単位',PChar(Initial.Units));
  AddText(Values,'値',Initial.Values); AddString(Data,GraphSettingsName,'');
  // AddTextの引数は一時WideStringになり得るため、登録後は寿命の長い所有文字列を参照する。
  Names.Value:=PChar(Initial.Names); Values.Value:=PChar(Initial.Values);
  ClearSelectList; AddSelectList(EnterList,'なし',0); AddSelectList(EnterList,'フェードイン',1);
  AddSelect(EnterMode,'登場',0,@EnterList[0]); AddTrack(EnterTime,'登場時間',0.5,0,60,0.01);
  AddSelectList(ElementList,'なし',0); AddSelectList(ElementList,'パターン1',1);
  AddSelect(ElementMode,'要素の登場',0,@ElementList[0]);
  // SDKのtrack上限は登録時定数。最大系列数まで確保し、実系列数以降は完成状態となる。
  AddTrack(Progress,'進行',0,0,MaxGraphColumns*100,0.01);
  AddSelectList(ExitList,'なし',0); AddSelectList(ExitList,'フェードアウト',1);
  AddSelect(ExitMode,'退場',0,@ExitList[0]); AddTrack(ExitTime,'退場時間',0.5,0,60,0.01);
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
function CurrentAnimation(Video:PFILTER_PROC_VIDEO):TGraphAnimation;
begin
  Result:=Default(TGraphAnimation);
  Result.EnterMode:=EnterMode.Value; Result.ExitMode:=ExitMode.Value; Result.ElementMode:=ElementMode.Value;
  Result.EnterSeconds:=EnterTime.Value; Result.ExitSeconds:=ExitTime.Value; Result.Progress:=Progress.Value;
  if (Video<>nil) and (Video^.Object_<>nil) then
  begin Result.Time:=Video^.Object_^.Time; Result.Duration:=Video^.Object_^.TimeTotal; end;
end;
end.
