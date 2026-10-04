unit GraphPlugin;

// DLLの入口と設定画面の接続。ホストABIを越える例外は必ずここで処理する。
interface
uses AviUtl2FilterTypes;
procedure InitializeGraphPlugin;
procedure FinalizeGraphPlugin;
function GraphPluginTable:PFILTER_PLUGIN_TABLE;
implementation
uses System.SysUtils, Winapi.Windows, PluginFilterTable, PluginFilterContextManager,
  GraphRenderContext, GraphHostParameters, GraphHostSettings, GraphEditorForm, GraphHostLog,
  GraphFloatState;
type TContexts=class(TPluginFilterContextList<TGraphRenderContext>);
var Contexts:TContexts;
procedure InitializeGraphPlugin;
begin
  // AviUtl2が作ったスレッドはDelphiのBeginThreadを通らない。
  // UIと映像の同時確保でも、DLL自身のメモリマネージャーにロックを使わせる。
  IsMultiThread:=True;
  if Contexts=nil then Contexts:=TContexts.Create;
end;
procedure FinalizeGraphPlugin;
begin InitializeGraphLogger(nil); FreeAndNil(Contexts); end;
function ProcessVideo(Video:PFILTER_PROC_VIDEO):Byte; cdecl;
var Context:TGraphRenderContext; Stage:string; PreviousMXCSR:Cardinal;
begin
  Result:=1; Stage:='コンテキスト取得';
  PreviousMXCSR:=BeginGraphFloatScope;
  try
  try
    if Contexts=nil then Exit;
    Context:=Contexts.GetContext(Video); if Context<>nil then Context.Process(Video,Stage);
  except
    on E:Exception do begin ReportGraphVideoError(Video,Stage,E); Result:=0; end;
  end;
  // 例外処理・ログ出力が状態を変えた場合も、ABIを戻る直前に復元する。
  finally RestoreGraphFloatScope(PreviousMXCSR); end;
end;
procedure OpenSettings(Edit:PEDIT_SECTION); cdecl;
var Obj:OBJECT_HANDLE; Location:TOBJECT_LAYER_FRAME; Context:TGraphRenderContext;
  Pixels:TBytes; W,H:Integer; Status:string; Form:TGraphEditorForm; PreviousDpi:DPI_AWARENESS_CONTEXT;
begin
  try
    if (Edit=nil) or not Assigned(Edit^.GetFocusObject) or not Assigned(Edit^.GetObjectLayerFrame) or
      not Assigned(Edit^.GetObjectItemValue) or not Assigned(Edit^.SetObjectItemValue) then
      raise EInvalidOp.Create('編集APIを取得できません。');
    Obj:=Edit^.GetFocusObject(); if Obj=nil then raise EInvalidOp.Create('編集対象がありません。');
    Location:=Edit^.GetObjectLayerFrame(Obj); Pixels:=nil; W:=0; H:=0;
    if Contexts<>nil then
    begin
      Context:=Contexts.FindByObjectLocation(Location.Layer,Location.StartFrame,Location.EndFrame);
      if Context<>nil then Context.CopyBackground(Pixels,W,H,Status);
    end;
    PreviousDpi:=SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    try
      Form:=TGraphEditorForm.Create(nil);
      try
        Form.Load(Pixels,W,H,ReadItem(Edit,Obj,GraphSettingsName),ReadShared(Edit,Obj));
        Form.ShowModal;
        WriteSettings(Edit,Obj,Form.Shared,Form.Settings);
      finally Form.Free; end;
    finally
      if IsValidDpiAwarenessContext(PreviousDpi) then SetThreadDpiAwarenessContext(PreviousDpi);
    end;
  except on E:Exception do MessageBox(0,PChar(E.Message),'SYNC グラフ',MB_OK or MB_ICONERROR); end;
end;
function GraphPluginTable:PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name=nil then
  begin
    RegisterGraphParameters(OpenSettings);
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,GraphEffectName,'SYNC',
      'グラフ / 棒・折れ線・円・レーダーチャート v0.2',ProcessVideo,nil);
  end;
  Result:=@GTable;
end;
end.
