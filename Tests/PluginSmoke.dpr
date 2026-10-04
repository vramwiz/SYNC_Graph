program PluginSmoke;
{$APPTYPE CONSOLE}

// 生成したauf2の公開ABIをロードし、人工ホストで映像コールバックを検証する。
uses System.SysUtils, System.Classes, System.Math, Winapi.Windows,
  AviUtl2FilterTypes, GraphModel, GraphSettings, GraphHostLog;
type
  TInitialize=function(Version:Cardinal):Byte; cdecl;
  TInitializeLogger=procedure(Handle:PGraphLogHandle); cdecl;
  TFinalize=procedure; cdecl;
  TTable=function:PFILTER_PLUGIN_TABLE; cdecl;
  PItem=^TFILTER_ITEM_STRING;
  PSelect=^TFILTER_ITEM_SELECT;
  PTrack=^TFILTER_ITEM_TRACK;
  TSelectItems=array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  PSelectItems=^TSelectItems;
  PThreadCapture=^TThreadCapture;
  TThreadCapture=record
    Calls,GpuCalls:Integer;
    Blue:Byte;
    Output:TBytes;
  end;
var Table:PFILTER_PLUGIN_TABLE; Calls,GpuCalls,TransferMode,LogCount:Integer; Output:TBytes;
  LastLog:string;
threadvar TransferProbe:Double; ThreadCapture:PThreadCapture;
procedure CaptureLog(Handle:PGraphLogHandle; Message:PWideChar); cdecl;
begin Inc(LogCount); LastLog:=string(Message); end;
procedure ConvertTransferPixel;
begin
  // 画像転送内にも端数計算を含め、描画だけの例外保護では不足する条件を再現する。
  TransferProbe:=40; TransferProbe:=TransferProbe/255;
end;
procedure GetImage(Buffer:PPIXEL_RGBA); cdecl;
var I:Integer; P:PByte; Blue:Byte;
begin
  if TransferMode=3 then raise EInvalidOp.Create('Injected input failure');
  if TransferMode=1 then ConvertTransferPixel;
  Blue:=40; if ThreadCapture<>nil then Blue:=ThreadCapture^.Blue;
  P:=PByte(Buffer);
  for I:=0 to 640*480-1 do
  begin P[0]:=0; P[1]:=0; P[2]:=Blue; P[3]:=255; Inc(P,4); end;
end;
function UnexpectedGpuAccess:Pointer; cdecl;
begin
  Result:=nil;
  if ThreadCapture<>nil then Inc(ThreadCapture^.GpuCalls) else Inc(GpuCalls);
end;
procedure SetImage(Buffer:PPIXEL_RGBA; W,H:Integer); cdecl;
begin
  if TransferMode=4 then raise EInvalidOp.Create('Injected output failure');
  if TransferMode=2 then ConvertTransferPixel;
  if ThreadCapture<>nil then
  begin
    Inc(ThreadCapture^.Calls); SetLength(ThreadCapture^.Output,W*H*4);
    Move(Buffer^,ThreadCapture^.Output[0],Length(ThreadCapture^.Output)); Exit;
  end;
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

procedure CheckWorkerPlayback(const Video:TFILTER_PROC_VIDEO);
const Positions:array[0..11] of Double=(0,0.00001,0.01,15,99.99,100,
  100.01,199.99,200,299.99,300,150);
