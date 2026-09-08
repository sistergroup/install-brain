# Two separate questions, in this order:
#
#   1. Where should the brain folder go?   -> Select-Location
#   2. Should anything back it up?         -> Select-Sync
#
# They are separate because they are separate decisions. Someone may well want
# the folder in Documents and no cloud copy at all, or in a cloud folder and
# nothing further. Neither answer should be inferred from the other.
#
# One real constraint has to be told to people rather than hidden: OneDrive only
# syncs what is inside the OneDrive folder, so it cannot back up a folder
# elsewhere. Google Drive for desktop can mirror any folder. Where an option is
# impossible for the location chosen, say why instead of silently omitting it.
#
# Select-Location returns: Real, Path, Link
# Select-Sync returns:     Provider, Location, NeedsDriveMirror

function Get-OneDriveRoots {
    $roots = @()
    foreach ($v in @($env:OneDriveCommercial, $env:OneDriveConsumer, $env:OneDrive)) {
        if ($v -and (Test-Path $v) -and ($roots -notcontains $v)) { $roots += $v }
    }
    if ($env:USERPROFILE) {
        Get-ChildItem -Path $env:USERPROFILE -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'OneDrive*' } |
            ForEach-Object { if ($roots -notcontains $_.FullName) { $roots += $_.FullName } }
    }
    return $roots
}

function Get-GoogleDriveRoots {
    $roots = @()
    # Drive for desktop mounts a drive letter, G: by default.
    foreach ($d in [char[]]('D'..'Z')) {
        $p = "${d}:\My Drive"
        if (Test-Path $p) { $roots += $p }
    }
    if ($env:USERPROFILE) {
        $u = Join-Path $env:USERPROFILE 'My Drive'
        if ((Test-Path $u) -and ($roots -notcontains $u)) { $roots += $u }
    }
    return $roots
}

function Test-GoogleDriveInstalled {
    # Join-Path throws on a null Path, and these variables are not guaranteed to
    # be set, so check each one before using it.
    foreach ($base in @(${env:ProgramFiles}, ${env:ProgramFiles(x86)})) {
        if (-not $base) { continue }
        if (Test-Path (Join-Path $base 'Google\Drive File Stream')) { return $true }
    }
    return $false
}

