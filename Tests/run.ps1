param([ValidateSet('Debug','Release')][string]$Config='Debug')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root "Win64\Tests\$Config"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$setup='C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$units=(Get-ChildItem (Join-Path $root 'Source') -Directory -Recurse | ForEach-Object { $_.FullName }) -join ';'
$line='call "'+$setup+'" && dcc64 -B -Q -U"'+$units+'" -E"'+$out+'" -N0"'+$out+'" "'+$PSScriptRoot+'\GraphTests.dpr"'
& $env:ComSpec /d /s /c $line
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item -LiteralPath 'C:\Program Files (x86)\Embarcadero\Studio\37.0\Redist\win64\sk4d.dll' -Destination $out -Force
Push-Location $out
try { & '.\GraphTests.exe'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { Pop-Location }
$line='call "'+$setup+'" && dcc64 -B -Q -U"'+$units+'" -E"'+$out+'" -N0"'+$out+'" "'+$PSScriptRoot+'\EditorSmoke.dpr"'
& $env:ComSpec /d /s /c $line
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $out 'EditorSmoke.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$line='call "'+$setup+'" && dcc64 -B -Q -U"'+$units+'" -E"'+$out+'" -N0"'+$out+'" "'+$PSScriptRoot+'\PluginSmoke.dpr"'
& $env:ComSpec /d /s /c $line
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$plugin=Join-Path $root "Win64\Plugin\$Config\SYNC_Graph_Filter.auf2"
if (-not (Test-Path -LiteralPath $plugin)) { throw '先に対象構成のプラグインをビルドしてください。' }
& (Join-Path $out 'PluginSmoke.exe') $plugin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
