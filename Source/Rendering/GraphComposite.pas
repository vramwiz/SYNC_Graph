unit GraphComposite;

// 非乗算RGBA同士のsource-over合成。編集用黒背景はここには含めない。
interface
uses System.SysUtils;
procedure CompositeRgba(var Background:TBytes; const Foreground:TBytes);
implementation
procedure CompositeRgba(var Background:TBytes; const Foreground:TBytes);
var I,C,A,B,OutA:Integer;
begin
  if Length(Foreground)=0 then Exit;
  if Length(Background)<>Length(Foreground) then
    raise EArgumentException.Create('合成画像のサイズが一致しません。');
  I:=0;
  while I<Length(Background) do
  begin
    A:=Foreground[I+3]; B:=Background[I+3]; OutA:=A*255+B*(255-A);
    if OutA>0 then
      for C:=0 to 2 do
        Background[I+C]:=(Foreground[I+C]*A*255+Background[I+C]*B*(255-A)+OutA div 2) div OutA;
    Background[I+3]:=(OutA+127) div 255;
    Inc(I,4);
  end;
end;
end.
