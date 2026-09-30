unit GraphEditState;

// 編集開始時・最後の有効状態・配置Undoを分けて保持する。画面部品は参照しない。
interface
uses System.Types, GraphModel;
type
  TGraphEditState=class
  private
    FInitialSettings,FValidSettings:string;
    FInitialShared,FValidShared:TGraphShared;
    FUndoLayout:Integer;
    FUndoOffsets:TArray<TPointF>;
    FUndoAvailable,FClosedWithError:Boolean;
  public
    procedure Initialize(Doc:TGraphDocument; const Shared:TGraphShared);
    procedure MarkValid(Doc:TGraphDocument; const Shared:TGraphShared);
    procedure CaptureNameLayout(Doc:TGraphDocument);
    procedure UndoNameLayout(Doc:TGraphDocument);
    function RestoreInitial:TGraphDocument;
    function AcceptedSettings(Doc:TGraphDocument):string;
    function AcceptedShared(const Current:TGraphShared):TGraphShared;
    property InitialShared:TGraphShared read FInitialShared;
    property ValidSettings:string read FValidSettings;
    property ValidShared:TGraphShared read FValidShared;
    property UndoAvailable:Boolean read FUndoAvailable;
    property ClosedWithError:Boolean read FClosedWithError write FClosedWithError;
  end;
implementation
uses System.Math, GraphSettings;
procedure TGraphEditState.Initialize(Doc:TGraphDocument; const Shared:TGraphShared);
begin
  FInitialSettings:=SaveGraph(Doc); FInitialShared:=Shared;
  FValidSettings:=FInitialSettings; FValidShared:=Shared;
  FUndoAvailable:=False; FUndoOffsets:=nil; FClosedWithError:=False;
end;
procedure TGraphEditState.MarkValid(Doc:TGraphDocument; const Shared:TGraphShared);
begin
  // 描画に成功した時点でだけ更新し、不正な途中入力で採用状態を上書きしない。
  FValidSettings:=SaveGraph(Doc); FValidShared:=Shared;
end;
procedure TGraphEditState.CaptureNameLayout(Doc:TGraphDocument);
var I:Integer;
begin
  FUndoLayout:=Doc.NameLayout; SetLength(FUndoOffsets,Doc.Rows);
  for I:=0 to High(FUndoOffsets) do FUndoOffsets[I]:=Doc.Offsets[I+2];
  FUndoAvailable:=True;
end;
procedure TGraphEditState.UndoNameLayout(Doc:TGraphDocument);
var I:Integer;
begin
  if not FUndoAvailable then Exit;
  Doc.NameLayout:=FUndoLayout;
  // 記録後に要素数が変わっても、現在の要素に存在する補正だけを復元する。
  for I:=0 to Min(High(FUndoOffsets),Doc.Rows-1) do Doc.Offsets[I+2]:=FUndoOffsets[I];
  FUndoAvailable:=False;
end;
function TGraphEditState.RestoreInitial:TGraphDocument;
begin
  // 返す文書は呼出側が所有する。現在の文書の解放・UI再接続はフォームの責務。
  Result:=LoadGraph(FInitialSettings); FUndoAvailable:=False;
end;
function TGraphEditState.AcceptedSettings(Doc:TGraphDocument):string;
begin
  if FClosedWithError then Result:=FValidSettings else Result:=SaveGraph(Doc);
end;
function TGraphEditState.AcceptedShared(const Current:TGraphShared):TGraphShared;
begin
  if FClosedWithError then Result:=FValidShared else Result:=Current;
end;
end.
