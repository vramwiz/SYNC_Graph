library StartupDiagnosticsFixture;
uses GraphStartupDiagnostics, StartupFaultProbe;
procedure RunProbe(Scoped:Byte); cdecl;
begin
  if Scoped<>0 then EnterGraphStartup('test startup callback');
  try ProbeAccessViolation;
  finally if Scoped<>0 then LeaveGraphStartup('test startup callback'); end;
end;
function FaultAddress:Pointer; cdecl;
begin Result:=ProbeFaultAddress; end;
exports RunProbe, FaultAddress;
begin
  CompleteGraphLibraryStartup;
end.
