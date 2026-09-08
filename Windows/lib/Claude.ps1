# Install the Claude desktop app, and put the brain skills where a session with
# the vault folder connected will find them.
#
# The desktop app, not the Claude Code CLI: almost nobody getting a brain will be
# working in a terminal, so the app is what they will actually open.

function Get-ClaudeAppPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Claude\Claude.exe'),
        (Join-Path ${env:ProgramFiles} 'Claude\Claude.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }

    # Installed but somewhere unexpected: search the Start Menu for a Claude
    # shortcut and follow it. Its target is where the app actually is.
    foreach ($menu in @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
                        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'))) {
        if (-not $menu -or -not (Test-Path $menu)) { continue }
        $lnk = Get-ChildItem -Path $menu -Recurse -Filter 'Claude*.lnk' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($lnk) {
            try {
                $target = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk.FullName).TargetPath
                if ($target -and (Test-Path $target)) { return $target }
            } catch { }
            return $lnk.FullName
        }
    }

    # Last resort: anything under the user's local app data that looks like it.
    $hit = Get-ChildItem -Path $env:LOCALAPPDATA -Recurse -Depth 3 -Filter 'Claude.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }

    return $null
}

function Install-ClaudeApp {
    Write-Step "Claude desktop app"

    $existing = Get-ClaudeAppPath
    if ($existing) {
        Write-Skip "Already installed at $existing"
        Add-Record "Claude desktop app: already installed, left alone"
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Say "  Installing via winget..."
        $wgArgs = @('install','-e','--id','Anthropic.Claude','--silent',
                    '--accept-package-agreements','--accept-source-agreements')
        & winget @wgArgs *>> (Get-LogPath)
        if (Get-ClaudeAppPath) {
            Write-Ok "Installed"
            Add-Record "Claude desktop app: installed"
            return
        }
        Write-Warn "winget could not install Claude - falling back to a direct download."
    } else {
        Write-Skip "winget not present - using a direct download instead"
    }

    Install-ClaudeAppFromExe
}

