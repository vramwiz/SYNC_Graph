unit GraphDataPanel;

// ホストが正本となる文字・値の編集。行ごとの値はカンマ区切りで保持する。
interface
uses System.Classes, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Grids, GraphModel;
type
  TGraphDataPanel=class(TPanel)
  private
    FTitle,FUnit:TEdit;
    FGrid:TStringGrid;
    FChanging:Boolean;
    FNamesCache,FValuesCache:TArray<string>;
    FColumns:Integer;
    FOnChange:TNotifyEvent;
    procedure Changed(Sender:TObject);
    procedure CellChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
  public
    constructor Create(AOwner:TComponent); override;
    procedure ClearCache;
    procedure Load(const Shared:TGraphShared; Doc:TGraphDocument);
    function ReadShared:TGraphShared;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses Vcl.Controls, System.SysUtils, GraphValues, DarkEditorTheme;

constructor TGraphDataPanel.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited;
  // ネイティブ入力部品のハンドル生成前に親ウィンドウを確定する。
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=450; Height:=600; BevelOuter:=bvNone;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='表題'; L.SetBounds(12,12,80,24);
  FTitle:=TEdit.Create(Self); FTitle.Parent:=Self; FTitle.SetBounds(12,40,426,32);
  FTitle.Anchors:=[akLeft,akTop,akRight]; FTitle.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='単位'; L.SetBounds(12,84,80,24);
  FUnit:=TEdit.Create(Self); FUnit.Parent:=Self; FUnit.SetBounds(12,112,426,32);
  FUnit.Anchors:=[akLeft,akTop,akRight]; FUnit.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self;
  L.Caption:='各行の値はカンマ区切り。空欄の数値は0。'; L.SetBounds(12,156,426,24);
  FGrid:=TStringGrid.Create(Self); FGrid.Parent:=Self;
  FGrid.SetBounds(12,192,426,392); FGrid.Anchors:=[akLeft,akTop,akRight,akBottom];
  FGrid.ColCount:=2; FGrid.FixedCols:=0; FGrid.RowCount:=4;
  SetupEditorGrid(FGrid,140);
  FGrid.Options:=FGrid.Options+[goEditing,goTabs]; FGrid.OnSetEditText:=CellChanged;
end;

procedure TGraphDataPanel.Changed(Sender:TObject);
begin if not FChanging and Assigned(FOnChange) then FOnChange(Self); end;
procedure TGraphDataPanel.CellChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
begin Changed(Sender); end;

procedure TGraphDataPanel.ClearCache;
begin FNamesCache:=nil; FValuesCache:=nil; end;

procedure TGraphDataPanel.Load(const Shared:TGraphShared; Doc:TGraphDocument);
var I,C:Integer; Values,Names,Cells,Incoming:TArray<string>; VisibleValue:string;
begin
  FChanging:=True;
  try
    FTitle.Text:=Shared.Title; FUnit.Text:=Shared.Units;
    FColumns:=Doc.Columns;
    FGrid.RowCount:=Doc.Rows+1; FGrid.Cells[0,0]:='要素名';
    if Doc.Kind=gkRadar then FGrid.Cells[1,0]:='系列ごとの値'
    else FGrid.Cells[1,0]:='値';
    Values:=SplitRows(Shared.Values);
    Names:=SplitRows(Shared.Names);
    if Length(FValuesCache)<Length(Values) then SetLength(FValuesCache,Length(Values));
    if Length(FNamesCache)<Length(Names) then SetLength(FNamesCache,Length(Names));
    for I:=0 to High(Values) do
    begin
      Cells:=FValuesCache[I].Split([',']); Incoming:=Values[I].Split([',']);
      if Length(Cells)<Length(Incoming) then SetLength(Cells,Length(Incoming));
      for C:=0 to High(Incoming) do Cells[C]:=Incoming[C];
      FValuesCache[I]:=string.Join(',',Cells);
    end;
    for I:=0 to High(Names) do FNamesCache[I]:=Names[I];
    for I:=0 to Doc.Rows-1 do
    begin
      if I<Length(FNamesCache) then FGrid.Cells[0,I+1]:=FNamesCache[I]
      else FGrid.Cells[0,I+1]:='要素'+IntToStr(I+1);
      VisibleValue:=''; Cells:=nil;
      if I<Length(FValuesCache) then Cells:=FValuesCache[I].Split([',']);
      for C:=0 to FColumns-1 do
      begin
        if C>0 then VisibleValue:=VisibleValue+',';
        if C<Length(Cells) then VisibleValue:=VisibleValue+Cells[C]
        else VisibleValue:=VisibleValue+'0';
      end;
      FGrid.Cells[1,I+1]:=VisibleValue;
    end;
  finally FChanging:=False; end;
end;

function TGraphDataPanel.ReadShared:TGraphShared;
var I,C:Integer; OldCells,NewCells:TArray<string>;
begin
  Result.Title:=FTitle.Text; Result.Units:=FUnit.Text;
  Result.Names:=''; Result.Values:='';
  if Length(FNamesCache)<FGrid.RowCount-1 then SetLength(FNamesCache,FGrid.RowCount-1);
  if Length(FValuesCache)<FGrid.RowCount-1 then SetLength(FValuesCache,FGrid.RowCount-1);
  for I:=1 to FGrid.RowCount-1 do
  begin
    if I>1 then begin Result.Names:=Result.Names+#13#10; Result.Values:=Result.Values+#13#10; end;
    Result.Names:=Result.Names+FGrid.Cells[0,I];
    Result.Values:=Result.Values+FGrid.Cells[1,I];
    // 構造を縮小してから戻す間は、隠れた行列を編集セッション内で保持する。
    FNamesCache[I-1]:=FGrid.Cells[0,I];
    OldCells:=FValuesCache[I-1].Split([',']); NewCells:=FGrid.Cells[1,I].Split([',']);
    if Length(OldCells)<Length(NewCells) then SetLength(OldCells,Length(NewCells));
    for C:=0 to High(NewCells) do OldCells[C]:=NewCells[C];
    FValuesCache[I-1]:=string.Join(',',OldCells);
  end;
end;
end.
