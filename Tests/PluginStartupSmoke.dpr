program PluginStartupSmoke;
{$APPTYPE CONSOLE}

// Skiaをリンクしない人工ホストで、単独ロードと同梱DLL欠落を検証する。
uses System.SysUtils, Winapi.Windows;
type
  TInitialize=function(Version:Cardinal):Byte; cdecl;
  TFinalize=procedure; cdecl;
  TGetTable=function:Pointer; cdecl;
var Lib:HMODULE; Init:TInitialize; Done:TFinalize; GetTable:TGetTable;
  ExpectFailure:Boolean; Cycle:Integer;
procedure Check(Condition:Boolean; const Message:string);
begin
  if not Condition then raise Exception.Create(Message);
  Writeln('PASS ',Message); Flush(Output);
end;
begin
  try
    Check(ParamCount>=1,'plugin path supplied');
    ExpectFailure:=(ParamCount=2) and SameText(ParamStr(2),'expect-failure');
    Check(GetModuleHandle('sk4d.dll')=0,'Skia is absent before plugin load');
    Lib:=LoadLibrary(PChar(ParamStr(1)));
    if Lib=0 then RaiseLastOSError;
    try
      Check(GetModuleHandle('sk4d.dll')=0,'LoadLibrary does not initialize Skia');
      Init:=TInitialize(GetProcAddress(Lib,'InitializePlugin'));
      Done:=TFinalize(GetProcAddress(Lib,'UninitializePlugin'));
      GetTable:=TGetTable(GetProcAddress(Lib,'GetFilterPluginTable'));
      Check(Assigned(Init) and Assigned(Done) and Assigned(GetTable),'startup exports');
      Check(GetTable()<>nil,'table can be requested before initialization');
      Check(GetModuleHandle('sk4d.dll')=0,'table registration does not initialize Skia');
      for Cycle:=1 to 2 do
      begin
        if ExpectFailure then
        begin
          Check(Init(0)=0,'missing bundled runtime returns failure without escaping the ABI');
          Done;
        end
        else
        begin
          Check(Init(0)=1,'explicit plugin initialization succeeds');
          try
            Check(GetModuleHandle('sk4d.dll')<>0,'Skia is loaded by InitializePlugin');
            Check(Init(0)=1,'repeated initialization is idempotent');
          finally Done; end;
          Done;
        end;
        Check(GetModuleHandle('sk4d.dll')=0,'Skia references are released before DLL unload');
      end;
    finally FreeLibrary(Lib); end;
    Writeln('PLUGIN_STARTUP_OK');
  except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
