<#
    Brain installer - Windows

    Sets up a context brain: Obsidian, the Claude desktop app, a structured vault
    in the home folder named after the owner's work email (jsmith@... ->
    %USERPROFILE%\jsmith-brain), and the skills that populate and maintain it.

        powershell -ExecutionPolicy Bypass -File .\install.ps1
        powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
        powershell -ExecutionPolicy Bypass -File .\install.ps1 -ReplaceSkills
        powershell -ExecutionPolicy Bypass -File .\install.ps1 -ReplaceGuide

    or in one line (it downloads the rest of the package itself):

        irm <your-host>/install.ps1 | iex

    Needs no administrator rights.

    It is safe to run more than once, and safe to run on a machine that already
    has a brain. Every step checks first and skips what is already there. Nothing
    that exists is ever overwritten - not a note, not a skill, not an Obsidian
    setting, not a line of Obsidian's own config.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$ReplaceSkills,
    [switch]$ReplaceGuide
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# --- where the package is ----------------------------------------------------

# Where the packaged Windows folder is hosted. Published by
# .github/workflows/pages.yml on every push, so this points at the current build.
#
# It is only ever used when this script is NOT sitting next to a template folder,
# because Resolve-Payload checks $ScriptDir first. So a copy someone downloaded and
# extracted always uses its own files and never touches the network, and a piped run
# fetches the package it belongs to. Set BRAIN_PACKAGE_URL to override.
$PackageUrl = $env:BRAIN_PACKAGE_URL
if (-not $PackageUrl) { $PackageUrl = 'https://sistergroup.github.io/install-brain/brain-windows.zip' }

$ScriptDir = ''
if ($PSCommandPath) { $ScriptDir = Split-Path -Parent $PSCommandPath }
elseif ($PSScriptRoot) { $ScriptDir = $PSScriptRoot }

$TmpPayload = ''

function Resolve-Payload {
    if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir 'template')) -and (Test-Path (Join-Path $ScriptDir 'lib'))) {
        return $ScriptDir
    }

    if (-not $PackageUrl) {
        Write-Host ""
        Write-Host "Install stopped: run this from the folder it came in." -ForegroundColor Red
        Write-Host ""
        Write-Host "  cd <the Windows folder>"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\install.ps1"
        Write-Host ""
        Write-Host "Piping it from a URL only works if BRAIN_PACKAGE_URL points at a hosted"
        Write-Host "copy of that folder."
        exit 1
    }

    Write-Host "==> Fetching the installer package" -ForegroundColor Cyan
    $script:TmpPayload = Join-Path $env:TEMP ("brain-pkg-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:TmpPayload -Force | Out-Null
    $zip = Join-Path $script:TmpPayload 'package.zip'

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $PackageUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $script:TmpPayload -Force
    } catch {
        Write-Host ""
        Write-Host "Install stopped: could not download the installer package from" -ForegroundColor Red
        Write-Host "  $PackageUrl"
        Write-Host ""
        Write-Host "Either the network is blocked or that URL is not published yet. Ask for"
        Write-Host "the Brain installer folder, unzip it, and run install.ps1 from inside it."
        exit 1
    }

    if (Test-Path (Join-Path $script:TmpPayload 'template')) { return $script:TmpPayload }

    $found = Get-ChildItem -Path $script:TmpPayload -Recurse -Directory -Filter 'template' -ErrorAction SilentlyContinue |
             Select-Object -First 1
    if (-not $found) {
        Write-Host "The downloaded package did not contain a template folder." -ForegroundColor Red
        exit 1
    }
    return $found.Parent.FullName
}

$Payload = Resolve-Payload

. (Join-Path $Payload 'lib\Common.ps1')
. (Join-Path $Payload 'lib\Obsidian.ps1')
. (Join-Path $Payload 'lib\Claude.ps1')
. (Join-Path $Payload 'lib\Sync.ps1')
. (Join-Path $Payload 'lib\Vault.ps1')

Initialize-Log
Write-Log ("dry_run=" + $DryRun + " replace_skills=" + $ReplaceSkills + " replace_guide=" + $ReplaceGuide)

# --- preflight ---------------------------------------------------------------

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Stop-Install "This needs Windows PowerShell 5 or newer. Yours is $($PSVersionTable.PSVersion)."
}

$SetupDate = Get-Date -Format 'yyyy-MM-dd'
$Adopted   = $false

Write-Host ""
if ($DryRun) {
    Write-Host "  Brain - dry run"
    Write-Host "  ---------------------------------------------------------------"
    Write-Host "  Nothing will be installed, created or changed. This only"
    Write-Host "  reports what a real run would do."
} else {
    Write-Host "  Brain - setup"
    Write-Host "  ---------------------------------------------------------------"
    Write-Host "  Installs Obsidian and the Claude desktop app, then creates"
    Write-Host "  your vault in your home folder."
    Write-Host ""
    Write-Host "  No administrator rights needed. Safe to run again: every"
    Write-Host "  step checks first and never overwrites anything that is"
    Write-Host "  already there."
}
Write-Host ""

