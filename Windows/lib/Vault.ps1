# Create the vault from the template, or complete an existing one.
#
# The governing rule in this file: nothing that already exists is ever changed.
# A second run adds what is missing and reports what it left alone.

# A folder is a brain if it has a Vault Guide in it. That is the one file every
# vault has and nothing else does.
function Test-IsVault {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Test-Path (Join-Path $Path 'Meta\Vault Guide.md'))
}

# Look for a brain the owner already has, so a second run adopts it instead of
# creating a rival one beside it. Checks the name this install would use, the
# older plain "Brain" name, anything else matching *-brain, and the same inside
# whichever cloud folders are present. Returns the first hit, or $null.
function Find-ExistingVault {
    param([Parameter(Mandatory=$true)][string]$VaultName)

    $roots = @($env:USERPROFILE)
    foreach ($v in @($env:OneDriveCommercial, $env:OneDriveConsumer, $env:OneDrive)) {
        if ($v -and (Test-Path $v) -and ($roots -notcontains $v)) { $roots += $v }
    }
    foreach ($g in @('G:\My Drive', 'H:\My Drive')) {
        if (Test-Path $g) { $roots += $g }
    }

    foreach ($root in $roots) {
        foreach ($name in @($VaultName, 'Brain')) {
            $p = Join-Path $root $name
            if ((Test-Path $p) -and (Test-IsVault -Path $p)) { return (Resolve-VaultPath -Path $p) }
        }
        $hit = Get-ChildItem -Path $root -Directory -Filter '*-brain' -ErrorAction SilentlyContinue |
               Where-Object { Test-IsVault -Path $_.FullName } |
               Select-Object -First 1
        if ($hit) { return (Resolve-VaultPath -Path $hit.FullName) }
    }
    return $null
}

# The home-folder shortcut is checked first, and adopting it would put the
# shortcut's path into every note instead of the real one. Follow a junction
# where this PowerShell can read where it points; otherwise use what we have.
function Resolve-VaultPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $item = Get-Item -Path $Path -Force -ErrorAction Stop
        $isLink = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint
        if ($isLink) {
            $target = Get-Prop -Object $item -Name 'Target'
            if ($target) {
                $first = @($target)[0]
                if ($first -and (Test-Path $first)) { return $first }
            }
        }
    } catch { }
    return $Path
}

# Guess the sync provider from where a vault already sits, so an adopted vault's
# notes do not get told the wrong thing.
function Get-ProviderFromPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if ($Path -like '*OneDrive*')  { return 'OneDrive' }
    if ($Path -like '*My Drive*')  { return 'Google Drive' }
    return 'as already configured'
}

# A vault with real content in it is never overwritten. "Populated" means the
# owner or Claude has put something here - not merely that the template's own
# stubs exist, which they always do straight after an install.
function Test-VaultPopulated {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return $false }

    # Anything filed in a content folder.
    foreach ($d in @('Projects','Areas','Resources','Ideas','Inbox','Archive','Journal')) {
        $dir = Join-Path $Path $d
        if (-not (Test-Path $dir)) { continue }
        $hit = Get-ChildItem -Path $dir -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $true }
    }

    # Any company folder that has been started. Companies\_README.md is part of
    # the template and sits at the top of that folder, so only look deeper.
    $companies = Join-Path $Path 'Companies'
    if (Test-Path $companies) {
        $hit = Get-ChildItem -Path $companies -Directory -ErrorAction SilentlyContinue |
               ForEach-Object { Get-ChildItem -Path $_.FullName -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue } |
               Select-Object -First 1
        if ($hit) { return $true }
    }

    # A profile that has been filled in. The template ships with status: empty.
    $profile = Join-Path $Path 'Me/profile.md'
    if (Test-Path $profile) {
        if (-not (Select-String -Path $profile -Pattern '^status: empty' -Quiet)) { return $true }
    }

    return $false
}

