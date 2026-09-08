# Context brain installer

Sets up a personal AI context brain on a Mac or a PC: an Obsidian vault of markdown
notes, the Claude desktop app, and three skills that populate and maintain the vault from
the person's own Microsoft 365 account.

Works for anyone at any organisation. Nothing in it is specific to one company.

**Zip `MacOS/` or `Windows/` and send it.** Each folder is self-contained.

## How people get it

Send them one link: **https://sistergroup.github.io/install-brain/**

It asks whether they are on a Mac or a PC and gives them the commands for that one. The
page and both archives are rebuilt and republished by `.github/workflows/pages.yml` on
every push that touches `MacOS/`, `Windows/` or `site/`, so the link is always the current
build and nobody ends up running a copy from their Downloads folder.

Both installers carry that site as their default `BRAIN_PACKAGE_URL`, so a piped run works
with no setup:

```bash
curl -fsSL https://sistergroup.github.io/install-brain/install.sh | bash
```

```powershell
irm https://sistergroup.github.io/install-brain/install.ps1 | iex
```

The site does not lead with that, and neither should you. It pipes a remote script into a
shell, the person never sees what they are about to run, and `--dry-run` is unavailable
because a script arriving on stdin cannot take arguments. The two-step the site gives
instead lands the archive on disk where it can be read first, at the cost of one line.

## Run it from a folder

**macOS** — unzip the `MacOS` folder, then in Terminal:

```bash
cd ~/Downloads/MacOS
chmod +x install.sh
./install.sh --dry-run      # reports what it would do, changes nothing
./install.sh
```

**Windows** — unzip the `Windows` folder, then in PowerShell:

```powershell
cd $env:USERPROFILE\Downloads\Windows
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`Unblock-File` clears the downloaded-from-the-internet flag. Without it the five
dot-sourced files in `lib\` can be refused.

Run `--dry-run` / `-DryRun` first on any machine that already has notes on it.

| Flag | Effect |
|---|---|
| `--dry-run` / `-DryRun` | Report every decision, change nothing |
| `--replace-skills` / `-ReplaceSkills` | Also refresh skills already in the vault |
| `--replace-guide` / `-ReplaceGuide` | Also take the shipped Vault Guide, keeping the old one beside it |
| `--help` (macOS) | Usage notes |

No administrator rights needed. Do not use `sudo`. Logs go to
`~/Library/Logs/brain-install.log` and `%LOCALAPPDATA%\Brain\install.log`.

## What the installer does

1. Installs **Obsidian** and the **Claude desktop app**, skipping either if present.
2. Asks the person's name, work email and company. Nothing about the work itself: what it
   produces, how it arrives and who it is with are all inferred from the mailbox scan by
   `/brain-setup`, then confirmed.
3. Asks **where the vault folder goes** — two answers: the home folder (recommended), or a
   path they type. A typed path inside OneDrive or Google Drive is picked up by the next
   question, so cloud locations still work; they are just not listed.
4. Asks, separately, **whether anything backs it up**.
5. Creates the vault, named from their email: `jsmith@example.com` → `jsmith-brain`.
6. Registers it with Obsidian so the app can open it.
7. Installs four skills into the vault and builds them as uploadable zips in `Meta/Setup`.
8. Prints the four steps the person completes in the Claude app.

Re-running is safe. A note, a skill and an Obsidian setting are never overwritten. Only the
vault itself can fail the run; every other step warns and carries on.

The one file a re-run may replace is `Meta/Vault Guide.md`, which carries a `guide_version`
in its frontmatter. Every skill reads its conventions from that file at run time, so a
convention change has to be able to reach a vault that already exists. A newer shipped
guide replaces an older installed one, and the old copy is kept beside it as
`Meta/Vault Guide (previous <date>).md`. A guide with no version, meaning hand-written or
from before versioning, is left alone unless `--replace-guide` says otherwise. Every vault
also carries `Meta/.brain.json` recording the package and guide versions it is on.

## What the person does after it

In the Claude app: sign in, connect Microsoft 365, upload the skill zips from `Meta/Setup`
to their own account, then add the vault folder to a chat and run `/brain-setup`.
`START HERE.md` in the vault walks them through it.

The four skills: **`brain-setup`** populates the vault once; **`vault-filing`** writes a
session note at the end of a working session; **`vault-rollup`** condenses those weekly and
monthly; **`email-triage`** reads the inbox each morning and writes a ranked list of what
actually needs an answer. It never sends, replies to or forwards anything.

The skill uploads cannot be automated — see `docs/SKILLS-SETUP.md`.

## Before you push

```bash
./sync-shared.sh  # copies template/ and skills/ from MacOS to Windows
./check.sh        # verifies both folders are complete and consistent
```

macOS is the source of truth for `template/` and `skills/`. Both folders carry a copy so
each ships standalone, and `check.sh` diffs them so drift fails rather than shipping.

CI runs `check.sh` before it builds anything, so a push that breaks it publishes nothing.
It also refuses to deploy if `dist/` holds anything other than the expected files, which
is what stops a stray file reaching a public website.

**This repo is public.** Working notes go in `docs/brainstorms/` and `docs/sessions/`,
both gitignored, and `check.sh` fails if either is ever tracked. Anything naming a real
person, the organisation, a plan tier or a policy status belongs in a context brain, not
here.

## Layout

```
MacOS/          complete macOS package
Windows/        complete Windows package
check.sh        verify before sharing
sync-shared.sh  keep the shared payload identical
ARCHITECTURE.md how it works, and what cannot be automated
BUILD-PLAN.md   what is proven, what is not, how to release
docs/           IT prerequisites; how the skills reach people
```
