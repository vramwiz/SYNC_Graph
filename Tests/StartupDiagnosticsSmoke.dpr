program StartupDiagnosticsSmoke;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, Winapi.Windows;
type
  TRunProbe=procedure(Scoped:Byte); cdecl;
  TFaultAddress=function:Pointer; cdecl;
var Root,OriginalAppData,Log,Text,BlockedRoot:string;
  Logs:TArray<string>; Lib:HMODULE; RunProbe:TRunProbe; FaultAddress:TFaultAddress;
  Address:NativeUInt;
procedure Check(Condition:Boolean; const Message:string);
begin
  if not Condition then raise Exception.Create(Message);
  Writeln('PASS ',Message);
end;
function ReadLog(const Path:string):string;
var Reader:TStreamReader;
begin
  Reader:=TStreamReader.Create(TFileStream.Create(Path,fmOpenRead or fmShareDenyNone),
    TEncoding.UTF8,True,4096);
  Reader.OwnStream;
  try Result:=Reader.ReadToEnd; finally Reader.Free; end;
end;
procedure LoadFixture;
begin
  Lib:=LoadLibrary(PChar(TPath.Combine(ExtractFilePath(ParamStr(0)),'StartupDiagnosticsFixture.dll')));
  if Lib=0 then RaiseLastOSError;
  RunProbe:=TRunProbe(GetProcAddress(Lib,'RunProbe'));
  FaultAddress:=TFaultAddress(GetProcAddress(Lib,'FaultAddress'));
  Check(Assigned(RunProbe) and Assigned(FaultAddress),'fixture exports');
end;
begin
  OriginalAppData:=GetEnvironmentVariable('LOCALAPPDATA');
  Root:=TPath.Combine(TPath.GetTempPath,'SYNC_Graph_Diagnostics_'+IntToStr(GetCurrentProcessId)+
    '_'+IntToStr(GetTickCount64));
  try
    try
      SetEnvironmentVariable('LOCALAPPDATA',PChar(Root));
      LoadFixture;
      try
        Address:=NativeUInt(FaultAddress());
        Check(Address<>0,'unit initialization access violation still reaches Delphi handler');
        Logs:=TDirectory.GetFiles(TPath.Combine(Root,'SYNC_Graph\Diagnostics'),'startup-*.log');
        Check(Length(Logs)=1,'one log per DLL load');
        Log:=Logs[0]; Text:=ReadLog(Log);
        Check(Text.Contains('first-chance access violation') and
          Text.Contains('StartupDiagnosticsFixture.dll') and
          Text.Contains('address=0x'+IntToHex(Address,16)) and
          Text.Contains('rva=0x'+IntToHex(Address-NativeUInt(Lib),16)) and
          Text.Contains('target=0x0000000000000000'),
          'initialization log records real module, address, RVA and null target');
        RunProbe(0);
        Check(ReadLog(Log)=Text,'exceptions outside startup are not recorded');
        RunProbe(1);
        Text:=ReadLog(Log);
        Check(Text.Contains('test startup callback begin') and
          Text.Contains('test startup callback end'),'startup callback scope is logged');
        Check(Length(Text.Split(['first-chance access violation']))=3,
          'only initialization and scoped access violations are observed');
      finally FreeLibrary(Lib); end;
      LoadFixture;
      try Check(FaultAddress()<>nil,'reload after observer removal');
      finally FreeLibrary(Lib); end;
      BlockedRoot:=TPath.Combine(Root,'unwritable-root');
      TFile.WriteAllText(BlockedRoot,'file blocks directory creation');
      SetEnvironmentVariable('LOCALAPPDATA',PChar(BlockedRoot));
      LoadFixture;
      try
        RunProbe(1);
        Check(FaultAddress()<>nil,'unavailable log directory does not prevent startup or exception handling');
      finally FreeLibrary(Lib); end;
    finally SetEnvironmentVariable('LOCALAPPDATA',PChar(OriginalAppData)); end;
  except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
