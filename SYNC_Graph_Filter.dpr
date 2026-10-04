library SYNC_Graph_Filter;

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2Canvas\Host\AviUtl2FilterTypes.pas',
  GraphPlugin in 'Source\Host\GraphPlugin.pas',
  GraphHostLog in 'Source\Host\GraphHostLog.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  try
    InitializeGraphPlugin;
    Result := 1;
  except
    Result := 0;
  end;
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
  try
    Result := GraphPluginTable;
  except
    Result := nil;
  end;
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
end.