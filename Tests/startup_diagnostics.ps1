param([ValidateSet('Debug','Release')][string]$Config='Debug')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root "Win64\Tests\StartupDiagnostics\$Config"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$setup='C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$units=(Join-Path $root 'Source\Host')+';'+$PSScriptRoot
$options=if ($Config -eq 'Debug') { '-$O- -$R+ -$Q+ -$D+' } else { '-$O+ -$R- -$Q- -$D-' }
foreach ($source in @('StartupDiagnosticsFixture.dpr','StartupDiagnosticsSmoke.dpr')) {
  $line='call "'+$setup+'" && dcc64 -B -Q '+$options+' -U"'+$units+'" -E"'+$out+'" -N0"'+$out+'" "'+(Join-Path $PSScriptRoot $source)+'"'
  & $env:ComSpec /d /s /c $line
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& (Join-Path $out 'StartupDiagnosticsSmoke.exe')
exit $LASTEXITCODE