var Worker:TThread; Failure:string;
begin
  // テストを別スレッドへ移し、初期化済みメインスレッドと同じ条件になるのを避ける。
  Worker:=TThread.CreateAnonymousThread(
    procedure
    var D:TGraphDocument; S:TGraphShared; Data:string; K:TGraphKind;
      V:TFILTER_PROC_VIDEO; Pattern,Mode,Transition,I,J:Integer;
      SelectTransition,SelectMode:PSelect; Progress,Zoom:PTrack;
      HostMask:TArithmeticExceptionMask;
    begin
      try
        V:=Video;
        SelectTransition:=PSelect(FindItem('推移方法'));
        SelectMode:=PSelect(FindItem('アニメーション'));
        Progress:=PTrack(FindItem('進行')); Zoom:=PTrack(FindItem('演出 拡大率'));
        D:=TGraphDocument.Create;
        try
          D.ResetBounds(640,480); D.ResizeStructure(3,1);
          S:=DefaultShared; S.Values:='10'#13#10'20'#13#10'30';
          SetText('値',PChar(S.Values)); Zoom^.Value:=150;
          D.Lines[4].OutlineWidth:=2; D.Lines[5].OutlineWidth:=2;
          for K:=gkRadar to gkPie do
          begin
            D.Kind:=K;
            if K=gkPie then
            begin D.ResizeStructure(3,1); S.Values:=''#13#10'0'#13#10'30'; end
            else
            begin D.ResizeStructure(3,3); S.Values:='10,,30'#13#10'0,20,'#13#10',40,50'; end;
            SetText('値',PChar(S.Values));
            D.Stacked:=K=gkBar; D.Horizontal:=K in [gkLine,gkBar];
            for Pattern:=1 to 4 do
            begin
              for J:=0 to 2 do D.Series[J].FillPattern:=Pattern;
              D.Lines[4].Kind:=2+Pattern mod 2; D.Lines[5].Kind:=D.Lines[4].Kind;
              Data:=SaveGraph(D); SetText('設定データ',PChar(Data));
              for Transition:=0 to 4 do
              for Mode:=1 to 2 do
              for I:=0 to High(Positions) do
              begin
                SelectTransition^.Value:=Transition; SelectMode^.Value:=Mode;
                Progress^.Value:=Positions[I]*D.Columns;
                case I mod 3 of
                  0:HostMask:=[exDenormalized,exUnderflow,exPrecision];
                  1:HostMask:=[exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision];
                else HostMask:=[exDenormalized,exUnderflow]; end;
                TransferMode:=1+I mod 2;
                SetExceptionMask(HostMask); Calls:=0;
                if Table^.Func_Proc_Video(@V)<>1 then
                  raise Exception.CreateFmt('Playback failed: kind=%d pattern=%d transition=%d mode=%d frame=%d',
                    [Ord(K),Pattern,Transition,Mode,I]);
                if GetExceptionMask<>HostMask then raise Exception.Create('Host exception mask changed');
                SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision]);
                if (Calls<>1) or (Length(Output)<>640*480*4) then
                  raise Exception.Create('Playback output missing');
                // 拡大時はグラフが四隅へ届くので、特定座標ではなく残った入力画素を確認する。
                J:=0;
                while (J<640*480) and ((Output[J*4]<>0) or (Output[J*4+1]<>0) or
                  (Output[J*4+2]<>40) or (Output[J*4+3]<>255)) do Inc(J);
                if J=640*480 then raise Exception.Create('Playback background damaged');
                if I=10 then
                begin
                  J:=0;
                  while (J<640*480) and (Output[J*4]=0) and (Output[J*4+1]=0) do Inc(J);
                  if J=640*480 then raise Exception.Create('Playback graph missing');
                end;
              end;
            end;
            Writeln('PASS worker playback with floating point image transfer ',Ord(K));
          end;
          if GpuCalls<>0 then raise Exception.Create('Host GPU callback was used');
        finally D.Free; end;
      except on E:Exception do Failure:=E.ClassName+': '+E.Message; end;
    end);
  Worker.FreeOnTerminate:=False; Worker.Start;
  // ネイティブ描画が停止した場合も、独立したテストプロセスだけを終了する。
  if WaitForSingleObject(Worker.Handle,30000)<>WAIT_OBJECT_0 then
  begin Writeln('FAIL worker playback timed out'); Halt(1); end;
  Worker.Free;
  if Failure<>'' then raise Exception.Create(Failure);
end;

{$WARN SYMBOL_PLATFORM OFF} // Win64映像境界のMXCSR全体を検証する。
procedure CheckChangedGraphPlayback(const Video:TFILTER_PROC_VIDEO);
var D:TGraphDocument; S:TGraphShared; Data:string; K:TGraphKind;
  Previous,HostState:Cardinal; I,Pass,BeforeCalls,J:Integer; First:TBytes;
