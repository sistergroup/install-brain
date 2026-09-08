# Shared helpers. Dot-sourced by install.ps1 - not meant to be run directly.
# Written for Windows PowerShell 5.1, which is what ships with Windows. No
# PowerShell 7 syntax.

# LOCALAPPDATA is always set on Windows; the fallback is only so a missing
# variable produces a log in the temp folder rather than a confusing crash.
$script:BrainLog =
    if ($env:BRAIN_LOG)      { $env:BRAIN_LOG }
    elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Brain\install.log' }
    else                     { Join-Path ([System.IO.Path]::GetTempPath()) 'brain-install.log' }

function Initialize-Log {
    $dir = Split-Path -Parent $script:BrainLog
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Log "=== Brain install started ($([System.Environment]::OSVersion.VersionString), PS $($PSVersionTable.PSVersion)) ==="
}

function Write-Log {
    param([string]$Message)
    try { Add-Content -Path $script:BrainLog -Value ("{0} {1}" -f (Get-Date -Format 's'), $Message) -Encoding UTF8 } catch { }
}

function Get-LogPath { $script:BrainLog }

function Write-Say  { param([string]$m) Write-Host $m;                       Write-Log "SAY  $m" }
function Write-Step { param([string]$m) Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan; Write-Log "STEP $m" }
function Write-Ok   { param([string]$m) Write-Host "  + $m" -ForegroundColor Green;  Write-Log "OK   $m" }
function Write-Skip { param([string]$m) Write-Host "  - $m" -ForegroundColor DarkGray; Write-Log "SKIP $m" }
function Write-Warn { param([string]$m) Write-Host "  ! $m" -ForegroundColor Yellow; Write-Log "WARN $m" }

function Stop-Install {
    param([string]$Message)
    Write-Host ""
    Write-Host "Install stopped: $Message" -ForegroundColor Red
    Write-Host "Full log: $(Get-LogPath)"
    Write-Log "DIE  $Message"
    exit 1
}

# --- summary -----------------------------------------------------------------
# Every step records what it did or did not do, so the end of the run says
# plainly what changed. On a re-run most lines should read "left alone".

$script:Summary = New-Object System.Collections.ArrayList

function Add-Record {
    param([string]$Message)
    [void]$script:Summary.Add($Message)
    Write-Log "REC  $Message"
}

function Write-Summary {
    if ($script:Summary.Count -eq 0) { return }
    Write-Host ""
    Write-Host "What this run did"
    foreach ($line in $script:Summary) { Write-Host ("  - " + $line) }
}

# --- running a step safely ---------------------------------------------------
# $ErrorActionPreference is 'Stop', so any unhandled error aborts the whole
# script. That is right for the vault itself and wrong for everything around it:
# the first real Windows install died inside Register-Vault and the employee
# never saw the four steps they still had to do. Conveniences get wrapped.
function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Body
    )
    try {
        & $Body
    } catch {
        Write-Log ("STEP-ERR $Name : " + $_.Exception.ToString())
        Write-Warn "$Name did not finish: $($_.Exception.Message)"
        Write-Say  "  Carrying on - this does not stop the rest of the setup."
        Add-Record "$Name : did not finish, skipped (see the log)"
    }
}

# Read a property that may not exist. Under Set-StrictMode -Version 2.0 a plain
# $obj.missing is a terminating error, not $null - which is exactly what broke
# the first Windows install. Use this for anything parsed from JSON or returned
# by Get-Item, where the shape is not guaranteed.
function Get-Prop {
    param($Object, [Parameter(Mandatory=$true)][string]$Name)
    if ($null -eq $Object) { return $null }
    try {
        $prop = $Object.PSObject.Properties[$Name]
        if ($prop) { return $prop.Value }
    } catch { }
    return $null
}

# --- input -------------------------------------------------------------------

function Read-Answer {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [string]$Default = ''
    )
    while ($true) {
        if ($Default) { $reply = Read-Host "  $Prompt [$Default]" }
        else          { $reply = Read-Host "  $Prompt" }
        if (-not $reply) { $reply = $Default }
        if ($reply) { return $reply }
        Write-Host "  (needed)"
    }
}

