# Context brain installer — Windows

## Run it

```powershell
cd $env:USERPROFILE\Downloads\Windows
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`Unblock-File` clears the downloaded-from-the-internet flag. `-ExecutionPolicy Bypass`
covers the main script but the five dot-sourced files in `lib\` are where that flag usually
bites.

No administrator rights. Safe to run twice: every step checks first and never overwrites
anything already there. Log: `%LOCALAPPDATA%\Brain\install.log`.

| Flag | Effect |
|---|---|
| `-DryRun` | Report every decision, change nothing |
| `-ReplaceSkills` | Also refresh skills already in the vault |
| `-ReplaceGuide` | Also take the shipped `Meta\Vault Guide.md`, keeping the old one beside it |

## What it does

1. Installs **Obsidian** — `winget --scope user`, then winget's default, then Obsidian's own
   per-user `.exe` with `/S`.
2. Installs the **Claude desktop app** — `winget install -e --id Anthropic.Claude`, a
   per-user EXE, else a direct download.
3. Asks name, work email and company, and nothing about the work itself. What it produces,
   how it arrives and who it is with are all inferred later by `/brain-setup`, which has
   the mailbox to read.
4. Asks **where the vault folder goes**: two answers only — home folder (recommended), or a
   typed path. A typed path inside OneDrive or Google Drive is detected by the next
   question.
5. Asks separately **whether anything backs it up**.
6. Creates the vault, named from the email: `jsmith@example.com` →
   `%USERPROFILE%\jsmith-brain`.
7. Writes `.obsidian\` config and **registers the vault** in
   `%APPDATA%\obsidian\obsidian.json`.
8. Installs the four skills into `.claude\skills`, builds them as uploadable zips in
   `Meta\Setup`, writes `CLAUDE.md` and `START HERE.md`.
9. Prints the four steps left, all in the Claude app.

## Files

```
install.ps1         entry point
lib\Common.ps1      output, prompts, tokens, downloads, manifest, step wrapper
lib\Obsidian.ps1    install Obsidian; register the vault
lib\Claude.ps1      install the Claude app; place skills, zips, CLAUDE.md
lib\Sync.ps1        the location question, then the backup question
lib\Vault.ps1       build or complete the vault
template\           identical to MacOS\template
skills\             identical to MacOS\skills
```

## Notes for maintainers

**Written for Windows PowerShell 5.1**, which is what ships with Windows. No PowerShell 7
syntax — no `?:`, no `??`.

**`Set-StrictMode -Version 2.0` makes a missing property a terminating error**, not `$null`,
and `$ErrorActionPreference` is `Stop`. Never dot-access a property that might not exist —
anything from `ConvertFrom-Json`, `Get-Item`, or a shape you did not write. Use `Get-Prop`.
Two more of the same family: a function returning an empty array yields `$null`, so wrap
such calls in `@()` before `.Count`; and `Join-Path` throws on a null environment variable,
so check before using one.

**`DirectoryInfo.Target` does not exist in PowerShell 5.1** — it arrived in 6. Reading a
junction's target needs `Get-Prop`, and the code must work when it comes back empty.

**Only `New-Vault` may fail the run.** Everything else goes through `Invoke-Step`, which
catches, warns, records and carries on, so the person always reaches the closing
instructions.

**Junction, not symbolic link.** A junction needs no administrator rights. Removing one with
`rmdir` removes the link, not the files behind it.

**Path separators.** Windows accepts `/` and `\` interchangeably and environment variables
arrive with either, so any "is this path inside that one?" test normalises both sides first.

**Notes are written LF with no BOM.** A BOM breaks YAML frontmatter parsing.

**Never do a blanket `{{...}}` substitution.** Obsidian's own `{{title}}` placeholders live
in `template\Meta\Templates\` and must survive.

**`template\` and `skills\` are copies from `MacOS`.** Change them there, run
`..\sync-shared.sh`, then `..\check.sh`.

**The folder-name rule exists twice** — see the macOS README for the rule and its nine test
cases. They must agree, or the same person gets different folder names on each machine.
