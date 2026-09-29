param([ValidateSet('Debug','Release')][string]$Config = 'Debug', [switch]$Install)
$ErrorActionPreference = 'Stop'
$kitRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = [IO.Path]::GetFullPath((Join-Path $kitRoot '..\..\..'))
$setup = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$project = Join-Path $projectRoot 'SYNC_Graph_Filter.dproj'
# IDEと同じ標準ビルドイベントで配置する。Installは旧コマンドとの互換引数。
$buildLine = 'call "' + $setup + '" && msbuild "' + $project + '" /t:Build /p:Config=' + $Config + ' /p:Platform=Win64 /v:minimal /nologo'
& $env:ComSpec /d /s /c $buildLine
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output 'C:\ProgramData\aviutl2\Plugin\SYNC_Graph\SYNC_Graph_Filter.auf2'