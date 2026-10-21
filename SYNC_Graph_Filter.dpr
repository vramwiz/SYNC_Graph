library SYNC_Graph_Filter;

{$IFNDEF SKIA_DEFERRED_INIT}
  {$MESSAGE FATAL 'Build the plugin through SYNC_Graph_Filter.dproj to enable deferred Skia initialization.'}
{$ENDIF}

uses
  GraphStartupDiagnostics in 'Source\Host\GraphStartupDiagnostics.pas',
  System.Skia in 'Win64\SkiaOverride\System.Skia.pas',
  System.SysUtils,
  System.Skia.API,
  TextRendererSkiaRuntime in 'Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkiaBootstrap in 'Source\Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2Canvas\Host\AviUtl2FilterTypes.pas',
  GraphPlugin in 'Source\Host\GraphPlugin.pas',
  GraphHostLog in 'Source\Host\GraphHostLog.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  EnterGraphStartup('InitializePlugin');
  try
  try
    InitializeGraphPlugin;
    ReportGraphSkiaRuntime(@sk4d_streamadapter_set_procs);
    Result := 1;
  except
    on E:Exception do
    begin
      ReportGraphStartupError('InitializePlugin',E);
      Result := 0;
    end;
    else Result := 0;
  end;
  finally LeaveGraphStartup('InitializePlugin'); end;
end;

procedure UninitializePlugin; cdecl;
begin
  try
    FinalizeGraphPlugin;
  except
    // No exception may cross the host ABI.
  end;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  EnterGraphStartup('GetFilterPluginTable');
  try
  try
    Result := GraphPluginTable;
  except
    on E:Exception do
    begin
      ReportGraphStartupError('GetFilterPluginTable',E);
      Result := nil;
    end;
    else Result := nil;
  end;
  finally LeaveGraphStartup('GetFilterPluginTable'); end;
end;

procedure InitializeLogger(Handle:PGraphLogHandle); cdecl;
begin
  InitializeGraphLogger(Handle);
end;

exports
  InitializeLogger name 'InitializeLogger',
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
  CompleteGraphLibraryStartup;
end.
