unit GraphAnimation;

// ホストのフレーム時刻と進行値から演出を計算する。逆再生でも履歴に依存しない。
interface
type
  TGraphAnimation = record
    EnterMode, ExitMode, ElementMode: Integer;
    EnterSeconds, ExitSeconds, Progress, Time, Duration: Double;
    function Opacity: Single;
    function Element(Index: Integer): Single;
  end;
implementation
uses System.Math;
function TGraphAnimation.Opacity:Single;
begin
  Result:=1;
  if (EnterMode<>0) and (EnterSeconds>0) then
    Result:=Result*EnsureRange(Time/EnterSeconds,0.0,1.0);
  if (ExitMode<>0) and (ExitSeconds>0) then
    Result:=Result*EnsureRange((Duration-Time)/ExitSeconds,0.0,1.0);
end;
function TGraphAnimation.Element(Index:Integer):Single;
begin
  if ElementMode=0 then Result:=1
  else Result:=EnsureRange(Progress/100-Index,0.0,1.0);
end;
end.
