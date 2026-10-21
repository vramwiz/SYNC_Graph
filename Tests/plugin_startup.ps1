param([Parameter(Mandatory=$true)][string]$PluginPath,
  [ValidateSet('Debug','Release')][string]$Config='Debug')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root "Win64\Tests\PluginStartup\$Config"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$setup='C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$line='call "'+$setup+'" && dcc64 -B -Q -E"'+$out+'" -N0"'+$out+'" "'+(Join-Path $PSScriptRoot 'PluginStartupSmoke.dpr')+'"'
& $env:ComSpec /d /s /c $line
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $out 'PluginStartupSmoke.exe') $PluginPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# 絶対パスで同梱DLLを要求するため、PATHに別のSkiaがあっても欠落を検出する。
$missingDir=Join-Path $out ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $missingDir | Out-Null
$missingPlugin=Join-Path $missingDir 'SYNC_Graph_Filter.auf2'
Copy-Item -LiteralPath $PluginPath -Destination $missingPlugin
& (Join-Path $out 'PluginStartupSmoke.exe') $missingPlugin 'expect-failure'
exit $LASTEXITCODE
