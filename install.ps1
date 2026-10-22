#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Upstream,
    [switch]$NoRestart,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$AppDir      = Join-Path $env:LOCALAPPDATA 'AntigravityProxy'
$LauncherVbs = Join-Path $AppDir 'Start-Antigravity.vbs'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Ok([string]$text)   { Say "[ok]   $text" 'Green' }
function Warn([string]$text) { Say "[warn] $text" 'Yellow' }
function Fail([string]$text) { Say "[err]  $text" 'Red' }
function Step([string]$text) { Say "`n== $text" 'Cyan' }

function Find-Antigravity {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'),
        'C:\Program Files\Antigravity\Antigravity.exe',
        'C:\Program Files (x86)\Antigravity\Antigravity.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $hit = Get-ChildItem -Path @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}) -Filter 'Antigravity.exe' -Recurse -Depth 4 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike '*\resources\*' } |
        Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

function Get-ProxyCandidates {
    @(
        @{ Port = 10809; Scheme = 'http'   },
        @{ Port = 10808; Scheme = 'socks5' },
        @{ Port = 7890;  Scheme = 'http'   },
        @{ Port = 7891;  Scheme = 'socks5' },
        @{ Port = 7897;  Scheme = 'http'   },
        @{ Port = 7898;  Scheme = 'socks5' },
        @{ Port = 2080;  Scheme = 'socks5' },
        @{ Port = 2081;  Scheme = 'http'   },
        @{ Port = 1080;  Scheme = 'socks5' },
        @{ Port = 1081;  Scheme = 'http'   },
        @{ Port = 2334;  Scheme = 'http'   },
        @{ Port = 12334; Scheme = 'socks5' },
        @{ Port = 1087;  Scheme = 'http'   },
        @{ Port = 1086;  Scheme = 'socks5' },
        @{ Port = 3128;  Scheme = 'http'   },
        @{ Port = 9050;  Scheme = 'socks5' },
        @{ Port = 9150;  Scheme = 'socks5' }
    )
}

function Test-PortListening([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $port)
        if (-not $task.Wait(400)) { return $false }
        return $client.Connected
    } catch { return $false }
    finally { $client.Close() }
}

function Invoke-CurlJson([string]$proxyUrl, [string]$target, [int]$timeoutSec = 15) {
    if ($proxyUrl) {
        $curlArgs = @('-s', '--max-time', "$timeoutSec", '--proxy', $proxyUrl, $target)
    } else {
        $curlArgs = @('-s', '--max-time', "$timeoutSec", $target)
    }
    $raw = & curl.exe @curlArgs 2>$null
    if (-not $raw) { return $null }
    try { return ($raw -join "`n" | ConvertFrom-Json) } catch { return $null }
}

function Test-Upstream([string]$proxyUrl) {
    $info = Invoke-CurlJson -proxyUrl $proxyUrl -target 'https://ipwho.is/'
    if (-not $info -or -not $info.success) { return $null }
    return @{ Url = $proxyUrl; Ip = "$($info.ip)"; Country = "$($info.country_code)"; CountryName = "$($info.country)" }
}

function Set-Shortcut {
    param([string]$Path, [string]$Target, [string]$Arguments, [string]$WorkDir, [string]$Icon, [string]$Description)
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath = $Target
    if ($Arguments) { $lnk.Arguments = $Arguments }
    if ($WorkDir) { $lnk.WorkingDirectory = $WorkDir }
    if ($Icon) { $lnk.IconLocation = $Icon }
    if ($Description) { $lnk.Description = $Description }
    $lnk.Save()
}

Say ""
Say "Antigravity region fix - installer" 'White'
Say "---------------------------------" 'DarkGray'

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Fail 'curl.exe not found (ships with Windows 10 1803+).'
    Say 'Update Windows or run this on a newer build.' 'Yellow'
    exit 1
}

Step '1/4 Locating Antigravity'
$agExe = Find-Antigravity
if (-not $agExe) {
    Fail 'Antigravity.exe not found.'
    Say 'Install Antigravity from https://antigravity.google and run this script again.' 'Yellow'
    exit 1
}
Ok "found: $agExe"
$agDir = Split-Path -Parent $agExe

Step '2/4 Choosing the proxy Antigravity will use'
$chosen = $null

