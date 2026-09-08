# Context brain installer — macOS

## Run it

```bash
cd ~/Downloads/MacOS
chmod +x install.sh
./install.sh --dry-run      # reports what it would do, changes nothing
./install.sh
```

No administrator rights. Do not use `sudo`. Safe to run twice: every step checks first and
never overwrites anything already there. Log: `~/Library/Logs/brain-install.log`.

| Flag | Effect |
|---|---|
| `--dry-run` | Report every decision, change nothing |
| `--replace-skills` | Also refresh skills already in the vault |
| `--replace-guide` | Also take the shipped `Meta/Vault Guide.md`, keeping the old one beside it |
| `--help` | Usage notes |

## What it does

1. Installs **Obsidian** — Homebrew, else a direct `.dmg` into `~/Applications`.
2. Installs the **Claude desktop app** — `brew install --cask claude`, else a direct `.dmg`.
3. Asks name, work email and company, and nothing about the work itself. What it produces,
   how it arrives and who it is with are all inferred later by `/brain-setup`, which has
   the mailbox to read.
4. Asks **where the vault folder goes**: two answers only — home folder (recommended), or a
   typed path. A typed path inside OneDrive or Google Drive is detected by the next
   question.
5. Asks separately **whether anything backs it up**.
6. Creates the vault, named from the email: `jsmith@example.com` → `~/jsmith-brain`.
7. Writes `.obsidian/` config and **registers the vault** with Obsidian.
8. Installs the four skills into `.claude/skills`, builds them as uploadable zips in
   `Meta/Setup`, writes `CLAUDE.md` and `START HERE.md`.
9. Prints the four steps left, all in the Claude app.

## Files

```
install.sh          entry point
lib/common.sh       output, prompts, tokens, downloads, manifest, step wrapper
lib/obsidian.sh     install Obsidian; register the vault
lib/claude.sh       install the Claude app; place skills, zips, CLAUDE.md
lib/sync.sh         the location question, then the backup question
lib/vault.sh        build or complete the vault
template/           the vault: folders, Vault Guide, templates, stubs
skills/             brain-setup, vault-filing, vault-rollup
```

## Notes for maintainers

**`template/` and `skills/` are duplicated in `Windows/`.** macOS is the source of truth.
Run `../sync-shared.sh` after changing either, then `../check.sh`.

**Never do a blanket `{{...}}` substitution.** Obsidian's own `{{title}}` placeholders live
in `template/Meta/Templates/` and must survive. `substitute_tokens` in `lib/common.sh`
replaces only the named tokens.

**Prompts read from `/dev/tty`, not stdin.** Under `curl … | bash` stdin *is* the script, so
a plain `read` swallows the rest of the installer.

**macOS ships bash 3.2.** No associative arrays, no `${var,,}`, no `mapfile`.

**`sed -i` differs between BSD and GNU.** `substitute_tokens` writes through a temp file.

**Never point a downloader at a landing page.** `obsidian.md/download` and
`claude.ai/download` are HTML pages. Versions are resolved from Obsidian's update manifest;
`download_file` rejects anything that arrives as HTML or under a megabyte.

**Only `create_vault` may fail the run.** Everything else goes through `run_step`, which
contains the failure and carries on, so the person always reaches the closing instructions.

**The folder-name rule exists twice**, here and in `Windows/lib/Common.ps1`. They must
agree, or the same person gets different folder names on their Mac and PC. Both lowercase
the email's local part, remove full stops, replace anything else outside `a-z0-9_-` with a
hyphen, collapse and trim hyphens, then append `-brain`. Re-check these nine:

| Email | Folder |
|---|---|
| `jsmith@example.com` | `jsmith-brain` |
| `A.Chen@Example.COM` | `achen-brain` |
| `j.o-neill@example.com` | `jo-neill-brain` |
| `first.last@example.com` | `firstlast-brain` |
| `UPPER.CASE.Name@example.co.uk` | `uppercasename-brain` |
| `weird+tag@example.com` | `weird-tag-brain` |
| `-lead-@example.com` | `lead-brain` |
| `..@example.com` | `my-brain` |
| `@example.com` | `my-brain` |