# --- who you are -------------------------------------------------------------

Write-Step "About you"
Write-Say  "  Used to label your own notes. Nothing is sent anywhere."

$OwnerName   = Read-Answer -Prompt "Your full name"           -Default $env:BRAIN_OWNER_NAME
$OwnerEmail  = Read-Answer -Prompt "Your work email (the Microsoft 365 one)" -Default $env:BRAIN_OWNER_EMAIL
$CompanyName = Read-Answer -Prompt "The company you work for" -Default $env:BRAIN_COMPANY_NAME

# Nothing is asked about the work itself. What it produces, how it arrives and who
# it is with are all inferred by /brain-setup from the mailbox, calendar and Teams,
# then stated back with the evidence and confirmed. The installer stages every set
# of role extras into the vault so the skill can apply the one that fits.

# The folder is named from the email so it is recognisable inside a sync folder.
# Where it goes is the next question - the home folder is only the default.
$VaultName = Get-VaultName -Email $OwnerEmail
$VaultPath = ''
$VaultLink = ''

# --- a brain you already have ------------------------------------------------

Write-Step "Looking for a brain you already have"
$Existing = Find-ExistingVault -VaultName $VaultName
if ($Existing) {
    Write-Say "  Found one at $Existing"
    if (Read-Confirm "Use that one, and just add anything it is missing?") {
        $Adopted   = $true
        $VaultPath = $Existing
        $VaultLink = ''
        $Sync = @{
            Provider         = (Get-ProviderFromPath -Path $Existing)
            Real             = $Existing
            Path             = $Existing
            Link             = ''
            Location         = $Existing
            NeedsDriveMirror = $false
        }
        Write-Ok "Using your existing vault. Its notes, settings and skills stay exactly as they are."
        Write-Say "  Its location is not changed either."
        Add-Record "Existing vault at $Existing adopted - nothing in it replaced"
    } else {
        Write-Say "  Leaving it alone and setting up a separate one."
        Add-Record "Existing vault at $Existing left untouched; created a separate vault"
    }
} else {
    Write-Skip "None found - setting one up"
}

# --- where it goes -----------------------------------------------------------

if ($Adopted) {
    Write-Step "Where your brain folder should go"
    Write-Skip "Leaving your existing vault where it is: $($Sync.Real)"
    Write-Step "Backing it up"
    Write-Skip "Leaving your existing setup alone (looks like: $($Sync.Provider))"
} else {
    $Location  = Select-Location -VaultName $VaultName -HomeFolder $env:USERPROFILE
    $VaultPath = $Location.Path
    $VaultLink = $Location.Link

    $Backup = Select-Sync -Real $Location.Real

    $Sync = @{
        Real             = $Location.Real
        Path             = $Location.Path
        Link             = $Location.Link
        Provider         = $Backup.Provider
        Location         = $Backup.Location
        NeedsDriveMirror = $Backup.NeedsDriveMirror
    }
}

$Tokens = @{
    OWNER_NAME    = $OwnerName
    OWNER_EMAIL   = $OwnerEmail
    COMPANY_NAME  = $CompanyName
    VAULT_NAME    = $VaultName
    VAULT_PATH    = $VaultPath
    SYNC_PROVIDER = $Sync.Provider
    SYNC_LOCATION = $Sync.Location
    SETUP_DATE    = $SetupDate
}

# --- dry run stops here ------------------------------------------------------

