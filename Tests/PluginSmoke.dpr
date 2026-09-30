program PluginSmoke;
{$APPTYPE CONSOLE}

// 生成したauf2の公開ABIをロードし、人工ホストで映像コールバックを検証する。
uses System.SysUtils, Winapi.Windows, AviUtl2FilterTypes, GraphModel, GraphSettings;
type
  TInitialize=function(Version:Cardinal):Byte; cdecl;
  TFinalize=procedure; cdecl;
  TTable=function:PFILTER_PLUGIN_TABLE; cdecl;
  PItem=^TFILTER_ITEM_STRING;
  PSelect=^TFILTER_ITEM_SELECT;
  PTrack=^TFILTER_ITEM_TRACK;
  TSelectItems=array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  PSelectItems=^TSelectItems;
var Table:PFILTER_PLUGIN_TABLE; Calls,GpuCalls:Integer; Output:TBytes;
procedure GetImage(Buffer:PPIXEL_RGBA); cdecl;
var I:Integer; P:PByte;
begin
  P:=PByte(Buffer);
  for I:=0 to 640*480-1 do
  begin P[0]:=0; P[1]:=0; P[2]:=40; P[3]:=255; Inc(P,4); end;
end;
function UnexpectedGpuAccess:Pointer; cdecl;
begin
  Result:=nil;
  Inc(GpuCalls);
end;
procedure SetImage(Buffer:PPIXEL_RGBA; W,H:Integer); cdecl;
begin
  Inc(Calls); SetLength(Output,W*H*4); Move(Buffer^,Output[0],Length(Output));
end;
function FindItem(const Name:string):Pointer;
var P:PPointer;
begin
  P:=PPointer(Table^.Items);
  while P^<>nil do
  begin
    if string(PItem(P^)^.Name)=Name then Exit(P^);
    Inc(P);
  end;
  raise Exception.Create('Item missing: '+Name);
end;
procedure SetText(const Name:string; Value:PWideChar);
begin PItem(FindItem(Name))^.Value:=Value; end;
procedure Run;
var Lib:HMODULE; Init:TInitialize; Done:TFinalize; GetTable:TTable;
  Scene:TSCENE_INFO; Obj:TOBJECT_INFO; Video:TFILTER_PROC_VIDEO;
  D:TGraphDocument; S:TGraphShared; Data:string; K:TGraphKind;
  I,Colored,StartPixel,FullPixel:Integer;
  Transition,GraphMode:PSelect; Progress,Zoom:PTrack;
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
      Transition:=PSelect(FindItem('推移方法'));
      GraphMode:=PSelect(FindItem('グラフアニメーション'));
      Progress:=PTrack(FindItem('進行'));
      Zoom:=PTrack(FindItem('演出 拡大率'));
      if (string(Transition^.ItemType)<>'select') or
        (string(PSelectItems(Transition^.List)^[0].Name)<>'なし') or
        (string(PSelectItems(Transition^.List)^[4].Name)<>'セル行方向') or
        (string(PSelectItems(GraphMode^.List)^[1].Name)<>'フェード') or
        (string(PSelectItems(GraphMode^.List)^[2].Name)<>'伸長') or
        (Progress^.Value<>0) or (Progress^.S<>0) or
        (Progress^.E<>MaxGraphRows*MaxGraphColumns*100) or
        (Zoom^.Value<>100) or (Zoom^.S<>100) or (Zoom^.E<150) then
        raise Exception.Create('Animation host parameters are wrong');
      Writeln('PASS animation host parameters');
      if Table^.Func_Proc_Video(nil)<>1 then raise Exception.Create('nil callback failed');
      Scene:=Default(TSCENE_INFO); Scene.Width:=640; Scene.Height:=480;
      Obj:=Default(TOBJECT_INFO); Obj.ID:=1; Obj.EffectID:=2; Obj.Width:=640; Obj.Height:=480;
      Video:=Default(TFILTER_PROC_VIDEO); Video.Scene:=@Scene; Video.Object_:=@Obj;
      Video.GetImageData:=GetImage; Video.SetImageData:=SetImage;
      Video.GetFramebufferTexture2D:=UnexpectedGpuAccess;
      Video.GetImageTexture2D:=UnexpectedGpuAccess;
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
        D.Kind:=gkBar; D.ResizeStructure(1,1);
        S.Values:='80'; Data:=SaveGraph(D);
        SetText('設定データ',PChar(Data)); SetText('値',PChar(S.Values));
        Transition^.Value:=4; GraphMode^.Value:=2; Progress^.Value:=0;
        if Table^.Func_Proc_Video(@Video)<>1 then
          raise Exception.Create('Animation start callback failed');
        StartPixel:=Output[(300*640+320)*4];
        Progress^.Value:=100;
        if Table^.Func_Proc_Video(@Video)<>1 then
          raise Exception.Create('Animation end callback failed');
        FullPixel:=Output[(300*640+320)*4];
        if FullPixel<=StartPixel then
          raise Exception.Create('Host progress did not reveal the bar');
        Zoom^.Value:=150;
        if Table^.Func_Proc_Video(@Video)<>1 then
          raise Exception.Create('Zoom callback failed');
        if Output[(200*640+110)*4]=0 then
          raise Exception.Create('Host zoom did not expand the bar');
        Writeln('PASS host animation progress and focus zoom');
        Calls:=0;
        for I:=0 to 299 do
        begin
          Progress^.Value:=I mod 101;
          if Table^.Func_Proc_Video(@Video)<>1 then
            raise Exception.Create('Repeated playback callback failed');
        end;
        if Calls<>300 then raise Exception.Create('Repeated playback output missing');
        if GpuCalls<>0 then raise Exception.Create('Host GPU callback was used');
        Writeln('PASS repeated playback without host GPU access');
      finally D.Free; end;
    finally Done; end;
  finally FreeLibrary(Lib); end;
end;
begin
  try Run; except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
