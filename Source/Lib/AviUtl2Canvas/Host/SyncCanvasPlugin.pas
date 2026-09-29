unit SyncCanvasPlugin;

// Host boundary: capture per object/effect, edit snapshot, persist JSON through AviUtl2.
interface

uses AviUtl2FilterTypes;

procedure InitializeCanvasPlugin;
procedure FinalizeCanvasPlugin;
function CanvasPluginTable: PFILTER_PLUGIN_TABLE;

implementation

uses System.SysUtils, Winapi.Windows, Vcl.Forms, SyncCanvasEditor,
  PluginFilterTable, PluginFilterContextManager, SyncFrameCapture;

const
  EffectName = 'グラフ';
  DataName = '設定データ';

type
  TCaptureContext = class(TPluginFilterContextItem)
  public
    Capture: TSyncFrameCapture;
    constructor Create;
    destructor Destroy; override;
  end;
  TCaptureContexts = class(TPluginFilterContextList<TCaptureContext>);

var
  Contexts: TCaptureContexts;
  SettingsButton: TFILTER_ITEM_BUTTON;
  SettingsData: TFILTER_ITEM_STRING;

constructor TCaptureContext.Create;
begin
  inherited;
  Capture := TSyncFrameCapture.Create;
end;

destructor TCaptureContext.Destroy;
begin
  Capture.Free;
  inherited;
end;

procedure InitializeCanvasPlugin;
begin
  if Contexts = nil then Contexts := TCaptureContexts.Create;
end;

procedure FinalizeCanvasPlugin;
begin
  FreeAndNil(Contexts);
end;

function CaptureVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var Context: TCaptureContext;
begin
  Result := 1;
  try
    if Contexts = nil then Exit;
    Context := Contexts.GetContext(Video);
    if Context <> nil then Context.Capture.Capture(Video);
    // Do not call SetImageData: this test leaves the host video unchanged.
  except
    on E: Exception do OutputDebugString(PChar('Canvas capture: '+E.Message));
  end;
end;

procedure OpenSettings(Edit: PEDIT_SECTION); cdecl;
var Obj: OBJECT_HANDLE; Location: TOBJECT_LAYER_FRAME; Context: TCaptureContext;
  Data: PAnsiChar; Current: string; Updated: UTF8String;
  Pixels: TBytes; Width, Height: Integer; Status: string;
  Form: TSyncCanvasEditor; PreviousDpi: DPI_AWARENESS_CONTEXT;
begin
  try
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
      not Assigned(Edit^.GetObjectLayerFrame) or not Assigned(Edit^.GetObjectItemValue) or
      not Assigned(Edit^.SetObjectItemValue) then
      raise EInvalidOp.Create('編集APIを取得できません。');
    Obj := Edit^.GetFocusObject();
    if Obj = nil then raise EInvalidOp.Create('編集対象がありません。');
    Data := Edit^.GetObjectItemValue(Obj, EffectName, DataName);
    if Data = nil then Current := '' else Current := string(UTF8String(Data));
    Location := Edit^.GetObjectLayerFrame(Obj);
    Pixels := nil;
    Width := 0;
    Height := 0;
    Status := '背景が未取得、または対象の効果を一意に識別できません。';
    if Contexts <> nil then
    begin
      Context := Contexts.FindByObjectLocation(Location.Layer, Location.StartFrame, Location.EndFrame);
      if Context <> nil then Context.Capture.CopyRgba(Pixels, Width, Height, Status);
    end;
    PreviousDpi := SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    try
      Form := TSyncCanvasEditor.Create(nil);
      try
        Form.LoadSnapshot(Pixels, Width, Height, Current, Status);
        Form.ShowModal;
        Updated := UTF8String(Form.SaveData);
      finally
        Form.Free;
      end;
    finally
      if IsValidDpiAwarenessContext(PreviousDpi) then SetThreadDpiAwarenessContext(PreviousDpi);
    end;
    if not Edit^.SetObjectItemValue(Obj, EffectName, DataName, PAnsiChar(Updated)) then
      raise EInvalidOp.Create('設定データを保存できませんでした。');
  except
    on E: Exception do MessageBox(0, PChar(E.Message), 'SYNC グラフ', MB_OK or MB_ICONERROR);
  end;
end;

function CanvasPluginTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
  begin
    AddButton(SettingsButton, '設定', OpenSettings);
    AddString(SettingsData, DataName, '');
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER, EffectName, 'SYNC',
      'グラフ設定・背景キャンバス v1.0', CaptureVideo, nil);
  end;
  Result := @GTable;
end;

end.
