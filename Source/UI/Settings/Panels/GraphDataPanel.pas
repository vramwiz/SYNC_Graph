unit GraphDataPanel;

// ホストが正本の表題・単位・要素名・値を、行ごとの入力欄として編集する。
interface
uses System.Classes, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Controls, GraphModel;
type
  TGraphDataPanel=class(TPanel)
  private
    FTitle,FUnit:TEdit;
    FRowNames,FRowValues:TArray<TEdit>;
    FRowLabels:TArray<TLabel>;
    FChanging:Boolean;
    FNamesCache,FValuesCache:TArray<string>;
    FColumns:Integer;
    FOnChange:TNotifyEvent;
    procedure Changed(Sender:TObject);
    procedure RowKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure SetRowCount(Count:Integer);
  public
    constructor Create(AOwner:TComponent); override;
    procedure ClearCache;
    procedure Load(const Shared:TGraphShared; Doc:TGraphDocument);
    function ReadShared:TGraphShared;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses System.SysUtils, System.Math, Winapi.Windows, GraphValues;

constructor TGraphDataPanel.Create(AOwner:TComponent);
var L:TLabel;
  function S(Value:Integer):Integer;
  begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  inherited;
  if AOwner is TWinControl then Parent:=TWinControl(AOwner);
  Width:=S(290); Height:=S(280); BevelOuter:=bvNone; Color:=$00303030;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='文字・値'; L.SetBounds(S(12),S(8),S(300),S(24));
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='表題'; L.SetBounds(S(12),S(40),S(80),S(24));
  FTitle:=TEdit.Create(Self); FTitle.Parent:=Self; FTitle.SetBounds(S(12),S(66),S(272),S(30));
  FTitle.StyleElements:=[];
  FTitle.Color:=$00303030; FTitle.Font.Color:=$00EEEEEE; FTitle.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='単位'; L.SetBounds(S(12),S(106),S(80),S(24));
  FUnit:=TEdit.Create(Self); FUnit.Parent:=Self; FUnit.SetBounds(S(12),S(132),S(272),S(30));
  FUnit.StyleElements:=[];
  FUnit.Color:=$00303030; FUnit.Font.Color:=$00EEEEEE; FUnit.OnChange:=Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='要素名'; L.SetBounds(S(40),S(176),S(90),S(22));
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='値（カンマ区切り）';
  L.SetBounds(S(138),S(176),S(146),S(22));
end;

procedure TGraphDataPanel.Changed(Sender:TObject);
begin if not FChanging and Assigned(FOnChange) then FOnChange(Self); end;

procedure TGraphDataPanel.SetRowCount(Count:Integer);
var I,Old:Integer;
  procedure Bounds(Control:TControl; X,Y,W,H:Integer);
  begin
    Control.SetBounds(MulDiv(X,CurrentPPI,96),MulDiv(Y,CurrentPPI,96),
      MulDiv(W,CurrentPPI,96),MulDiv(H,CurrentPPI,96));
  end;
begin
  Old:=Length(FRowNames);
  for I:=Count to Old-1 do
  begin
    FRowNames[I].Free; FRowValues[I].Free; FRowLabels[I].Free;
  end;
  SetLength(FRowNames,Count); SetLength(FRowValues,Count); SetLength(FRowLabels,Count);
  for I:=Old to Count-1 do
  begin
    FRowLabels[I]:=TLabel.Create(Self); FRowLabels[I].Parent:=Self;
    FRowNames[I]:=TEdit.Create(Self); FRowNames[I].Parent:=Self;
    FRowValues[I]:=TEdit.Create(Self); FRowValues[I].Parent:=Self;
    FRowNames[I].StyleElements:=[]; FRowValues[I].StyleElements:=[];
    FRowNames[I].Color:=$00303030; FRowNames[I].Font.Color:=$00EEEEEE;
    FRowValues[I].Color:=$00303030; FRowValues[I].Font.Color:=$00EEEEEE;
    FRowValues[I].Hint:='空欄は仮データを自動生成します。0はそのまま使用します。';
    FRowValues[I].ShowHint:=True;
    FRowNames[I].OnChange:=Changed; FRowValues[I].OnChange:=Changed;
    FRowNames[I].OnKeyDown:=RowKeyDown; FRowValues[I].OnKeyDown:=RowKeyDown;
  end;
  for I:=0 to Count-1 do
  begin
    FRowLabels[I].Caption:=IntToStr(I+1); Bounds(FRowLabels[I],12,204+I*40,26,26);
    Bounds(FRowNames[I],40,200+I*40,90,30);
    Bounds(FRowValues[I],138,200+I*40,146,30);
  end;
  Height:=MulDiv(Max(280,208+Count*40),CurrentPPI,96);