begin
  Previous:=GetMXCSR;
  D:=TGraphDocument.Create;
  try
    D.ResetBounds(640,480); D.ResizeStructure(3,1);
    S:=DefaultShared; S.Values:='20'#13#10'50'#13#10'80'; SetText('値',PChar(S.Values));
    PSelect(FindItem('推移方法'))^.Value:=3;
    PSelect(FindItem('アニメーション'))^.Value:=2;
    PTrack(FindItem('演出 拡大率'))^.Value:=100;
    for K:=gkRadar to gkPie do
    for I:=0 to 11 do
    begin
      // 種類・色・文字サイズの変更直後にキャッシュを作り、同じフレームを再生し直す。
      SetMXCSR($1F80); D.Kind:=K; D.Rotation:=I;
      D.Series[0].FillColor:=$FF008000+Cardinal(I*10);
      D.TextStyles[trValue].Size:=20+I;
      Data:=SaveGraph(D); SetText('設定データ',PChar(Data));
      PTrack(FindItem('進行'))^.Value:=50+I*20;
      // 精度例外を有効にし、丸めモード・既存の例外状態も含めて保存されることを確認する。
      HostState:=($0F80 or Cardinal((I mod 4) shl 13)) or $20;
      for Pass:=0 to 1 do
      begin
        TransferMode:=1+I mod 2; BeforeCalls:=Calls; SetMXCSR(HostState);
        SetMXCSRExceptionFlag($20); HostState:=GetMXCSR;
        if Table^.Func_Proc_Video(@Video)<>1 then
          raise Exception.CreateFmt('Changed graph playback failed: kind=%d edit=%d pass=%d',
            [Ord(K),I,Pass]);
        if GetMXCSR<>HostState then raise Exception.Create('Full host floating point state changed');
        SetMXCSR($1F80);
        if Calls<>BeforeCalls+1 then raise Exception.Create('Changed graph output missing');
        J:=0;
        while (J<640*480) and ((Output[J*4]<>0) or (Output[J*4+1]<>0) or
          (Output[J*4+2]<>40) or (Output[J*4+3]<>255)) do Inc(J);
        if J=640*480 then raise Exception.Create('Changed graph background damaged');
        if Pass=0 then First:=Copy(Output)
        else if not CompareMem(@First[0],@Output[0],Length(First)) then
          raise Exception.Create('First playback differs from cached playback');
      end;
    end;
    TransferMode:=0;
    Writeln('PASS changed graph first/cached playback and complete host state: 96 frames');
  finally D.Free; SetMXCSR(Previous); end;
end;

procedure CheckVideoFailureLog(const Video:TFILTER_PROC_VIDEO);
const Stages:array[3..4] of string=('入力画像取得','出力画像転送');
var Mode,BeforeLogs:Integer; Previous,HostState:Cardinal;
begin
  Previous:=GetMXCSR;
  try
    for Mode:=3 to 4 do
    begin
      TransferMode:=Mode; BeforeLogs:=LogCount; HostState:=$0F80 or $20;
      SetMXCSR(HostState); SetMXCSRExceptionFlag($20); HostState:=GetMXCSR;
      if Table^.Func_Proc_Video(@Video)<>0 then raise Exception.Create('Transfer error was ignored');
      if GetMXCSR<>HostState then raise Exception.Create('Transfer error changed host state');
      SetMXCSR($1F80);
      if (LogCount<>BeforeLogs+1) or (Pos(Stages[Mode],LastLog)=0) or
        (Pos('frame=',LastLog)=0) then raise Exception.Create('Failure stage/frame log missing');
    end;
    TransferMode:=0;
    if Table^.Func_Proc_Video(@Video)<>1 then raise Exception.Create('Playback did not recover after transfer error');
    Writeln('PASS image transfer error log, state restoration and next-frame recovery');
  finally TransferMode:=0; SetMXCSR(Previous); end;
end;
{$WARN SYMBOL_PLATFORM ON}