# --- the Vault Guide, and why it is the one file that can be replaced ---------
#
# Every other note in a vault belongs to the person: a re-run adds what is missing
# and never overwrites. The Vault Guide is different. It is declared the source of
# truth for folder names and conventions, and the skills read it at run time rather
# than hard-coding them, which is what lets a convention change without anyone
# reinstalling anything. That only works if a newer guide can actually reach an
# existing vault, so the guide carries guide_version in its frontmatter and a
# re-run replaces an older one.
#
# Two rules keep that from becoming the silent damage this installer must not do:
#
#   1. The old guide is moved aside, never merged. Reconciling someone's edits with
#      a new shipped version is not something a script can get right, and a bad
#      merge to the file that governs every skill is worse than a manual
#      reconciliation. They get told where their copy went.
#   2. A guide with no guide_version is left alone. It was written by hand or
#      predates versioning, which is exactly the case when this installer adopts a
#      brain somebody built themselves. -ReplaceGuide opts in.
#
# Kept identical to MacOS/lib/vault.sh. check.sh compares the two.
#
# -LiteralPath throughout, not -Path: -Path applies wildcard rules, where a
# backslash escapes the next character and [ ] is a character class. A vault under
# "OneDrive - Company [UK]" is a real possibility and -Path would not find it.

function Get-GuideVersion {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $lines = @(Get-Content -LiteralPath $Path -TotalCount 30 -ErrorAction SilentlyContinue)
    foreach ($line in $lines) {
        if ($line -match '^guide_version:\s*([0-9]+)\s*$') { return [int]$Matches[1] }
    }
    return 0
}

function Update-VaultGuide {
    param(
        [Parameter(Mandatory=$true)][string]$RealPath,
        [Parameter(Mandatory=$true)][string]$TemplateDir,
        [Parameter(Mandatory=$true)][hashtable]$Tokens,
        [switch]$ReplaceGuide,
        [switch]$JustWritten
    )

    $src  = Join-Path $TemplateDir 'Meta\Vault Guide.md'
    $dest = Join-Path $RealPath    'Meta\Vault Guide.md'

    # A missing guide is the base note copy's job, and it has already run. A guide it
    # just wrote is current by definition, so there is nothing to say about it.
    if (-not (Test-Path -LiteralPath $src))  { return }
    if (-not (Test-Path -LiteralPath $dest)) { return }
    if ($JustWritten)           { return }

    $shipped   = Get-GuideVersion -Path $src
    $installed = Get-GuideVersion -Path $dest

    if (-not $ReplaceGuide) {
        if ($installed -eq 0) {
            Write-Skip "Vault Guide carries no version, left alone"
            Write-Say  "  Yours was written by hand or predates versioning, so the shipped guide"
            Write-Say  "  (v$shipped) was not applied. -ReplaceGuide takes it and keeps yours beside it."
            Add-Record "Vault Guide: left alone (unversioned; shipped v$shipped)"
            return
        }
        if ($shipped -le $installed) {
            Write-Skip "Vault Guide already at v$installed"
            Add-Record "Vault Guide: already v$installed"
            return
        }
    }

    $stamp = [string]$Tokens['SETUP_DATE']
    $keep  = Join-Path $RealPath "Meta\Vault Guide (previous $stamp).md"
    $n     = 2
    while (Test-Path -LiteralPath $keep) {
        $keep = Join-Path $RealPath "Meta\Vault Guide (previous $stamp-$n).md"
        $n++
    }

    try {
        Move-Item -LiteralPath $dest -Destination $keep -ErrorAction Stop
    } catch {
        Write-Warn "Could not move your Vault Guide aside, so it was left exactly as it is."
        Add-Record "Vault Guide: not updated (could not move the old one aside)"
        return
    }

    try {
        Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
        Set-Tokens -Path $dest -Tokens $Tokens
    } catch {
        Move-Item -LiteralPath $keep -Destination $dest -Force -ErrorAction SilentlyContinue
        Write-Warn "Could not write the new Vault Guide, so yours was put back."
        Add-Record "Vault Guide: not updated (copy failed, old one restored)"
        return
    }

    if ($shipped -le $installed) { Write-Ok "Vault Guide replaced with v$shipped (-ReplaceGuide)" }
    else                         { Write-Ok "Vault Guide updated, v$installed -> v$shipped" }
    Write-Say "  Your previous guide is beside it as `"$(Split-Path -Leaf $keep)`"."
    Write-Say "  Anything you had changed needs re-applying by hand."
    Add-Record "Vault Guide: v$installed -> v$shipped, previous kept as $(Split-Path -Leaf $keep)"
}

# What this vault is running, so a later run - or a person asked to describe their
# setup - can tell without guessing. A dotfile because Obsidian ignores dotfiles and
# this is machine state, not a note.
#
# Only written when something it records actually changed, so a re-run that changes
# nothing still leaves every file in the vault byte-identical.
function Write-VaultStamp {
    param(
        [Parameter(Mandatory=$true)][string]$RealPath,
        [Parameter(Mandatory=$true)][string]$TemplateDir,
        [Parameter(Mandatory=$true)][hashtable]$Tokens
    )

    $dest = Join-Path $RealPath 'Meta\.brain.json'
    $pkg  = Get-ManifestValue -ManifestPath (Join-Path $TemplateDir 'manifest.json') -Name 'packageVersion'
    if ([string]::IsNullOrWhiteSpace($pkg)) { $pkg = 'unknown' }
    $guide = Get-GuideVersion -Path (Join-Path $RealPath 'Meta\Vault Guide.md')
    # The role is not known at install time - /brain-setup works it out and writes it
    # here when it applies an overlay. So an existing value is preserved, exactly like
    # the original install date, or a re-run would undo the skill's work.
    $role = 'unset'
    $installedOn = [string]$Tokens['SETUP_DATE']
    if (Test-Path -LiteralPath $dest) {
        $existing = $null
        try { $existing = Get-Content -Raw -LiteralPath $dest | ConvertFrom-Json } catch { }
        if ($existing) {
            $prev = Get-Prop -Object $existing -Name 'installed'
            if (-not [string]::IsNullOrWhiteSpace([string]$prev)) { $installedOn = [string]$prev }
            $prevRole = Get-Prop -Object $existing -Name 'role'
            if (-not [string]::IsNullOrWhiteSpace([string]$prevRole)) { $role = [string]$prevRole }
            if (([string](Get-Prop -Object $existing -Name 'packageVersion')) -eq $pkg -and
                ([int](Get-Prop -Object $existing -Name 'guideVersion'))      -eq $guide) {
                Write-Skip "Version stamp already says package $pkg, guide v$guide"
                return
            }
        }
    }

    $json = @(
        '{',
        "  `"packageVersion`": `"$pkg`",",
        "  `"guideVersion`": $guide,",
        "  `"role`": `"$role`",",
        "  `"installed`": `"$installedOn`",",
        "  `"stamped`": `"$([string]$Tokens['SETUP_DATE'])`"",
        '}'
    ) -join "`n"
    [System.IO.File]::WriteAllText($dest, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "Version stamp: package $pkg, guide v$guide"
    Add-Record "Version stamp: package $pkg, guide v$guide"
}