end;

procedure TGraphDataPanel.RowKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
var I:Integer; IsValue,Found:Boolean; Next:TEdit;
begin
  Next:=nil; IsValue:=False; Found:=False;
  for I:=0 to High(FRowNames) do
  begin
    if Sender=FRowNames[I] then begin Found:=True; Break; end;
    if Sender=FRowValues[I] then begin IsValue:=True; Found:=True; Break; end;
  end;
  if not Found then Exit;
  case Key of
    VK_UP:if I>0 then
      if IsValue then Next:=FRowValues[I-1] else Next:=FRowNames[I-1];
    VK_DOWN:if I<High(FRowNames) then
      if IsValue then Next:=FRowValues[I+1] else Next:=FRowNames[I+1];
    VK_LEFT:if TEdit(Sender).SelStart=0 then
      if IsValue then Next:=FRowNames[I]
      else if I>0 then Next:=FRowValues[I-1];
    VK_RIGHT:if TEdit(Sender).SelStart=Length(TEdit(Sender).Text) then
      if not IsValue then Next:=FRowValues[I]
      else if I<High(FRowNames) then Next:=FRowNames[I+1];
  end;
  if Next<>nil then
  begin
    Key:=0; Next.SetFocus;
    if (Sender=FRowValues[I]) and (Next=FRowNames[I]) then Next.SelStart:=Length(Next.Text)
    else Next.SelStart:=Min(TEdit(Sender).SelStart,Length(Next.Text));
  end;
end;

procedure TGraphDataPanel.ClearCache;
begin FNamesCache:=nil; FValuesCache:=nil; end;

procedure TGraphDataPanel.Load(const Shared:TGraphShared; Doc:TGraphDocument);
var I,C:Integer; Values,Names,Cells,Incoming:TArray<string>; VisibleValue:string;
begin
  FChanging:=True;
  try
    FTitle.Text:=Shared.Title; FUnit.Text:=Shared.Units;
    FColumns:=Doc.Columns;
    Values:=SplitRows(Shared.Values); Names:=SplitRows(Shared.Names);
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
    SetRowCount(Doc.Rows);
    for I:=0 to Doc.Rows-1 do
    begin
      if I<Length(FNamesCache) then FRowNames[I].Text:=FNamesCache[I]
      else FRowNames[I].Text:='要素'+IntToStr(I+1);
      VisibleValue:=''; Cells:=nil;
      if I<Length(FValuesCache) then Cells:=FValuesCache[I].Split([',']);
      // 増えたセルも未入力のまま表示・保存し、仮データを実際の0へ置き換えない。
      for C:=0 to FColumns-1 do
      begin
        if C>0 then VisibleValue:=VisibleValue+',';
        if C<Length(Cells) then VisibleValue:=VisibleValue+Cells[C];
      end;
      FRowValues[I].Text:=VisibleValue;
    end;
  finally FChanging:=False; end;
end;

function TGraphDataPanel.ReadShared:TGraphShared;
var I,C:Integer; OldCells,NewCells:TArray<string>; ValueText:string;
begin
  Result.Title:=FTitle.Text; Result.Units:=FUnit.Text;
  Result.Names:=''; Result.Values:='';
  if Length(FNamesCache)<Length(FRowNames) then SetLength(FNamesCache,Length(FRowNames));
  if Length(FValuesCache)<Length(FRowNames) then SetLength(FValuesCache,Length(FRowNames));
  for I:=0 to High(FRowNames) do
  begin
    if I>0 then begin Result.Names:=Result.Names+#13#10; Result.Values:=Result.Values+#13#10; end;
    Result.Names:=Result.Names+FRowNames[I].Text;
    Result.Values:=Result.Values+FRowValues[I].Text;
    // 構造の縮小・再拡大で隠れた列の入力を保持する。
    FNamesCache[I]:=FRowNames[I].Text;
    OldCells:=FValuesCache[I].Split([',']);
    ValueText:=FRowValues[I].Text; NewCells:=ValueText.Split([',']);
    if Length(OldCells)<Max(FColumns,Length(NewCells)) then
      SetLength(OldCells,Max(FColumns,Length(NewCells)));
    // 入力行を消した場合は表示中の全セルを空欄にする。縮小で隠れた列だけは
    // 保持し、再拡大時に消した値が意図せず復活するのを防ぐ。
    for C:=0 to Max(FColumns,Length(NewCells))-1 do
      if C<Length(NewCells) then OldCells[C]:=NewCells[C] else OldCells[C]:='';
    FValuesCache[I]:=string.Join(',',OldCells);
  end;
end;
end.
