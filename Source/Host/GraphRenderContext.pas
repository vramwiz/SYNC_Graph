unit GraphRenderContext;

// オブジェクト・効果別の背景と描画キャッシュ。映像側からVCLを参照しない。
interface
uses System.SysUtils, System.SyncObjs, AviUtl2FilterTypes, PluginFilterContextManager,
  SyncFrameCapture, GraphModel;
type
  TGraphRenderContext=class(TPluginFilterContextItem)
  private
    FLock:TCriticalSection;
    FKey:string;
    FImage:TBytes;
  public
    Capture:TSyncFrameCapture;
    constructor Create;
    destructor Destroy; override;
    procedure Process(Video:PFILTER_PROC_VIDEO);
  end;
implementation
uses GraphHostParameters, GraphSettings, GraphRenderer, GraphPainter,
  GraphAnimation, GraphComposite;
constructor TGraphRenderContext.Create;
begin inherited; FLock:=TCriticalSection.Create; Capture:=TSyncFrameCapture.Create; end;
destructor TGraphRenderContext.Destroy;
begin Capture.Free; FLock.Free; inherited; end;
procedure TGraphRenderContext.Process(Video:PFILTER_PROC_VIDEO);
var Doc:TGraphDocument; S:TGraphShared; A:TGraphAnimation; Settings,Key:string;
  W,H:Integer; Buffer:TBytes; Labels:TArray<TGraphLabel>;
begin
  if (Video=nil) or (Video^.Scene=nil) or (Video^.Object_=nil) then Exit;
  FLock.Acquire;
  try
    Capture.Capture(Video);
    Settings:=CurrentSettings; S:=CurrentShared; A:=CurrentAnimation;
    W:=Video^.Object_^.Width; H:=Video^.Object_^.Height;
    if (W<=0) or (H<=0) then begin W:=Video^.Scene^.Width; H:=Video^.Scene^.Height; end;
    if (W<=0) or (H<=0) or (Int64(W)*H>33554432) then Exit;
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
    if (Length(FImage)=0) or not Assigned(Video^.GetImageData) or not Assigned(Video^.SetImageData) then Exit;
    SetLength(Buffer,NativeInt(W)*H*4);
    Video^.GetImageData(@Buffer[0]); CompositeRgba(Buffer,FImage);
    Video^.SetImageData(@Buffer[0],W,H);
  finally FLock.Release; end;
end;
end.