function New-Vault {
    param(
        [Parameter(Mandatory=$true)][string]$RealPath,
        [Parameter(Mandatory=$true)][string]$Payload,
        [Parameter(Mandatory=$true)][hashtable]$Tokens,
        [switch]$ReplaceGuide
    )

    Write-Step "Vault"

    $tpl = Join-Path $Payload 'template'
    if (-not (Test-Path $tpl)) { Stop-Install "The installer package has no template folder. Re-download it." }
    $manifest = Join-Path $tpl 'manifest.json'
    if (-not (Test-Path $manifest)) { Stop-Install "The installer package has no template\manifest.json. Re-download it." }

    $repairOnly = $false
    if (Test-VaultPopulated -Path $RealPath) {
        Write-Say "  There is already a vault with notes in it at $RealPath."
        Write-Say "  Nothing in it gets changed. Anything missing is added; everything"
        Write-Say "  else is left exactly as it is."
        $repairOnly = $true
    }

    if (-not (Test-Path $RealPath)) { New-Item -ItemType Directory -Path $RealPath -Force | Out-Null }

    # Folders come from the manifest so there is one source of truth for the shape.
    # @() so an empty or single-item result still behaves like an array; a bare
    # $null.Count is a terminating error under Set-StrictMode -Version 2.0.
    $folders = @(Get-ManifestFolders -ManifestPath $manifest)
    if ($folders.Count -eq 0) { Stop-Install "Could not read the folder list from template\manifest.json." }
    foreach ($f in $folders) {
        $p = Join-Path $RealPath ($f -replace '/', '\')
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    Write-Ok "$($folders.Count) folders"

    # Obsidian settings: only ever written when missing. They look like config
    # rather than content, but people change them - attachment folder, link
    # style, which core plugins are on - and clobbering that is exactly the kind
    # of silent damage this installer must not do.
    $obsDest = Join-Path $RealPath '.obsidian'
    if (-not (Test-Path $obsDest)) { New-Item -ItemType Directory -Path $obsDest -Force | Out-Null }
    $oAdded = 0; $oKept = 0
    foreach ($f in (Get-ChildItem -Path (Join-Path $tpl '.obsidian') -Filter '*.json' -ErrorAction SilentlyContinue)) {
        $target = Join-Path $obsDest $f.Name
        if (Test-Path $target) { $oKept++; continue }
        Copy-Item $f.FullName $target -Force
        $oAdded++
    }
    if ($oKept -gt 0) { Write-Skip "Obsidian settings already there ($oKept files), left alone" }
    else              { Write-Ok "Obsidian settings" }
    Add-Record "Obsidian settings: $oAdded written, $oKept left alone"

    # Notes: never overwrite one that already exists.
    $copied = 0; $kept = 0; $guideJustWritten = $false
    # roles\ holds the per-role overlays, not vault content. Add-StagedRoleOverlays
    # stages them under Meta\.roles; none of them is a note in this vault yet.
    $rolesDir = Join-Path $tpl 'roles'
    foreach ($file in (Get-ChildItem -Path $tpl -Recurse -File -Filter '*.md' |
                       Where-Object { $_.FullName -notlike ($rolesDir + '*') } |
                       Sort-Object FullName)) {
        $rel  = $file.FullName.Substring($tpl.Length).TrimStart([char]'\', [char]'/')
        $dest = Join-Path $RealPath $rel
        if (Test-Path $dest) { $kept++; continue }
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $file.FullName $dest -Force
        Set-Tokens -Path $dest -Tokens $Tokens
        $copied++
        if ($rel -eq 'Meta\Vault Guide.md') { $guideJustWritten = $true }
    }
    if ($kept -gt 0) { Write-Ok "$copied notes written, $kept already there" }
    else             { Write-Ok "$copied notes written" }
    Add-Record "Template notes: $copied written, $kept already there"

    Add-StagedRoleOverlays -RealPath $RealPath -TemplateDir $tpl -Tokens $Tokens
    Update-VaultGuide -RealPath $RealPath -TemplateDir $tpl -Tokens $Tokens `
                      -ReplaceGuide:$ReplaceGuide -JustWritten:$guideJustWritten
    Write-VaultStamp  -RealPath $RealPath -TemplateDir $tpl -Tokens $Tokens

    Write-Welcome -RealPath $RealPath -Tokens $Tokens
}

# --- role extras, staged rather than applied ---------------------------------
#
# What someone's work mainly produces decides which extra folders and templates
# their vault wants: Assets\ for someone who builds things, Reporting\ for someone
# who produces numbers, a friction vocabulary for someone whose job is other people
# working better.
#
# The installer does not know the answer and does not ask. A cold multiple-choice
# question in a terminal gets a guess, and this is the answer that changes the folder
# structure, so it is the last one that should be guessed. /brain-setup works it out
# from the mailbox, the calendar and Teams, states its read with the evidence, and
# applies the overlay the person confirms.
#
# So the installer's job is to put every overlay where the skill can reach it, with
# tokens already substituted so the skill never has to know about tokens:
#
#   <vault>\Meta\.roles\<key>\folders.txt   folders to create
#   <vault>\Meta\.roles\<key>\files\**      templates to copy into place
#
# A dotfolder, because Obsidian ignores dotfolders and this is not vault content
# until one of them is applied. All five stay after one is applied, so a person
# whose work changes can have another applied later without reinstalling.
#
# Kept identical to MacOS/lib/vault.sh. check.sh compares the two.
function Add-StagedRoleOverlays {
    param(
        [Parameter(Mandatory=$true)][string]$RealPath,
        [Parameter(Mandatory=$true)][string]$TemplateDir,
        [Parameter(Mandatory=$true)][hashtable]$Tokens
    )

    $src = Join-Path $TemplateDir 'roles'
    if (-not (Test-Path -LiteralPath $src)) { return }
    $destRoot = Join-Path $RealPath 'Meta\.roles'

    $added = 0; $kept = 0
    foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File | Sort-Object FullName)) {
        $rel  = $f.FullName.Substring($src.Length).TrimStart([char]'\', [char]'/')
        $dest = Join-Path $destRoot $rel
        if (Test-Path -LiteralPath $dest) { $kept++; continue }
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        if ($f.Extension -eq '.md') { Set-Tokens -Path $dest -Tokens $Tokens }
        $added++
    }

    $keys = @(Get-ChildItem -LiteralPath $src -Directory).Count

    if ($added -gt 0) { Write-Ok   "$keys sets of role extras staged for /brain-setup to apply" }
    else              { Write-Skip "role extras already staged ($kept files), left alone" }
    Add-Record "Role extras staged: $added written, $kept already there, $keys sets"
}

function Write-Welcome {
    param(
        [Parameter(Mandatory=$true)][string]$RealPath,
        [Parameter(Mandatory=$true)][hashtable]$Tokens
    )

    $welcome = Join-Path $RealPath 'WELCOME.md'
    if (Test-Path $welcome) {
        Write-Skip "WELCOME.md already there, left alone"
        Add-Record "WELCOME.md: left alone"
        return
    }

    $vaultPath = $Tokens['VAULT_PATH']
    $body = @"
# Welcome to your brain

This is your context brain: an ordinary folder of markdown notes that both you and Claude
can read and write. It is yours, it lives in your own storage, and nobody else reads it.

Right now it is an empty structure. Four short steps and Claude fills it in. They all
happen in the **Claude app** - you do not need a command line for any of it.

There is a fuller version of this in `START HERE.md` beside this file.

## 1. Open Claude and sign in

Open **Claude** from the Start menu and sign in with your work account.

## 2. Connect Microsoft 365

In Claude, go to **Settings > Connectors**, find **Microsoft 365** and click **Connect**,
then sign in with your work account. Your IT team has already authorised it for the
organisation, so you should not see a permissions screen you cannot approve.

This is what lets Claude read your own sent mail and calendar to work out how you write
and who you work with. It reads as you, over data you can already see, and only after you
have said yes to each source.

## 3. Add the three brain skills to your account

They teach Claude how to work with this vault, and they go on **your own** Claude
account. Three small files are waiting in ``Meta\Setup`` in this folder.

In Claude: **Customize > Skills > + > Create skill > Upload a skill**, then upload
``brain-setup.zip``, ``vault-filing.zip`` and ``vault-rollup.zip`` in turn.

Claude only sees skills that are on your own account, and nothing can put them there
from outside. Three uploads, once, and they are yours for good.

## 4. Add this folder and set the brain up

Start a new chat and **add this folder** - ``$vaultPath`` - using the folder or **+**
button, so Claude can read and write your notes. Then type:

``````
/brain-setup
``````

Claude will tell you exactly what it wants to read before it reads anything, draft your
profile, writing style, the companies and people you deal with and what you appear to be
working on, then ask you about the parts it could not work out.

Skipped step 3? Paste this instead and it still works:

> Read ``.claude/skills/brain-setup/SKILL.md`` in this folder and follow it.

Do go back and do step 3 though - ``vault-filing`` and ``vault-rollup`` have to be on
your account to run on their own.

## Then what

- Read ``Meta/Vault Guide.md`` once. It is the contract between you and Claude for this
  vault, and if you disagree with something in it, change it - it is the source of truth.
- At the end of a working session with Claude, ask it to file the session, and it writes a
  note into ``Journal/Sessions``. Those condense into weekly and monthly reviews, so
  detail becomes summary on its own.
- Put anything you are not sure where to file into ``Inbox``.
- Your notes also open in **Obsidian**, which is the nicer way to read and link them.

Set up $($Tokens['SETUP_DATE']). Sync: $($Tokens['SYNC_PROVIDER']).
"@

    [System.IO.File]::WriteAllText($welcome, ($body -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "WELCOME.md"
    Add-Record "WELCOME.md: written"
}
