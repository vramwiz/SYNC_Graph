unit GraphAnimation;

// ホストの進行値からセル単位の登場順と見た目を計算する。時刻履歴を持たない。
interface

type
  TGraphAnimation = record
    TransitionMode, GraphMode: Integer;
    Progress, ZoomPercent: Double;
    function CellProgress(Row,Column,Rows,Columns:Integer):Single;
    function ShapeProgress(Row,Column,Rows,Columns:Integer):Single;
    function CellOpacity(Row,Column,Rows,Columns:Integer):Single;
    function ZoomScale:Single;
    procedure ActiveCell(Rows,Columns:Integer; out Row,Column:Integer);
  end;

implementation

uses System.Math;

function TGraphAnimation.CellProgress(Row,Column,Rows,Columns:Integer):Single;
var Rank,Span,Total:Integer; Position:Double;
begin
  if (Rows<=0) or (Columns<=0) then Exit(0);
  Total:=Rows*Columns*100;
  case TransitionMode of
    0: Exit(1);
    1: begin Span:=Rows*100; Rank:=Column; end;
    2: begin Span:=Columns*100; Rank:=Row; end;
    3: begin Span:=100; Rank:=Column*Rows+Row; end;
    4: begin Span:=100; Rank:=Row*Columns+Column; end;
  else Exit(1);
  end;
  // どの推移方法でも終点は同じ。まとめて表示する組はセル数分の幅を共有する。
  Position:=EnsureRange(Progress,0.0,Double(Total));
  Result:=EnsureRange((Position-Rank*Span)/Span,0.0,1.0);
end;

function TGraphAnimation.ShapeProgress(Row,Column,Rows,Columns:Integer):Single;
begin
  if GraphMode=2 then Result:=CellProgress(Row,Column,Rows,Columns)
  else Result:=1;
end;

function TGraphAnimation.CellOpacity(Row,Column,Rows,Columns:Integer):Single;
var F:Single;
begin
  if GraphMode=0 then Exit(1);
  F:=CellProgress(Row,Column,Rows,Columns);
  if GraphMode=1 then Result:=F
  else Result:=Min(1,F/0.15);
end;

function TGraphAnimation.ZoomScale:Single;
begin Result:=EnsureRange(ZoomPercent,100.0,300.0)/100; end;

procedure TGraphAnimation.ActiveCell(Rows,Columns:Integer;
  out Row,Column:Integer);
var Rank,Count,Span,Total:Integer;
begin
  Row:=0; Column:=0;
  if (Rows<=0) or (Columns<=0) then Exit;
  Total:=Rows*Columns*100;
  case TransitionMode of
    1:begin Count:=Columns; Span:=Rows*100; end;
    2:begin Count:=Rows; Span:=Columns*100; end;
    3,4:begin Count:=Rows*Columns; Span:=100; end;
  else Exit;
  end;
  Rank:=EnsureRange(Trunc(EnsureRange(Progress,0.0,Double(Total))/Span),0,Count-1);
  case TransitionMode of
    1:Column:=Rank;
    2:Row:=Rank;
    3:begin Row:=Rank mod Rows; Column:=Rank div Rows; end;
    4:begin Row:=Rank div Columns; Column:=Rank mod Columns; end;
  end;
end;

end.
