unit GraphStartupDiagnostics;

// Skia/VCLより先に起動し、DLL初期化中のアクセス違反を記録する。
// 例外は処理済みにせず、ホストとDelphi本来の例外処理へ渡す。
interface

uses System.SysUtils;

procedure EnterGraphStartup(const Stage:string);
procedure LeaveGraphStartup(const Stage:string);
procedure ReportGraphStartupError(const Stage:string; Error:Exception);
procedure ReportGraphSkiaRuntime(SkiaEntry:Pointer);
procedure CompleteGraphLibraryStartup;

implementation

uses Winapi.Windows;

type PStartupExceptionPointers=^Winapi.Windows.TExceptionPointers;
function AddVectoredExceptionHandler(First:ULONG; Handler:Pointer):Pointer; stdcall;
  external kernel32 name 'AddVectoredExceptionHandler';
function RemoveVectoredExceptionHandler(Handle:Pointer):ULONG; stdcall;
  external kernel32 name 'RemoveVectoredExceptionHandler';

var
  LogFile:THandle=INVALID_HANDLE_VALUE;
  ExceptionObserver:Pointer;
threadvar
  StartupDepth:Integer;
  WritingException:Boolean;

procedure WriteStartupLine(const Message:string);
var Bytes:UTF8String; Written:DWORD;
begin
  // 診断先の書込み失敗をプラグインの起動失敗にしない。
  try
    if LogFile=INVALID_HANDLE_VALUE then Exit;
    Bytes:=UTF8String(Format('[thread=%d] %s'#13#10,[GetCurrentThreadId,Message]));
    WriteFile(LogFile,Bytes[1],Length(Bytes),Written,nil);
  except
  end;
end;

procedure WriteModule(const Name:string; Module:HMODULE);
var Path:array[0..32767] of Char; Size:DWORD; FileName:string;
  Attributes:WIN32_FILE_ATTRIBUTE_DATA;
begin
  if Module=0 then
    WriteStartupLine(Name+': not loaded')
  else
  begin
    Size:=GetModuleFileName(Module,Path,Length(Path));
    SetString(FileName,PChar(@Path[0]),Size);
    WriteStartupLine(Name+': '+FileName+
      ' base=0x'+IntToHex(NativeUInt(Module),16));
    if GetFileAttributesEx(PChar(FileName),GetFileExInfoStandard,@Attributes) then
      WriteStartupLine(Name+' file: size=0x'+IntToHex(Attributes.nFileSizeHigh,8)+
        IntToHex(Attributes.nFileSizeLow,8)+' modified=0x'+
        IntToHex(Attributes.ftLastWriteTime.dwHighDateTime,8)+
        IntToHex(Attributes.ftLastWriteTime.dwLowDateTime,8));
  end;
end;

function ObserveStartupException(Info:PStartupExceptionPointers):Longint; stdcall;
const Digits:PWideChar='0123456789ABCDEF';
var
  Line:array[0..2047] of WideChar;
  Bytes:array[0..8191] of AnsiChar;
  Path:array[0..1023] of WideChar;
  Memory:MEMORY_BASIC_INFORMATION;
  Used,ByteCount,I:Integer;
  Written,PreviousError:DWORD;
  Address:NativeUInt;
  procedure Append(Value:PWideChar);
  begin
    while (Value^<>#0) and (Used<High(Line)) do
    begin Line[Used]:=Value^; Inc(Used); Inc(Value); end;
  end;
  procedure Hex(Value:UInt64);
  var Shift:Integer;
  begin
    Append('0x');
    for Shift:=15 downto 0 do
      if Used<High(Line) then
      begin Line[Used]:=Digits[(Value shr (Shift*4)) and $F]; Inc(Used); end;
  end;
begin
  Result:=0; // EXCEPTION_CONTINUE_SEARCH
  if (StartupDepth=0) or WritingException or (LogFile=INVALID_HANDLE_VALUE) or
    (Info=nil) or (Info^.ExceptionRecord=nil) or
    (Info^.ExceptionRecord^.ExceptionCode<>EXCEPTION_ACCESS_VIOLATION) then Exit;
  WritingException:=True;
  PreviousError:=GetLastError;
  try
    // 障害中はヒープ確保、VCL、ホストのログAPIを使用しない。
    Used:=0;
    Append('first-chance access violation (may be handled), thread='); Hex(GetCurrentThreadId);
    Address:=NativeUInt(Info^.ExceptionRecord^.ExceptionAddress);
    Append(' address='); Hex(Address);
    if VirtualQuery(Pointer(Address),Memory,SizeOf(Memory))<>0 then
    begin
      Append(' module=');
      I:=GetModuleFileName(HMODULE(Memory.AllocationBase),Path,Length(Path));
      if (I>0) and (I<Length(Path)) then Append(Path) else Append('(unknown)');
      Append(' base='); Hex(NativeUInt(Memory.AllocationBase));
      Append(' rva='); Hex(Address-NativeUInt(Memory.AllocationBase));
    end;
    if Info^.ExceptionRecord^.NumberParameters>=2 then
    begin
      Append(' operation='); Hex(Info^.ExceptionRecord^.ExceptionInformation[0]);
      Append(' target='); Hex(Info^.ExceptionRecord^.ExceptionInformation[1]);
    end;
    Append(#13#10); Line[Used]:=#0;
    ByteCount:=WideCharToMultiByte(CP_UTF8,0,Line,Used,Bytes,SizeOf(Bytes),nil,nil);
    if ByteCount>0 then WriteFile(LogFile,Bytes,ByteCount,Written,nil);
  finally
    SetLastError(PreviousError);
    WritingException:=False;
  end;
end;

procedure EnterGraphStartup(const Stage:string);
begin
  Inc(StartupDepth);
  try WriteStartupLine(Stage+' begin'); except end;
end;

procedure LeaveGraphStartup(const Stage:string);
begin
  try WriteStartupLine(Stage+' end'); except end;
  if StartupDepth>0 then Dec(StartupDepth);
end;

procedure ReportGraphStartupError(const Stage:string; Error:Exception);
begin
  try
    WriteStartupLine(Stage+' failed: '+Error.ClassName+': '+Error.Message+
      ' address=0x'+IntToHex(NativeUInt(ExceptAddr),16));
  except
  end;
end;

procedure ReportGraphSkiaRuntime(SkiaEntry:Pointer);
var Memory:MEMORY_BASIC_INFORMATION;
begin
  try
    if (SkiaEntry<>nil) and (VirtualQuery(SkiaEntry,Memory,SizeOf(Memory))<>0) then
      WriteModule('sk4d.dll (bound API)',HMODULE(Memory.AllocationBase))
    else WriteModule('sk4d.dll (name lookup)',GetModuleHandle('sk4d.dll'));
  except
  end;
end;

procedure CompleteGraphLibraryStartup;
begin
  ReportGraphSkiaRuntime(nil);
  LeaveGraphStartup('DLL initialization');
end;

procedure StartDiagnostics;
var Root:string; Buffer:array[0..32767] of Char; Size:DWORD; Now:TSystemTime;
begin
  IsMultiThread:=True;
  StartupDepth:=1;
  try
    Size:=GetEnvironmentVariable('LOCALAPPDATA',Buffer,Length(Buffer));
    if (Size=0) or (Size>=DWORD(Length(Buffer))) then Exit;
    Root:=IncludeTrailingPathDelimiter(Copy(string(Buffer),1,Size))+'SYNC_Graph\Diagnostics';
    if not ForceDirectories(Root) then Exit;
    GetLocalTime(Now);
    Root:=IncludeTrailingPathDelimiter(Root)+Format('startup-%.4d%.2d%.2d-%.2d%.2d%.2d-%d-%d.log',
      [Now.wYear,Now.wMonth,Now.wDay,Now.wHour,Now.wMinute,Now.wSecond,GetCurrentProcessId,GetTickCount64]);
    LogFile:=CreateFile(PChar(Root),FILE_APPEND_DATA,FILE_SHARE_READ or FILE_SHARE_WRITE,
      nil,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,0);
    if LogFile=INVALID_HANDLE_VALUE then Exit;
    WriteStartupLine('DLL initialization begin');
    WriteModule('host',GetModuleHandle(nil));
    WriteModule('plugin',HInstance);
    WriteModule('sk4d.dll before initialization',GetModuleHandle('sk4d.dll'));
    ExceptionObserver:=AddVectoredExceptionHandler(1,@ObserveStartupException);
    if ExceptionObserver=nil then WriteStartupLine('Exception observer unavailable');
  except
    // 保存先を使えない環境でも通常の起動を続ける。
  end;
end;

initialization
  StartDiagnostics;
finalization
  if ExceptionObserver<>nil then RemoveVectoredExceptionHandler(ExceptionObserver);
  if LogFile<>INVALID_HANDLE_VALUE then CloseHandle(LogFile);
end.