procedure CheckConcurrentPlayback(const Video:TFILTER_PROC_VIDEO);
var D:TGraphDocument; S:TGraphShared; Data:string; K:TGraphKind; Gate:THandle;
  Workers:array[0..1] of TThread; Failures:array[0..1] of string; I:Integer;
  function MakeWorker(Index:Integer):TThread;
  begin
    Result:=TThread.CreateAnonymousThread(
      procedure
      var V:TFILTER_PROC_VIDEO; Obj:TOBJECT_INFO; Capture:TThreadCapture; Frame,J:Integer;
      begin
        Capture:=Default(TThreadCapture); Capture.Blue:=40+Index;
        ThreadCapture:=@Capture;
        try
          V:=Video; Obj:=Video.Object_^; Obj.ID:=400+Index; V.Object_:=@Obj;
          if WaitForSingleObject(Gate,10000)<>WAIT_OBJECT_0 then raise Exception.Create('Worker start timed out');
          for Frame:=0 to 99 do
          begin
            Obj.Frame:=Frame;
            SetExceptionMask([exDenormalized,exUnderflow]);
            if Table^.Func_Proc_Video(@V)<>1 then raise Exception.Create('Concurrent video callback failed');
            SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision]);
            if (Capture.Calls<>Frame+1) or (Length(Capture.Output)<>640*480*4) then
              raise Exception.Create('Concurrent output missing');
            J:=0;
            while (J<640*480) and ((Capture.Output[J*4]<>0) or (Capture.Output[J*4+1]<>0) or
              (Capture.Output[J*4+2]<>Capture.Blue) or (Capture.Output[J*4+3]<>255)) do Inc(J);
            if J=640*480 then raise Exception.Create('Concurrent input background mixed');
          end;
          if Capture.GpuCalls<>0 then raise Exception.Create('Concurrent host GPU access');
        except on E:Exception do Failures[Index]:=E.ClassName+': '+E.Message; end;
        ThreadCapture:=nil;
      end);
    Result.FreeOnTerminate:=False;
  end;
begin
  D:=TGraphDocument.Create;
  try
    D.ResetBounds(640,480); D.ResizeStructure(3,1);
    S:=DefaultShared; S.Values:='10'#13#10'20'#13#10'30'; SetText('値',PChar(S.Values));
    PTrack(FindItem('進行'))^.Value:=150; TransferMode:=2;
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K; Data:=SaveGraph(D); SetText('設定データ',PChar(Data));
      Gate:=CreateEvent(nil,True,False,nil); if Gate=0 then RaiseLastOSError;
      try
        for I:=0 to 1 do begin Failures[I]:=''; Workers[I]:=MakeWorker(I); Workers[I].Start; end;
        SetEvent(Gate);
        for I:=0 to 1 do
          if WaitForSingleObject(Workers[I].Handle,30000)<>WAIT_OBJECT_0 then
          begin Writeln('FAIL concurrent playback timed out'); Halt(1); end;
        for I:=0 to 1 do Workers[I].Free;
        for I:=0 to 1 do if Failures[I]<>'' then raise Exception.Create(Failures[I]);
      finally CloseHandle(Gate); end;
    end;
    Writeln('PASS simultaneous native host threads with separate object backgrounds: 800 frames');
  finally D.Free; TransferMode:=0; end;
end;

procedure Run;
var Lib:HMODULE; Init:TInitialize; Done:TFinalize; GetTable:TTable;
  InitLogger:TInitializeLogger; Logger:TGraphLogHandle;
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
    InitLogger:=TInitializeLogger(GetProcAddress(Lib,'InitializeLogger'));
    if not Assigned(InitLogger) then raise Exception.Create('Missing logger export');
    if not Assigned(Init) or not Assigned(Done) or not Assigned(GetTable) then raise Exception.Create('Missing exports');
    if Init(0)<>1 then raise Exception.Create('Initialize failed');
    try
      Logger:=Default(TGraphLogHandle); Logger.Error:=CaptureLog; InitLogger(@Logger);
      Table:=GetTable();
      if (Table=nil) or (string(Table^.Name)<>'グラフ') or (string(Table^.Label_)<>'SYNC') then raise Exception.Create('Wrong registration');
      Writeln('PASS plugin exports and SYNC registration');
      Transition:=PSelect(FindItem('推移方法'));
      GraphMode:=PSelect(FindItem('アニメーション'));
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
        CheckWorkerPlayback(Video);
        CheckChangedGraphPlayback(Video);
        CheckVideoFailureLog(Video);
        CheckConcurrentPlayback(Video);
      finally D.Free; end;
    finally Done; end;
  finally FreeLibrary(Lib); end;
end;
begin
  try Run; except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