if ($DryRun) {
    Write-Step "What a real run would do"

    if (Get-ObsidianPath) { Write-Skip "Obsidian - already installed, would skip" }
    else                  { Write-Say  "  + would install Obsidian" }

    if (Get-ClaudeAppPath) { Write-Skip "Claude desktop app - already installed, would skip" }
    else                   { Write-Say  "  + would install the Claude desktop app" }

    if (Test-IsVault -Path $Sync.Real) {
        Write-Say "  . vault at $($Sync.Real) exists - would add only missing folders and notes"
    } else {
        Write-Say "  + would create the vault at $($Sync.Real)"
    }

    $installedGuide = Join-Path $Sync.Real 'Meta\Vault Guide.md'
    if (Test-Path $installedGuide) {
        $iv = Get-GuideVersion -Path $installedGuide
        $sv = Get-GuideVersion -Path (Join-Path $Payload 'template\Meta\Vault Guide.md')
        if ($ReplaceGuide) {
            Write-Say  "  + would replace the Vault Guide with v$sv, keeping yours beside it (-ReplaceGuide)"
        } elseif ($iv -eq 0) {
            Write-Skip "Vault Guide - carries no version, would leave it alone"
        } elseif ($sv -gt $iv) {
            Write-Say  "  + would update the Vault Guide v$iv -> v$sv, keeping yours beside it"
        } else {
            Write-Skip "Vault Guide - already v$iv, would leave it alone"
        }
    }

    if ($VaultLink) {
        if (Test-Path $VaultLink) { Write-Skip "shortcut $VaultLink - something is already there, would leave it alone" }
        else                      { Write-Say  "  + would add a shortcut at $VaultLink" }
    }

    foreach ($d in (Get-ChildItem -Path (Join-Path $Payload 'skills') -Directory -ErrorAction SilentlyContinue)) {
        if (Test-Path (Join-Path $VaultPath ".claude\skills\$($d.Name)")) {
            Write-Skip "skill $($d.Name) - already there, would leave alone"
        } else {
            Write-Say "  + would install skill $($d.Name)"
        }
    }

    if (Test-Path -LiteralPath (Join-Path $VaultPath 'Meta\.roles')) {
        Write-Skip "role extras - already staged, would leave alone"
    } else {
        Write-Say  "  + would stage every set of role extras for /brain-setup to apply"
    }

    if (Test-Path (Join-Path $VaultPath 'CLAUDE.md')) { Write-Skip "CLAUDE.md - exists, would leave alone" }
    else                                             { Write-Say  "  + would write CLAUDE.md" }

    $cfg = Join-Path $env:APPDATA 'obsidian\obsidian.json'
    if (Test-Path $cfg) {
        $raw = Get-Content -Raw -Path $cfg -ErrorAction SilentlyContinue
        if ($raw -and $raw.Contains($Sync.Real)) {
            Write-Skip "Obsidian registration - already registered, would leave alone"
        } else {
            Write-Say "  + would register the vault alongside your existing ones, without changing which opens"
        }
    } else {
        Write-Say "  + would register the vault as Obsidian's default"
    }

    Write-Host ""
    Write-Host "  Nothing was changed. Drop -DryRun to do it for real."
    Write-Host ""
    if ($script:TmpPayload -and (Test-Path $script:TmpPayload)) {
        Remove-Item $script:TmpPayload -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

# --- do the work -------------------------------------------------------------

# The vault is the deliverable, so a failure there is fatal. Everything else is a
# convenience and must never take the run down with it - the first Windows
# install died inside Register-Vault and the employee never saw what to do next.
Invoke-Step "Installing Obsidian"          { Install-Obsidian }
Invoke-Step "Installing the Claude app"    { Install-ClaudeApp }

New-Vault -RealPath $Sync.Real -Payload $Payload -Tokens $Tokens -ReplaceGuide:$ReplaceGuide

if (-not $Adopted) {
    if ($VaultLink) {
        Invoke-Step "Adding a shortcut in your home folder" { New-VaultLink -LinkPath $VaultLink -RealPath $Sync.Real }
    }
    Invoke-Step "Pinning the OneDrive folder" { Set-OneDrivePin -Provider $Sync.Provider -RealPath $Sync.Real }
}

Invoke-Step "Installing the brain skills"      { Install-Skills -VaultPath $VaultPath -Payload $Payload -OwnerName $OwnerName -ReplaceSkills:$ReplaceSkills }
Invoke-Step "Registering the vault with Obsidian" { Register-Vault -VaultPath $Sync.Real }

# --- what is left ------------------------------------------------------------

Write-Summary

Write-Step "Done - four short steps left, and they all happen in the Claude app"
Write-Host ""
Write-Host "  Your vault is at $VaultPath"
Write-Host "  Sync: $($Sync.Provider)"
if ($VaultLink -and (Test-Path $VaultLink)) { Write-Host "  Shortcut: $VaultLink" }

if ($Sync.NeedsDriveMirror) {
    Write-Host ""
    Write-Host "  Google Drive needs one manual step, because it cannot be scripted:"
    Write-Host "  open Google Drive for desktop > Preferences > Folders from your computer,"
    Write-Host "  click ""Add folder"", choose $VaultPath, and set it to Mirror."
}

Write-Host ""
Write-Host "  1. Open Claude and sign in."
Write-Host "  2. Connect Microsoft 365, in Settings > Connectors > Microsoft 365 > Connect."
Write-Host "  3. Add the three brain skills to your own account. They are waiting as zips in"
Write-Host "     $VaultPath\Meta\Setup"
Write-Host "     In Claude: Customize > Skills > + > Create skill > Upload a skill."
Write-Host "  4. Start a chat, add the folder $VaultPath, and type:  /brain-setup"
Write-Host ""
Write-Host "  Claude will say what it wants to read before it reads anything, draft your"
Write-Host "  profile, style, companies, people and projects, then ask about the rest."
Write-Host ""
Write-Host "  Step 3 is by hand because Claude only sees skills that are on your own"
Write-Host "  account, and nothing can put them there from outside. One minute, once."
Write-Host ""
Write-Host "  All of this is written out in $VaultPath\START HERE.md"
Write-Host "  Install log: $(Get-LogPath)"
Write-Host ""

$claudeApp = Get-ClaudeAppPath
if ($claudeApp) {
    if (Read-Confirm "Open Claude now?") {
        try { Start-Process -FilePath $claudeApp } catch { Write-Log ("OPEN-ERR " + $_.Exception.Message) }
    }
}

Write-Log "=== Brain install finished ==="

if ($script:TmpPayload -and (Test-Path $script:TmpPayload)) {
    Remove-Item $script:TmpPayload -Recurse -Force -ErrorAction SilentlyContinue
}