# Somewhere the vault must not go. A vault needs to be an ordinary writable
# folder the owner controls; these are none of those things.
function Test-PathSensible {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Parent)

    if (-not $Parent) { Write-Warn "Please give a full path."; return $false }

    $bad = @($env:SystemRoot, ${env:ProgramFiles}, ${env:ProgramFiles(x86)}, $env:ProgramData)
    if ($env:SystemDrive) { $bad += (Join-Path $env:SystemDrive '\') }
    foreach ($b in $bad) {
        if ($b -and ($Parent.TrimEnd('\') -eq $b.TrimEnd('\'))) {
            Write-Warn "$Parent is not somewhere a vault can live."
            return $false
        }
        if ($b -and $env:SystemRoot -and ($Parent -like ($env:SystemRoot + '\*'))) {
            Write-Warn "$Parent is inside Windows itself, so a vault cannot live there."
            return $false
        }
    }

    if (-not ($Parent -match '^[A-Za-z]:\\' -or $Parent -match '^\\\\')) {
        Write-Warn "Please give a full path, like C:\Users\you\Documents."
        return $false
    }
    if (-not (Test-Path $Parent -PathType Container)) { Write-Warn "$Parent does not exist."; return $false }

    # Writable? Find out by trying, rather than by guessing at permissions.
    try {
        $probe = Join-Path $Parent (".brain-write-test-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType File -Path $probe -Force -ErrorAction Stop | Out-Null
        Remove-Item $probe -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warn "$Parent is not writable by you."
        return $false
    }
    return $true
}

# Bounded on purpose: a prompt that can loop forever will, if the input is
# redirected or someone keeps mistyping. Three goes, then fall back.
function Read-CustomParent {
    param([Parameter(Mandatory=$true)][string]$VaultName)
    for ($try = 1; $try -le 3; $try++) {
        $reply = Read-Host "  Full path to the folder it should go inside (blank to go back)"
        if (-not $reply) { return $null }
        $expanded = $reply.Trim('"').TrimEnd('\')
        # If they typed the vault folder itself rather than its parent, accept both.
        if ((Split-Path -Leaf $expanded) -eq $VaultName) { $expanded = Split-Path -Parent $expanded }
        if (Test-PathSensible -Parent $expanded) { return $expanded }
    }
    Write-Warn "That is three tries - going with the home folder instead."
    return $null
}

# Which known cloud folder, if any, a path sits inside. Used only to tell people
# the truth about their options; it decides nothing on its own.
#
# Both sides are normalised to one separator first. Windows accepts / and \
# interchangeably and environment variables arrive with either, so comparing raw
# strings quietly fails to match a folder that is plainly inside OneDrive.
function Get-NormalPath {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Path)
    if (-not $Path) { return '' }
    return ($Path -replace '/', '\').TrimEnd('\')
}

function Get-ContainingCloud {
    param([Parameter(Mandatory=$true)][string]$Path)
    $p = Get-NormalPath -Path $Path
    foreach ($r in @(Get-OneDriveRoots)) {
        $root = Get-NormalPath -Path $r
        if ($root -and ($p -eq $root -or $p -like ($root + '\*'))) { return 'OneDrive' }
    }
    foreach ($r in @(Get-GoogleDriveRoots)) {
        $root = Get-NormalPath -Path $r
        if ($root -and ($p -eq $root -or $p -like ($root + '\*'))) { return 'Google Drive' }
    }
    return ''
}

# --- question 1: where the folder goes ---------------------------------------

function Select-Location {
    param(
        [Parameter(Mandatory=$true)][string]$VaultName,
        [Parameter(Mandatory=$true)][string]$HomeFolder
    )

    Write-Step "Where your brain folder should go"

    Write-Say "  Just the folder location. Backing it up is the next question."
    Write-Say "  The home folder is the recommendation: it always exists, it is always"
    Write-Say "  writable, and it does not depend on a cloud client being signed in."
    Write-Say "  To have a cloud client sync the vault, type a folder inside OneDrive or"
    Write-Say "  Google Drive - the next question picks that up."

    $answer = Read-Choice "Where should the folder go?" @(
        "Your home folder - $HomeFolder\$VaultName  (Recommended)",
        'Somewhere else - I will type the folder'
    )

    if ($answer -like 'Somewhere else*') {
        # Three bad answers falls back to the home folder rather than looping.
        $parent = Read-CustomParent -VaultName $VaultName
        if (-not $parent) {
            Write-Say "  Using the home folder instead."
            $parent = $HomeFolder
        }
    } else {
        $parent = $HomeFolder
    }

    $real = Join-Path $parent $VaultName
    $out = @{ Real = $real; Path = $real; Link = '' }

    # A shortcut in the home folder, so there is always a short path to the vault
    # even when the real one is buried somewhere deep. Never for a vault that
    # already lives in the home folder.
    if ((Get-NormalPath -Path $parent) -ne (Get-NormalPath -Path $HomeFolder)) {
        $out.Link = Join-Path $HomeFolder $VaultName
    }

    Write-Ok "Folder: $real"
    return $out
}

# --- question 2: whether anything backs it up --------------------------------

function Select-Sync {
    param([Parameter(Mandatory=$true)][string]$Real)

    Write-Step "Backing it up"

    $out = @{ Provider = 'None'; Location = 'the vault folder itself, with no cloud copy'; NeedsDriveMirror = $false }
    $inside = Get-ContainingCloud -Path $Real

    if ($inside) {
        # Already in a synced folder. Still their call whether to add anything on
        # top, but say plainly that they do not need to.
        Write-Ok "This folder is inside $inside, so $inside already syncs it."
        $out.Provider = $inside
        $out.Location = $Real

        if ($inside -eq 'OneDrive' -and ((Test-GoogleDriveInstalled) -or @(Get-GoogleDriveRoots).Count -gt 0)) {
            $answer = Read-Choice "Add anything else?" @(
                'No - OneDrive is enough  (Recommended)',
                'Also mirror it into Google Drive'
            )
            if ($answer -like 'Also*') {
                Write-Warn "Two sync clients on one folder can produce duplicate files and lose edits."
                if (Read-Confirm "Do it anyway?") {
                    $out.Provider         = 'OneDrive and Google Drive'
                    $out.Location         = "$Real, synced by OneDrive and mirrored into Google Drive"
                    $out.NeedsDriveMirror = $true
                } else {
                    Write-Ok "Leaving it to OneDrive."
                }
            } else {
                Write-Ok "Leaving it to $inside."
            }
        }
        return $out
    }

    # Not in a cloud folder. Google Drive can mirror any folder; OneDrive cannot,
    # and people deserve to know why it is not on the list.
    if (-not (Test-GoogleDriveInstalled) -and @(Get-GoogleDriveRoots).Count -eq 0) {
        Write-Say "  Nothing on this PC can back up a folder in this location:"
        Write-Say "  Google Drive for desktop is not installed, and OneDrive only syncs"
        Write-Say "  folders inside OneDrive itself."
        Write-Say "  Get Drive from https://www.google.com/drive/download/ and re-run this,"
        Write-Say "  or re-run and type a folder inside OneDrive."
        Add-Record "Sync: none available for this location"
        return $out
    }

    Write-Say "  Google Drive can mirror a folder anywhere. OneDrive cannot - it only"
    Write-Say "  syncs folders inside OneDrive - so if you want OneDrive, re-run this"
    Write-Say "  and type a folder inside OneDrive."

    $answer = Read-Choice "Back this folder up to Google Drive?" @(
        'Yes - mirror it into Google Drive',
        'No - not for now'
    )

    if ($answer -like 'Yes*') {
        $out.Provider         = 'Google Drive'
        $out.Location         = "$Real, mirrored into Google Drive"
        $out.NeedsDriveMirror = $true
        if (-not (Test-GoogleDriveInstalled)) {
            Write-Warn "Google Drive for desktop is not installed - get it from https://www.google.com/drive/download/"
        }
    } else {
        Write-Ok "No cloud copy. You can add one later."
    }
    return $out
}

# ~\<name>-brain is a convenience shortcut when the real vault lives elsewhere.
# A junction needs no administrator rights; a symbolic link would.
function New-VaultLink {
    param(
        [Parameter(Mandatory=$true)][string]$LinkPath,
        [Parameter(Mandatory=$true)][string]$RealPath
    )
    if ($LinkPath -eq $RealPath) { return }

    Write-Step "Adding a shortcut at $LinkPath"

    $item = Get-Item -Path $LinkPath -Force -ErrorAction SilentlyContinue
    if ($item) {
        $isLink = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint
        if ($isLink) {
            # Windows PowerShell 5.1's DirectoryInfo has no Target property - that
            # arrived in PowerShell 6 - so read it defensively. If we cannot tell
            # where it points, say so and ask, rather than guessing or crashing.
            $current = Get-Prop -Object $item -Name 'Target'
            if ($current -and (@($current) -contains $RealPath)) {
                Write-Skip "Already there"
                Add-Record "Shortcut at $LinkPath : already correct, left alone"
                return
            }
            if ($current) { Write-Warn "$LinkPath already points at $current." }
            else          { Write-Warn "$LinkPath is already a shortcut, and this PowerShell cannot read where it points." }
            if (Read-Confirm "Repoint it at $RealPath?") {
                # Removing a junction removes the link, not the files it points at.
                & cmd /c rmdir "`"$LinkPath`"" | Out-Null
            } else {
                Add-Record "Shortcut at $LinkPath : left as it was"
                return
            }
        } else {
            # Not fatal: the vault itself is fine where it is, only the shortcut
            # is missing.
            Write-Warn "$LinkPath already exists and is a real folder, so it was left alone."
            Write-Say  "  Your vault is at $RealPath and works. Use that path when adding the folder in Claude."
            Add-Record "Shortcut at $LinkPath : not created (a real folder is already there)"
            return
        }
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $RealPath -ErrorAction Stop | Out-Null
        Write-Ok "$LinkPath -> $RealPath"
        Add-Record "Shortcut: $LinkPath -> $RealPath"
    } catch {
        Write-Log ("LINK-ERR " + $_.Exception.Message)
        Write-Warn "Could not create the shortcut at $LinkPath."
        Write-Say  "  Your vault is at $RealPath and works. Use that path when adding the folder in Claude."
        Add-Record "Shortcut: not created - use $RealPath directly"
    }
}

# OneDrive's Files On-Demand leaves placeholder stubs instead of real files, and
# both Obsidian and Claude need real bytes on disk. attrib +P pins the folder.
function Set-OneDrivePin {
    param(
        [Parameter(Mandatory=$true)][string]$Provider,
        [Parameter(Mandatory=$true)][string]$RealPath
    )
    if ($Provider -ne 'OneDrive') { return }
    try { & attrib.exe +P /s /d "$RealPath" 2>&1 | Out-Null } catch { }
    $name = Split-Path -Leaf $RealPath
    Write-Say "  One thing to check in File Explorer: right-click the $name folder and"
    Write-Say "  choose ""Always keep on this device"". Without it OneDrive can replace"
    Write-Say "  notes with placeholders and Obsidian will show them as empty."
}
