# Install Obsidian, and register a vault so the app opens straight into it.
#
# Obsidian publishes the current version in the manifest its own updater reads.
# Resolve the version from there, then build the real GitHub release URL. Do NOT
# point at obsidian.md/download - that is an HTML landing page, and downloading
# it produces an "installer" that is actually a web page.

$script:ObsidianReleasesJson = if ($env:OBSIDIAN_RELEASES_JSON) { $env:OBSIDIAN_RELEASES_JSON }
    else { 'https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/desktop-releases.json' }

function Get-ObsidianLatestVersion {
    try {
        $ProgressPreference = 'SilentlyContinue'
        $json = Invoke-RestMethod -Uri $script:ObsidianReleasesJson -UseBasicParsing -ErrorAction Stop
        $v = Get-Prop -Object $json -Name 'latestVersion'
        if ($v) { return [string]$v }
    } catch {
        Write-Log ("OBS-VER-ERR " + $_.Exception.Message)
    }
    return $null
}

function Get-ObsidianExeUrl {
    param([Parameter(Mandatory=$true)][string]$Version)
    return "https://github.com/obsidianmd/obsidian-releases/releases/download/v$Version/Obsidian-$Version.exe"
}

# Printed whenever the automated install does not work. Installing Obsidian by
# hand takes a minute and nothing else in the setup depends on it having
# happened first, so this is a warning and never a failure.
function Write-ObsidianManualNote {
    Write-Warn "Could not install Obsidian automatically."
    Write-Say  "  Everything else here is done - your vault is set up and Claude can use it."
    Write-Say  "  To read your notes in Obsidian, install it from https://obsidian.md/download"
    Write-Say  "  and then re-run this installer; it will register the vault and skip the rest."
    Add-Record "Obsidian: NOT installed - install it from obsidian.md/download and re-run"
}

