unit GraphFloatState;

// Win64描画中だけ、呼出スレッドの浮動小数点例外をマスクする。
interface
function BeginGraphFloatScope:Cardinal;
procedure RestoreGraphFloatScope(State:Cardinal);
implementation

function BeginGraphFloatScope:Cardinal;
var Masked:Cardinal;
asm
  STMXCSR Masked
  MOV EAX,Masked
  MOV EDX,EAX
  OR EDX,$1F80
  AND EDX,$FFC0
  MOV Masked,EDX
  LDMXCSR Masked
end;

procedure RestoreGraphFloatScope(State:Cardinal);
asm
  // Win64の引数用領域へ置き、保留中の例外状態もそのまま戻す。
  // RTLのSetMXCSRは状態を消し、全スレッド共有のDefaultMXCSRも書き換えるため使わない。
  MOV [RSP+8],ECX
  LDMXCSR [RSP+8]
end;
end.
