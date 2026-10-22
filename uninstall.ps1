#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$AppDir = Join-Path $env:LOCALAPPDATA 'AntigravityProxy'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Find-Antigravity {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'),
        'C:\Program Files\Antigravity\Antigravity.exe',
        'C:\Program Files (x86)\Antigravity\Antigravity.exe'
    )
    foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

Say "Antigravity region fix - uninstall" 'White'
Say "-----------------------------------" 'DarkGray'

$agExe = Find-Antigravity

$shell = New-Object -ComObject WScript.Shell
foreach ($lnk in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Antigravity.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity.lnk'))) {
    if (-not (Test-Path -LiteralPath $lnk)) { continue }
    if (-not $agExe) { Say "leave as is (Antigravity.exe not found): $lnk" 'Yellow'; continue }
    $s = $shell.CreateShortcut($lnk)
    $s.TargetPath = $agExe
    $s.Arguments = ''
    $s.WorkingDirectory = (Split-Path -Parent $agExe)
    $s.IconLocation = "$agExe,0"
    $s.Save()
    Say "[ok] restored: $lnk" 'Green'
}

if (Test-Path -LiteralPath $AppDir) {
    Remove-Item -LiteralPath $AppDir -Recurse -Force
    Say "[ok] removed: $AppDir" 'Green'
}

Get-Process -Name 'Antigravity', 'language_server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Say ''
Say 'Done. Start Antigravity from the usual icon (it will no longer use the proxy).' 'White'