if ($Upstream) {
    Say "explicit upstream: $Upstream"
    $chosen = Test-Upstream $Upstream
    if (-not $chosen) { Fail "upstream $Upstream is not reachable or does not proxy HTTPS"; exit 1 }
    Ok "upstream works: exit $($chosen.Ip) ($($chosen.Country))"
} else {
    Say 'scanning for a local VPN/proxy port...'
    $found = @()
    foreach ($c in (Get-ProxyCandidates)) {
        if (-not (Test-PortListening $c.Port)) { continue }
        $url = "$($c.Scheme)://127.0.0.1:$($c.Port)"
        $r = Test-Upstream $url
        if ($r) {
            $found += $r
            Say ("  port {0,-6} {1,-7} -> exit {2} ({3})" -f $c.Port, $c.Scheme, $r.Ip, $r.Country) 'DarkGray'
        } else {
            Say ("  port {0,-6} {1,-7} -> not a working proxy" -f $c.Port, $c.Scheme) 'DarkGray'
        }
    }

    if ($found.Count -gt 0) {
        $chosen = $found | Where-Object { $_.Country -eq 'US' } | Select-Object -First 1
        if (-not $chosen) { $chosen = $found | Where-Object { $_.Country -notin @('RU', 'BY') } | Select-Object -First 1 }
    }

    if (-not $chosen) {
        $direct = Test-Upstream $null
        if ($direct) {
            Warn "no local proxy port found; direct exit is $($direct.Ip) ($($direct.Country))"
            if ($direct.Country -in @('RU', 'BY')) {
                Fail 'Traffic leaves from a country Google rejects for Antigravity.'
                Say 'Turn on your VPN (any client that opens a SOCKS/HTTP port) and run this script again.' 'Yellow'
                Say 'If your VPN runs in TUN mode only, Antigravity already goes through it - just pick a node in a supported country.' 'Yellow'
                Say 'You can also pass an explicit proxy:  -Upstream "socks5://127.0.0.1:1080"' 'Yellow'
                exit 1
            }
            Say 'Direct connection already leaves from a supported country, no proxy needed.' 'Green'
            Say 'If Antigravity still shows "User location is not supported", switch the VPN node and re-run.' 'Yellow'
            exit 0
        }
        Fail 'No working proxy found and the direct connection could not be tested (no internet?).'
        exit 1
    }
}

Ok "Antigravity will exit via $($chosen.Url) -> $($chosen.Ip) ($($chosen.Country))"
if ($chosen.Country -in @('RU', 'BY')) {
    Warn 'This exit country is usually rejected by Google. Switch the VPN node to USA and re-run.'
} elseif ($chosen.Country -notin @('US', 'CH')) {
    Warn "Country $($chosen.Country) is not verified. If Antigravity still fails, switch the VPN node to USA."
}

Step '3/4 Installing the launcher and shortcuts'
New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
$proxyUrl = $chosen.Url

$vbs = @"
Set sh = CreateObject("WScript.Shell")
Set env = sh.Environment("PROCESS")
env("HTTP_PROXY")  = "$proxyUrl"
env("HTTPS_PROXY") = "$proxyUrl"
env("ALL_PROXY")   = "$proxyUrl"
env("http_proxy")  = "$proxyUrl"
env("https_proxy") = "$proxyUrl"
env("all_proxy")   = "$proxyUrl"
env("NO_PROXY")    = "localhost,127.0.0.1,::1"
env("no_proxy")    = "localhost,127.0.0.1,::1"
sh.Run """$agExe""", 1, False
"@
Set-Content -LiteralPath $LauncherVbs -Value $vbs -Encoding Unicode
Ok "launcher: $LauncherVbs"

$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
$linkArgs = "`"$LauncherVbs`""
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$desktopDir = [Environment]::GetFolderPath('Desktop')

foreach ($lnk in @((Join-Path $startMenuDir 'Antigravity.lnk'), (Join-Path $desktopDir 'Antigravity.lnk'))) {
    try {
        Set-Shortcut -Path $lnk -Target $wscript -Arguments $linkArgs -WorkDir $agDir -Icon "$agExe,0" -Description 'Antigravity (through VPN proxy)'
        Ok "shortcut: $lnk"
    } catch {
        Warn "could not update ${lnk}: $($_.Exception.Message)"
    }
}

Step '4/4 Starting Antigravity with the proxy'
if (-not $NoRestart) {
    if (Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue) {
        Say 'Antigravity is running - restarting it so it picks up the proxy...'
        Get-Process -Name 'Antigravity', 'language_server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
    }
    Start-Process -FilePath $wscript -ArgumentList $linkArgs -WindowStyle Hidden
    Ok 'Antigravity started through the launcher'
} else {
    Warn 'Antigravity was not started (-NoRestart). Use the Antigravity shortcut to launch it.'
}

if (-not $SkipVerify -and -not $NoRestart) {
    Say ''
    Say 'waiting for the language server...' 'DarkGray'
    Start-Sleep -Seconds 20
    $ls = Get-Process -Name 'language_server' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ls) {
        Warn 'language_server did not start yet - open Antigravity and send a message to finish the check.'
    } else {
        $port = $null
        if ($proxyUrl -match '://(?:[^@/]*@)?127\.0\.0\.1:(\d+)') { $port = [int]$Matches[1] }
        if ($port) {
            $conns = @(Get-NetTCPConnection -OwningProcess $ls.Id -State Established -ErrorAction SilentlyContinue |
                Where-Object { $_.RemoteAddress -eq '127.0.0.1' -and $_.RemotePort -eq $port })
            if ($conns.Count -gt 0) {
                Ok "language_server is using the proxy on port $port ($($conns.Count) connections)"
            } else {
                Warn "language_server has no connection to port $port yet - it appears after the first request."
            }
        } else {
            Ok 'language_server is running (upstream is not a local port, nothing to check).'
        }
    }
}

Say ''
Say 'Done.' 'White'
Say "Proxy in use : $proxyUrl"
Say "Exit         : $($chosen.Ip) ($($chosen.Country) / $($chosen.CountryName))"
Say ''
Say 'Now open Antigravity via the usual icon and send any message.'
Say 'If you still see "User location is not supported":' 'Yellow'
Say '  1) switch your VPN node to USA, then run this script again;' 'Yellow'
Say '  2) or run:  install.ps1 -Upstream "socks5://127.0.0.1:PORT"' 'Yellow'
