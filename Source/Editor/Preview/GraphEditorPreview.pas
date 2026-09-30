unit GraphEditorPreview;

// 編集背景の所有・透過グラフとの合成・文字ドラッグ用レイヤーを担当する。
interface
uses System.SysUtils, GraphModel, GraphView;
type
  TGraphEditorPreview=class
  private
    FBackground:TBytes;
    FWidth,FHeight:Integer;
  public
    procedure Initialize(const Pixels:TBytes; Width,Height:Integer);
    procedure Draw(Doc:TGraphDocument; const Shared:TGraphShared; View:TGraphView);
    procedure PrepareLabel(Doc:TGraphDocument; const Shared:TGraphShared; View:TGraphView);
    property Width:Integer read FWidth;
    property Height:Integer read FHeight;
  end;
implementation
uses GraphAnimation, GraphRenderer, GraphPainter, GraphComposite;
procedure TGraphEditorPreview.Initialize(const Pixels:TBytes; Width,Height:Integer);
begin
  FWidth:=Width; FHeight:=Height;
  if (FWidth<=0) or (FHeight<=0) then begin FWidth:=1920; FHeight:=1080; end;
  if Int64(FWidth)*FHeight>33554432 then raise EArgumentException.Create('編集画像のサイズが大きすぎます。');
  // ホスト由来の非乗算RGBAを所有配列へコピーする。借用ポインターは保持しない。
  FBackground:=Copy(Pixels);
  if Length(FBackground)<>Int64(FWidth)*FHeight*4 then
    SetLength(FBackground,NativeInt(FWidth)*FHeight*4);
end;
procedure TGraphEditorPreview.Draw(Doc:TGraphDocument; const Shared:TGraphShared; View:TGraphView);
var Output,Image:TBytes; Labels:TArray<TGraphLabel>; Animation:TGraphAnimation;
begin
  Animation:=Default(TGraphAnimation);
  Output:=RenderGraph(Doc,Shared,Animation,FWidth,FHeight,Labels);
  Image:=Copy(FBackground); CompositeRgba(Image,Output);
  View.SetRgba(Image,FWidth,FHeight); View.Bind(Doc,Labels);
  // View側のキャッシュが必要な画像を保持する。ローカル配列はこの呼出しまで有効。
  View.CachePreview(FBackground,Output,FWidth,FHeight);
end;
procedure TGraphEditorPreview.PrepareLabel(Doc:TGraphDocument; const Shared:TGraphShared; View:TGraphView);
var Base,TextLayer:TBytes; Labels:TArray<TGraphLabel>; Animation:TGraphAnimation;
begin
  Animation:=Default(TGraphAnimation);
  // 対象文字だけを分離し、ドラッグ中は背景と残りのグラフを再描画せず合成する。
  Base:=RenderGraph(Doc,Shared,Animation,FWidth,FHeight,Labels,-1,View.ActiveLabelID);
  TextLayer:=RenderGraph(Doc,Shared,Animation,FWidth,FHeight,Labels,View.ActiveLabelID);
  View.CacheLabelPreview(FBackground,Base,TextLayer,FWidth,FHeight);
end;
end.