function Read-Choice {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][string[]]$Options
    )
    Write-Host ""
    Write-Host "  $Prompt"
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ("    {0}) {1}" -f ($i + 1), $Options[$i])
    }
    while ($true) {
        $reply = Read-Host ("  Choose 1-{0}" -f $Options.Count)
        $n = 0
        if ([int]::TryParse($reply, [ref]$n)) {
            if ($n -ge 1 -and $n -le $Options.Count) { return $Options[$n - 1] }
        }
        Write-Host ("  (1-{0})" -f $Options.Count)
    }
}

function Read-Confirm {
    param([Parameter(Mandatory=$true)][string]$Question)
    $reply = Read-Host "  $Question [Y/n]"
    if ($reply -match '^(n|no)$') { return $false }
    return $true
}

# --- vault name --------------------------------------------------------------
# The vault folder is named after the local part of the owner's work email, so it
# is recognisable in a sync folder shared with other things: jsmith-brain,
# achen-brain. Lowercased, full stops removed, and anything else that is not safe
# in a folder name becomes a hyphen.
#
# Full stops are removed rather than turned into hyphens: it keeps a.chen@ and
# jsmith@ looking like the same convention, and a folder name with no dots in it
# can never be mistaken for a file.
#
# This must stay identical in behaviour to vault_name_from_email in
# MacOS/lib/common.sh, or the same person gets different folder names on their
# Mac and their PC.

function Get-VaultName {
    param([Parameter(Mandatory=$true)][string]$Email)
    $part = ($Email -split '@')[0]
    if ($part) { $part = $part.ToLowerInvariant() } else { $part = '' }
    $part = $part -replace '\.', ''
    $part = $part -replace '[^a-z0-9_-]', '-'
    $part = $part -replace '-{2,}', '-'
    $part = $part.Trim('-', '_')
    if (-not $part) { $part = 'my' }
    return "$part-brain"
}

# --- token substitution ------------------------------------------------------
# Only known tokens are replaced. Obsidian's own {{title}} and {{date}}
# placeholders inside Meta\Templates must survive untouched, so never do a
# blanket {{...}} substitution here.

function Set-Tokens {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][hashtable]$Tokens
    )
    $text = [System.IO.File]::ReadAllText($Path)
    foreach ($key in $Tokens.Keys) {
        $text = $text.Replace('{{' + $key + '}}', [string]$Tokens[$key])
    }
    # LF endings: these are markdown notes read by Obsidian and Claude on any platform.
    $text = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# --- downloads ---------------------------------------------------------------
# Download to a file and refuse anything that is obviously a web page.
#
# This exists because of a real bug: obsidian.md/download and claude.ai/download
# are HTML landing pages, not installers. The download happily saved the page as
# Obsidian.dmg and the install then failed with a baffling error. Checking what
# actually arrived turns that into a clear message.
function Save-Download {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$What
    )

    # Some CDNs refuse PowerShell's default user agent outright, so present a
    # normal browser one. Nothing about the request is otherwise disguised.
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -MaximumRedirection 10 -UserAgent $ua -ErrorAction Stop
    } catch {
        Write-Log ("DL-FAIL $What <- $Url : " + $_.Exception.Message)
        return $false
    }

    if (-not (Test-Path $Destination)) {
        Write-Log "DL-FAIL $What <- $Url (nothing written)"
        return $false
    }

    # An HTML landing page instead of a binary.
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Destination)
        $head  = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(512, $bytes.Length))
        if ($head -match '(?i)<!doctype|<html') {
            Write-Log "DL-HTML $What <- $Url (got a web page, not a file)"
            return $false
        }
    } catch { }

    # Anything under a megabyte is not a desktop app installer.
    $size = (Get-Item $Destination).Length
    if ($size -lt 1000000) {
        Write-Log "DL-SMALL $What <- $Url ($size bytes)"
        return $false
    }

    Write-Log "DL-OK $What ($size bytes)"
    return $true
}

# --- manifest ----------------------------------------------------------------

function Get-ManifestFolders {
    param([Parameter(Mandatory=$true)][string]$ManifestPath)
    $json = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    return (Get-Prop -Object $json -Name 'folders')
}

# A single top-level string value, e.g. Get-ManifestValue -Name 'packageVersion'.
function Get-ManifestValue {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [Parameter(Mandatory=$true)][string]$Name
    )
    $json = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    $v = Get-Prop -Object $json -Name $Name
    if ($null -eq $v) { return '' }
    return [string]$v
}
