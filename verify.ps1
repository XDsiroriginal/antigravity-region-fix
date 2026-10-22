#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$Minutes = 15
)

$ErrorActionPreference = 'Continue'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

$log = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'

if (-not (Test-Path -LiteralPath $log)) {
    Say "[warn] no language server log yet: $log" 'Yellow'
    Say 'Open Antigravity and send one message, then run this check again.' 'Yellow'
    exit 2
}

$ls = Get-Process -Name 'language_server' -ErrorAction SilentlyContinue
if (-not $ls) { Say '[warn] Antigravity is not running - start it from the shortcut and send a message.' 'Yellow' }

$tail = @(Get-Content -LiteralPath $log -Tail 4000 -ErrorAction SilentlyContinue)
$rx = '\b[EWI](\d{2})(\d{2}) (\d{2}:\d{2}:\d{2}(?:\.\d+)?)\b.*User location is not supported'
$year = (Get-Date).Year
$last = $null

for ($i = $tail.Count - 1; $i -ge 0; $i--) {
    $m = [regex]::Match([string]$tail[$i], $rx)
    if (-not $m.Success) { continue }
    $s = '{0}-{1}-{2} {3}' -f $year, $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value
    try { $last = [datetime]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture) } catch { $last = $null }
    break
}

if ($last -and ((Get-Date) - $last).TotalMinutes -le $Minutes) {
    Say "[err]  region block detected at $($last.ToString('HH:mm:ss'))" 'Red'
    Say 'The exit country is rejected by Google. Switch the VPN node to USA and run install.ps1 again.' 'Yellow'
    Say 'You can also force a proxy:  install.ps1 -Upstream "socks5://127.0.0.1:PORT"' 'Yellow'
    exit 1
}

Say "[ok]   no region block in the last $Minutes minutes" 'Green'
if ($last) { Say "       (last one was at $($last.ToString('dd.MM HH:mm:ss')))" 'DarkGray' }
Say 'Antigravity talks to Google normally.' 'Green'
exit 0
