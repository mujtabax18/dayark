$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $root
$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)' | Select-Object -First 1
if (-not $versionLine) { throw 'Missing semantic version in pubspec.yaml' }
$version = $versionLine.Matches[0].Groups[1].Value
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
$iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
  $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
}
if (-not (Test-Path $iscc)) { throw 'Install Inno Setup 6 first (ISCC.exe not found).' }
& $iscc "/DMyAppVersion=$version" 'packaging\windows\dayark.iss'
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed' }
Write-Host 'Upload dist\DayArk-Setup-windows-x64.exe to the matching GitHub release.'