# Claude's own Windows installer is per-user and needs no admin rights.
function Install-ClaudeAppFromExe {
    $tmp = Join-Path $env:TEMP ("brain-claude-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $exe = Join-Path $tmp 'Claude-setup.exe'
    # The real installer endpoint. claude.ai/download is an HTML landing page -
    # the API redirect below is what its Windows button actually points at.
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $url  = if ($env:CLAUDE_DOWNLOAD_URL) { $env:CLAUDE_DOWNLOAD_URL }
            else { "https://claude.ai/api/desktop/win32/$arch/setup/latest/redirect" }

    Write-Say "  Downloading the Claude desktop app ($arch)..."
    if (-not (Save-Download -Url $url -Destination $exe -What "Claude desktop app")) {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Warn "Could not download Claude. Get it from https://claude.ai/download - everything else in this setup still works."
        Add-Record "Claude desktop app: NOT installed - get it from claude.ai/download"
        return
    }

    try {
        Write-Say "  Running the installer..."
        Start-Process -FilePath $exe -Wait
    } catch {
        Write-Log ("CLAUDE-ERR " + $_.Exception.Message)
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Warn "Claude's installer would not run. Get it from https://claude.ai/download."
        Add-Record "Claude desktop app: NOT installed - get it from claude.ai/download"
        return
    }

    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

    if (Get-ClaudeAppPath) {
        Write-Ok "Installed"
        Add-Record "Claude desktop app: installed"
    } else {
        Write-Warn "Claude may have installed somewhere unexpected. Look for it in the Start menu; the rest of this setup is fine either way."
        Add-Record "Claude desktop app: installed, location not confirmed"
    }
}

# The skills live inside the vault, so they travel with it: a Claude session with
# this folder connected picks them up, and there is nothing to keep in sync
# separately.
#
# Existing skills are never replaced. Someone who has edited their own copy keeps
# it, and re-running this installer will not undo their work. Pass
# -ReplaceSkills to take the shipped versions instead.
function Install-Skills {
    param(
        [Parameter(Mandatory=$true)][string]$VaultPath,
        [Parameter(Mandatory=$true)][string]$Payload,
        [Parameter(Mandatory=$true)][string]$OwnerName,
        [switch]$ReplaceSkills
    )

    Write-Step "Brain skills"

    $src = Join-Path $Payload 'skills'
    if (-not (Test-Path $src)) { Stop-Install "The installer package has no skills folder. Re-download it." }

    $dest = Join-Path $VaultPath '.claude\skills'
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

    $added = 0; $kept = 0; $replaced = 0
    foreach ($d in (Get-ChildItem -Path $src -Directory)) {
        $target = Join-Path $dest $d.Name
        if (Test-Path $target) {
            if ($ReplaceSkills) {
                Remove-Item $target -Recurse -Force
                Copy-Item -Path $d.FullName -Destination $target -Recurse -Force
                $replaced++
            } else {
                $kept++
            }
        } else {
            Copy-Item -Path $d.FullName -Destination $target -Recurse -Force
            $added++
        }
    }

    if ($added -gt 0)    { Write-Ok "$added skills installed" }
    if ($replaced -gt 0) { Write-Ok "$replaced skills replaced (-ReplaceSkills)" }
    if ($kept -gt 0) {
        Write-Skip "$kept skills already there, left exactly as they are"
        Write-Say  "  (re-run with -ReplaceSkills to take the shipped versions instead)"
    }
    Add-Record "Skills: $added added, $kept left alone, $replaced replaced"

    Build-SkillZips -VaultPath $VaultPath -Payload $Payload
    Write-ClaudeMd -VaultPath $VaultPath -OwnerName $OwnerName
}

# The desktop app only sees skills that are on the person's own claude.ai account,
# and the only way to put one there is to upload a zip of the skill folder by hand.
# So build the zips here, into the vault, ready to upload. Built at install time
# rather than shipped as binaries, so they can never drift from the SKILL.md files.
function Build-SkillZips {
    param(
        [Parameter(Mandatory=$true)][string]$VaultPath,
        [Parameter(Mandatory=$true)][string]$Payload
    )

    $src  = Join-Path $Payload 'skills'
    $dest = Join-Path $VaultPath 'Meta\Setup'
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

    $made = 0; $kept = 0
    foreach ($d in (Get-ChildItem -Path $src -Directory)) {
        $zip = Join-Path $dest ($d.Name + '.zip')
        if (Test-Path $zip) { $kept++; continue }
        try {
            # Passing the folder itself puts the folder inside the archive, which is
            # what claude.ai needs - the folder name must match the skill name or the
            # upload is rejected.
            Compress-Archive -Path $d.FullName -DestinationPath $zip -Force -ErrorAction Stop
            $made++
        } catch {
            Write-Log ("ZIP-ERR " + $_.Exception.Message)
            Write-Warn "Could not build $($d.Name).zip - you can still start setup by pasting the line in START HERE.md."
        }
    }

    if ($made -gt 0) { Write-Ok   "$made skill uploads prepared in Meta\Setup" }
    if ($kept -gt 0) { Write-Skip "$kept skill uploads already in Meta\Setup, left alone" }
    Add-Record "Skill uploads: $made built, $kept left alone"
}

# CLAUDE.md is what tells a session in this folder to read the Vault Guide. It is
# never overwritten - someone may well have added their own standing instructions
# to it.
function Write-ClaudeMd {
    param(
        [Parameter(Mandatory=$true)][string]$VaultPath,
        [Parameter(Mandatory=$true)][string]$OwnerName
    )
    $f = Join-Path $VaultPath 'CLAUDE.md'
    if (Test-Path $f) {
        Write-Skip "CLAUDE.md already there, left alone"
        Add-Record "CLAUDE.md: left alone"
        return
    }

    $body = @"
# Working in this vault

This folder is $OwnerName's context brain.

**Read ``Meta/Vault Guide.md`` before doing anything here.** It is the source of truth
for the folder structure, naming, frontmatter and the condensation pipeline. Take folder
names from it rather than assuming them.

Skills for this vault are in ``.claude/skills``:

- ``brain-setup`` - one-time setup: scans Microsoft 365 and drafts the standing-context
  notes. Run it once, on a fresh vault.
- ``vault-filing`` - run at the end of a session that produced anything worth re-reading.
- ``vault-rollup`` - weekly and monthly condensation.
- ``email-triage`` - reads the inbox and writes a ranked list of what needs an answer into
  ``Inbox``. Never sends, replies to or forwards anything.

These are plain files, so they work whether or not this Claude offers them as commands.
If ``/brain-setup`` is not offered by name, read ``.claude/skills/brain-setup/SKILL.md``
and follow it. Same for the others.

Never write a credential into a note. Every file here syncs to a cloud provider.
"@
    [System.IO.File]::WriteAllText($f, ($body -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "Wrote CLAUDE.md"
    Add-Record "CLAUDE.md: written"
}
