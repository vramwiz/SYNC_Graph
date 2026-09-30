unit GraphRenderContext;

// オブジェクト・効果別の背景と描画キャッシュ。映像側からVCLを参照しない。
interface
uses System.SysUtils, System.SyncObjs, AviUtl2FilterTypes, PluginFilterContextManager,
  GraphModel;
type
  TGraphRenderContext=class(TPluginFilterContextItem)
  private
    FLock:TCriticalSection;
    FKey:string;
    FImage,FBackground:TBytes;
    FWidth,FHeight:Integer;
  public
    function CopyBackground(out Pixels:TBytes; out W,H:Integer; out Status:string):Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Process(Video:PFILTER_PROC_VIDEO);
  end;
implementation
uses GraphHostParameters, GraphSettings, GraphRenderer, GraphPainter,
  GraphAnimation, GraphComposite;
constructor TGraphRenderContext.Create;
begin inherited; FLock:=TCriticalSection.Create; end;
destructor TGraphRenderContext.Destroy;
begin FLock.Free; inherited; end;
function TGraphRenderContext.CopyBackground(out Pixels:TBytes; out W,H:Integer;
  out Status:string):Boolean;
begin
  FLock.Acquire;
  try
    Pixels:=Copy(FBackground); W:=FWidth; H:=FHeight;
    Result:=Length(Pixels)>0; Status:='';
  finally FLock.Release; end;
end;
procedure TGraphRenderContext.Process(Video:PFILTER_PROC_VIDEO);
var Doc:TGraphDocument; S:TGraphShared; A:TGraphAnimation; Settings,Key:string;
  W,H:Integer; Buffer,Image:TBytes; Labels:TArray<TGraphLabel>;
begin
  if (Video=nil) or (Video^.Scene=nil) or (Video^.Object_=nil) then Exit;
  Settings:=CurrentSettings; S:=CurrentShared; A:=CurrentAnimation;
  W:=Video^.Object_^.Width; H:=Video^.Object_^.Height;
  if (W<=0) or (H<=0) then Exit;
  if (Int64(W)*H>33554432) or not Assigned(Video^.GetImageData) or
    not Assigned(Video^.SetImageData) then Exit;
  // ホストのGPUコンテキストを直接操作せず、入力RGBAを所有配列へ取得する。
  // ホスト関数はロック外で呼び、ホスト側の待機とロック順序が交差するのを避ける。
  SetLength(Buffer,NativeInt(W)*H*4);
  Video^.GetImageData(@Buffer[0]);
  FLock.Acquire;
  try
    FBackground:=Copy(Buffer); FWidth:=W; FHeight:=H;
    // 長さを含む区切りで、ユーザー文字列に区切り文字があっても衝突させない。
    Key:=IntToStr(Length(Settings))+':'+Settings+IntToStr(Length(S.Title))+':'+S.Title+
      IntToStr(Length(S.Names))+':'+S.Names+IntToStr(Length(S.Units))+':'+S.Units+
      IntToStr(Length(S.Values))+':'+S.Values+
      Format('|%d,%d,%d,%d|',[W,H,A.TransitionMode,A.GraphMode])+
      FloatToStr(A.Progress,TFormatSettings.Invariant)+'|'+
      FloatToStr(A.ZoomPercent,TFormatSettings.Invariant);
    if Key<>FKey then
    begin
      Doc:=LoadGraph(Settings);
      try
        if (Doc.Bounds.Width=0) or (Doc.Bounds.Height=0) then Doc.ResetBounds(W,H);
        FImage:=RenderGraph(Doc,S,A,W,H,Labels);
        FKey:=Key;
      finally Doc.Free; end;
    end;
    // 参照を保持し、別フレームのキャッシュ更新後も画像を有効にする。
    Image:=FImage;
  finally FLock.Release; end;
  if Length(Image)=0 then Exit;
  CompositeRgba(Buffer,Image);
  Video^.SetImageData(@Buffer[0],W,H);
end;
end.
