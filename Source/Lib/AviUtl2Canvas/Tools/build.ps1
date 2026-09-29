param([ValidateSet('Debug','Release')][string]$Config = 'Debug', [switch]$Install)
$ErrorActionPreference = 'Stop'
$kitRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = [IO.Path]::GetFullPath((Join-Path $kitRoot '..\..\..'))
$setup = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$project = Join-Path $projectRoot 'SYNC_Graph_Filter.dproj'
$buildLine = 'call "' + $setup + '" && msbuild "' + $project + '" /t:Build /p:Config=' + $Config + ' /p:Platform=Win64 /v:minimal /nologo'
& $env:ComSpec /d /s /c $buildLine
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$plugin = Join-Path $projectRoot "Win64\Plugin\$Config\SYNC_Graph_Filter.auf2"
if ($Install) {
    if (Get-Process aviutl2 -ErrorAction SilentlyContinue) { throw 'AviUtl2を終了してから配置してください。' }
    $destination = 'C:\ProgramData\aviutl2\Plugin\SYNC_Graph'
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -LiteralPath $plugin -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path (Split-Path $plugin) 'sk4d.dll') -Destination $destination -Force
}
Write-Output $plugin
