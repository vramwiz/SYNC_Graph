unit GraphHostSettings;

// 編集APIからUTF-8をコピーし、複数項目保存の失敗時は元の値への復元を試みる。
interface
uses AviUtl2FilterTypes, GraphModel;
function ReadItem(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE; const Name:string):string;
function ReadShared(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE):TGraphShared;
procedure WriteSettings(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE;
  const Shared:TGraphShared; const Settings:string);
implementation
uses System.SysUtils, GraphHostParameters;
function ReadItem(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE; const Name:string):string;
var P:PAnsiChar;
begin
  P:=Edit^.GetObjectItemValue(Obj,GraphEffectName,PChar(Name));
  if P=nil then Result:='' else Result:=string(UTF8String(P));
end;
function ReadShared(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE):TGraphShared;
begin
  // 編集APIの複数行項目はエイリアス形式（リテラルの\n）。描画APIの生文字列とは区別する。
  Result.Title:=ReadItem(Edit,Obj,SharedNames[0]); Result.Names:=ReadItem(Edit,Obj,SharedNames[1]).Replace('\n',#13#10);
  Result.Units:=ReadItem(Edit,Obj,SharedNames[2]); Result.Values:=ReadItem(Edit,Obj,SharedNames[3]).Replace('\n',#13#10);
end;
procedure WriteSettings(Edit:PEDIT_SECTION; Obj:OBJECT_HANDLE;
  const Shared:TGraphShared; const Settings:string);
var Names,Old,NewValues:array[0..4] of string; I,J:Integer; Text:UTF8String; Reverted:Boolean;
begin
  for I:=0 to 3 do Names[I]:=SharedNames[I]; Names[4]:=GraphSettingsName;
  NewValues[0]:=Shared.Title; NewValues[1]:=Shared.Names; NewValues[2]:=Shared.Units;
  NewValues[3]:=Shared.Values; NewValues[4]:=Settings;
  // 読み戻した旧値は既にエイリアス形式なので、復元時に再変換しない。
  for I in [1,3] do
    NewValues[I]:=NewValues[I].Replace(#13#10,#10).Replace(#13,#10).Replace(#10,'\n');
  for I:=0 to 4 do Old[I]:=ReadItem(Edit,Obj,Names[I]);
  for I:=0 to 4 do
  begin
    if NewValues[I]=Old[I] then Continue;
    Text:=UTF8String(NewValues[I]);
    if not Edit^.SetObjectItemValue(Obj,GraphEffectName,PChar(Names[I]),PAnsiChar(Text)) then
    begin
      Reverted:=True;
      for J:=I downto 0 do
      begin
        Text:=UTF8String(Old[J]);
        if not Edit^.SetObjectItemValue(Obj,GraphEffectName,PChar(Names[J]),PAnsiChar(Text)) then Reverted:=False;
      end;
      if Reverted then raise EInvalidOp.Create('設定を保存できなかったため、元の値へ戻しました。')
      else raise EInvalidOp.Create('設定の保存と復元に失敗しました。ホスト側の項目を確認してください。');
    end;
  end;
end;
end.