function Get-ObsidianPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'),
        (Join-Path ${env:ProgramFiles} 'Obsidian\Obsidian.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

function Install-Obsidian {
    Write-Step "Obsidian"

    $existing = Get-ObsidianPath
    if ($existing) {
        Write-Skip "Already installed at $existing"
        Add-Record "Obsidian: already installed, left alone"
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # Try a per-user install first: the machine-wide variant wants admin
        # rights, which we do not assume anyone has.
        Write-Say "  Installing via winget (per-user)..."
        $wgArgs = @('install','-e','--id','Obsidian.Obsidian','--scope','user','--silent',
                  '--accept-package-agreements','--accept-source-agreements')
        & winget @wgArgs *>> (Get-LogPath)
        if (Get-ObsidianPath) { Write-Ok "Installed via winget"; Add-Record "Obsidian: installed"; return }

        Write-Say "  Per-user install unavailable - trying winget's default scope..."
        $wgArgs = @('install','-e','--id','Obsidian.Obsidian','--silent',
                  '--accept-package-agreements','--accept-source-agreements')
        & winget @wgArgs *>> (Get-LogPath)
        if (Get-ObsidianPath) { Write-Ok "Installed via winget"; Add-Record "Obsidian: installed"; return }

        Write-Warn "winget could not install Obsidian - falling back to a direct download."
    } else {
        Write-Skip "winget not present - using a direct download instead"
    }

    Install-ObsidianFromExe
}

# Obsidian's own installer is NSIS and installs per-user into %LOCALAPPDATA%
# with no admin rights. /S runs it silently.
function Install-ObsidianFromExe {
    $version = Get-ObsidianLatestVersion
    if (-not $version) {
        Write-Warn "Could not work out the current Obsidian version."
        Write-ObsidianManualNote
        return
    }

    $tmp = Join-Path $env:TEMP ("brain-obsidian-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $exe = Join-Path $tmp 'Obsidian-setup.exe'

    Write-Say "  Downloading Obsidian $version..."
    if (-not (Save-Download -Url (Get-ObsidianExeUrl -Version $version) -Destination $exe -What "Obsidian $version")) {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-ObsidianManualNote
        return
    }

    try {
        Write-Say "  Running the installer silently..."
        Start-Process -FilePath $exe -ArgumentList '/S' -Wait
    } catch {
        Write-Log ("OBS-RUN-ERR " + $_.Exception.Message)
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-ObsidianManualNote
        return
    }

    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

    if (Get-ObsidianPath) {
        Write-Ok "Installed Obsidian $version"
        Add-Record "Obsidian: installed ($version)"
    } else {
        Write-Warn "Obsidian's installer ran but the app was not found where expected."
        Write-Say  "  It may be installed and simply somewhere unusual - check the Start menu."
        Add-Record "Obsidian: installer ran, location not confirmed"
    }
}

# Add the vault to Obsidian's own config so the app opens into it rather than
# showing the vault picker. Obsidian must not be running while this is written,
# and must be restarted afterwards to pick the vault up.
function Register-Vault {
    param([Parameter(Mandatory=$true)][string]$VaultPath)

    Write-Step "Registering the vault with Obsidian"

    if (-not (Test-Path (Join-Path $VaultPath '.obsidian'))) {
        Write-Warn "No .obsidian folder in the vault - Obsidian will not recognise it. Skipping registration."
        Add-Record "Obsidian registration: skipped (no .obsidian folder)"
        return
    }

    $cfgDir = Join-Path $env:APPDATA 'obsidian'
    $cfg    = Join-Path $cfgDir 'obsidian.json'

    if (Get-Process -Name 'Obsidian' -ErrorAction SilentlyContinue) {
        if (Read-Confirm "Obsidian is running and has to be closed to register the vault. Close it now?") {
            Stop-Process -Name 'Obsidian' -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } else {
            Write-Warn "Left Obsidian running - open the vault yourself with File > Open folder as vault."
            Add-Record "Obsidian registration: skipped (Obsidian left running)"
            return
        }
    }

    if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }

    $id = -join ((1..16) | ForEach-Object { '0123456789abcdef'[(Get-Random -Maximum 16)] })
    $ts = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())

    $data = $null
    if (Test-Path $cfg) {
        try { $data = Get-Content -Raw -Path $cfg | ConvertFrom-Json } catch { $data = $null }
        if ($data) {
            Copy-Item $cfg "$cfg.brain-backup.$(Get-Date -Format yyyyMMddHHmmss)" -Force -ErrorAction SilentlyContinue
        } else {
            Write-Warn "Obsidian's config could not be read - leaving it alone. Open the vault once with File > Open folder as vault."
            Add-Record "Obsidian registration: config left untouched (could not read it)"
            return
        }
    }

    if (-not $data) { $data = New-Object psobject }

    # Never dot-access a property that may not be there: under
    # Set-StrictMode -Version 2.0 that is a terminating error, not $null. A fresh
    # obsidian.json, or one written by a different Obsidian version, may have no
    # "vaults" at all - which is precisely what broke the first Windows install.
    $vaults = Get-Prop -Object $data -Name 'vaults'
    if (-not $vaults) {
        $vaults = New-Object psobject
        $data | Add-Member -NotePropertyName 'vaults' -NotePropertyValue $vaults -Force
    }

    $existingCount = 0
    foreach ($prop in $vaults.PSObject.Properties) {
        $existingCount++
        if ((Get-Prop -Object $prop.Value -Name 'path') -eq $VaultPath) {
            Write-Skip "Already registered with Obsidian"
            Add-Record "Obsidian registration: already registered, left alone"
            return
        }
    }

    # "open" marks the vault Obsidian opens on launch. If there are other vaults
    # already, leave this one false so whichever the owner currently has open
    # stays the one that opens. Two entries both claiming to be open makes
    # Obsidian's startup unpredictable.
    $isOnlyVault = ($existingCount -eq 0)

    $entry = New-Object psobject
    $entry | Add-Member -NotePropertyName 'path' -NotePropertyValue $VaultPath
    $entry | Add-Member -NotePropertyName 'ts'   -NotePropertyValue $ts
    $entry | Add-Member -NotePropertyName 'open' -NotePropertyValue $isOnlyVault
    $vaults | Add-Member -NotePropertyName $id -NotePropertyValue $entry -Force

    try {
        ($data | ConvertTo-Json -Depth 10) | Set-Content -Path $cfg -Encoding UTF8
        if ($isOnlyVault) {
            Write-Ok "Registered, and set as the vault Obsidian opens"
            Add-Record "Obsidian registration: registered as the default vault"
        } else {
            Write-Ok "Registered alongside your existing vaults (they still open as before)"
            Write-Say "  Pick it from Obsidian's vault switcher, bottom left."
            Add-Record "Obsidian registration: added alongside existing vaults"
        }
    } catch {
        Write-Warn "Could not write Obsidian's config - open the vault once with File > Open folder as vault and Obsidian will remember it."
        Add-Record "Obsidian registration: config left untouched (could not write it)"
    }
}
