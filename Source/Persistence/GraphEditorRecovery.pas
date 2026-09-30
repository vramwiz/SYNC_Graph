unit GraphEditorRecovery;

// 入力エラーで閉じられなくなることを防ぎ、修復用の生入力を別ファイルへ保管する。
// 通常のホスト設定とは別の診断用JSON。UIの走査は編集スレッドからだけ呼ぶ。
interface
uses System.Classes, GraphModel;
function CaptureEditorInputs(Root:TComponent):string;
function SaveEditorRecovery(const Inputs,Error,CurrentSettings,ValidSettings:string;
  const CurrentShared,ValidShared:TGraphShared):string;
implementation
uses System.SysUtils, System.JSON, System.IOUtils, Vcl.StdCtrls,
  GraphNumberEdit, DarkComboBox, HorizontalTrackBarControl;
function CaptureEditorInputs(Root:TComponent):string;
var Items:TJSONArray;
  procedure Visit(Owner:TComponent; const Path:string);
  var I:Integer; C:TComponent; Entry:TJSONObject; Value,Location:string; HasValue:Boolean;
  begin
    for I:=0 to Owner.ComponentCount-1 do
    begin
      C:=Owner.Components[I]; HasValue:=True; Value:='';
      if C is TEdit then Value:=TEdit(C).Text
      else if C is TGraphNumberEdit then Value:=TGraphNumberEdit(C).Text
      else if C is TComboBox then Value:=TComboBox(C).Text
      else if C is TDarkComboBox then Value:=TDarkComboBox(C).Text
      else if C is TCheckBox then Value:=BoolToStr(TCheckBox(C).Checked,True)
      else if C is THorizontalTrackBarControl then Value:=IntToStr(THorizontalTrackBarControl(C).Position)
      else HasValue:=False;
      Location:=Path+'/'+C.ClassName+'['+IntToStr(I)+']';
      if HasValue then
      begin
        Entry:=TJSONObject.Create; Entry.AddPair('path',Location); Entry.AddPair('value',Value);
        Items.AddElement(Entry);
      end;
      Visit(C,Location);
    end;
  end;
begin
  Items:=TJSONArray.Create;
  try Visit(Root,Root.ClassName); Result:=Items.ToJSON; finally Items.Free; end;
end;
function SharedJSON(const S:TGraphShared):TJSONObject;
begin
  Result:=TJSONObject.Create;
  Result.AddPair('title',S.Title); Result.AddPair('names',S.Names);
  Result.AddPair('units',S.Units); Result.AddPair('values',S.Values);
end;
function SaveEditorRecovery(const Inputs,Error,CurrentSettings,ValidSettings:string;
  const CurrentShared,ValidShared:TGraphShared):string;
var O:TJSONObject; Folder,Temp:string; ID:TGUID;
begin
  O:=TJSONObject.Create;
  try
    O.AddPair('version',TJSONNumber.Create(1)); O.AddPair('error',Error);
    O.AddPair('inputs',TJSONObject.ParseJSONValue(Inputs));
    O.AddPair('currentSettings',CurrentSettings); O.AddPair('validSettings',ValidSettings);
    O.AddPair('currentShared',SharedJSON(CurrentShared)); O.AddPair('validShared',SharedJSON(ValidShared));
    Folder:=GetEnvironmentVariable('LOCALAPPDATA');
    if Folder='' then Folder:=TPath.GetTempPath;
    Folder:=TPath.Combine(Folder,'SYNC_Graph\Recovery'); ForceDirectories(Folder);
    CreateGUID(ID);
    Result:=TPath.Combine(Folder,FormatDateTime('yyyymmdd-hhnnss',Now)+'-'+GUIDToString(ID)+'.json');
    // 固有名で過去の保管を上書きしない。自動復元はせず、利用者が修復内容を選ぶ。
    Temp:=Result+'.tmp';
    // 完全に書き終えたファイルだけを復旧用JSONとして公開する。
    TFile.WriteAllText(Temp,O.ToJSON,TEncoding.UTF8); TFile.Move(Temp,Result);
  finally O.Free; end;
end;
end.
