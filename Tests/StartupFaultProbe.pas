unit StartupFaultProbe;

// DLL本体のbeginより前に本物のアクセス違反を発生させ、既存の例外処理で回復する。
interface
procedure ProbeAccessViolation;
function ProbeFaultAddress:Pointer;
implementation
uses System.SysUtils;
var LastAddress:Pointer;
procedure ProbeAccessViolation;
var Target:PByte;
begin
  Target:=nil;
  try
    Target^:=42;
    raise Exception.Create('Fault injection did not fault');
  except
    on E:EAccessViolation do LastAddress:=ExceptAddr;
  end;
end;
function ProbeFaultAddress:Pointer;
begin Result:=LastAddress; end;
initialization
  ProbeAccessViolation;
end.
