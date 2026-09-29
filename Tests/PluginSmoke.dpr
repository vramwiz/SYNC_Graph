program PluginSmoke;
{$APPTYPE CONSOLE}

// 生成したauf2の公開ABIをロードし、人工ホストで映像コールバックを検証する。
uses System.SysUtils, Winapi.Windows, AviUtl2FilterTypes, GraphModel, GraphSettings;
type
  TInitialize=function(Version:Cardinal):Byte; cdecl;
  TFinalize=procedure; cdecl;
  TTable=function:PFILTER_PLUGIN_TABLE; cdecl;
  PItem=^TFILTER_ITEM_STRING;
var Table:PFILTER_PLUGIN_TABLE; Calls:Integer; Output:TBytes;
procedure GetImage(Buffer:PPIXEL_RGBA); cdecl;
var I:Integer; P:PByte;
begin
  P:=PByte(Buffer);
  for I:=0 to 640*480-1 do
  begin P[0]:=0; P[1]:=0; P[2]:=40; P[3]:=255; Inc(P,4); end;
end;
procedure SetImage(Buffer:PPIXEL_RGBA; W,H:Integer); cdecl;
begin
  Inc(Calls); SetLength(Output,W*H*4); Move(Buffer^,Output[0],Length(Output));
end;
procedure SetText(const Name:string; Value:PWideChar);
var P:PPointer;
begin
  P:=PPointer(Table^.Items);
  while P^<>nil do
  begin
    if string(PItem(P^)^.Name)=Name then begin PItem(P^)^.Value:=Value; Exit; end;
    Inc(P);
  end;
  raise Exception.Create('Item missing: '+Name);
end;
procedure Run;
var Lib:HMODULE; Init:TInitialize; Done:TFinalize; GetTable:TTable;
  Scene:TSCENE_INFO; Obj:TOBJECT_INFO; Video:TFILTER_PROC_VIDEO;
  D:TGraphDocument; S:TGraphShared; Data:string; K:TGraphKind; I,Colored:Integer;
begin
  Lib:=LoadLibrary(PChar(ParamStr(1)));
  if Lib=0 then RaiseLastOSError;
  try
    Init:=TInitialize(GetProcAddress(Lib,'InitializePlugin'));
    Done:=TFinalize(GetProcAddress(Lib,'UninitializePlugin'));
    GetTable:=TTable(GetProcAddress(Lib,'GetFilterPluginTable'));
    if not Assigned(Init) or not Assigned(Done) or not Assigned(GetTable) then raise Exception.Create('Missing exports');
    if Init(0)<>1 then raise Exception.Create('Initialize failed');
    try
      Table:=GetTable();
      if (Table=nil) or (string(Table^.Name)<>'グラフ') or (string(Table^.Label_)<>'SYNC') then raise Exception.Create('Wrong registration');
      Writeln('PASS plugin exports and SYNC registration');
      if Table^.Func_Proc_Video(nil)<>1 then raise Exception.Create('nil callback failed');
      Scene:=Default(TSCENE_INFO); Scene.Width:=640; Scene.Height:=480;
      Obj:=Default(TOBJECT_INFO); Obj.ID:=1; Obj.EffectID:=2; Obj.Width:=640; Obj.Height:=480;
      Video:=Default(TFILTER_PROC_VIDEO); Video.Scene:=@Scene; Video.Object_:=@Obj;
      Video.GetImageData:=GetImage; Video.SetImageData:=SetImage;
      D:=TGraphDocument.Create;
      try
        D.ResetBounds(640,480); S:=DefaultShared;
        S.Values:='10,20,30'#13#10'20,30,40'#13#10'30,40,50';
        SetText('表題',PChar(S.Title)); SetText('要素名',PChar(S.Names)); SetText('単位',PChar(S.Units));
        for K:=gkRadar to gkPie do
        begin
          D.Kind:=K;
          if K=gkPie then begin D.ResizeStructure(3,1); S.Values:='10'#13#10'20'#13#10'30'; end;
          Data:=SaveGraph(D); SetText('設定データ',PChar(Data)); SetText('値',PChar(S.Values));
          Calls:=0;
          if Table^.Func_Proc_Video(@Video)<>1 then raise Exception.Create('Video callback failed');
          if Calls<>1 then raise Exception.Create('Output not submitted');
          Colored:=0;
          for I:=0 to 640*480-1 do
          begin
            if Output[I*4+3]<>255 then raise Exception.Create('Background alpha damaged');
            if (Output[I*4]>0) or (Output[I*4+1]>0) then Inc(Colored);
          end;
          if Colored<100 then raise Exception.Create('Graph not composited');
          Writeln('PASS plugin render ',Ord(K));
        end;
      finally D.Free; end;
    finally Done; end;
  finally FreeLibrary(Lib); end;
end;
begin
  try Run; except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
