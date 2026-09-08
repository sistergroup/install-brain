# Architecture

## The split

Setting up a context brain is two jobs. One is mechanical — install two apps, make folders,
write config — and a shell script does it perfectly. The other is judgement: read someone's
mailbox, work out who they are, how they write, which of their correspondents matter, which
threads are projects. No script can do that; Claude can.

So the installer is deliberately dumb, and its last act is to hand over to a skill.

```
  the installer            →  installs Obsidian and the Claude app, creates the vault
  (install.sh / .ps1)         from a tokenised template, registers it with Obsidian,
                              builds the skill zips. No intelligence.

  /brain-setup             →  consent, scan Microsoft 365, draft, confirm by exception,
  (a Claude skill)            wire up the ongoing loop. All judgement.

  vault-filing             →  a session note at the end of each session; weekly and
  vault-rollup                monthly condensation.

  email-triage             →  reads the inbox on a schedule and writes a ranked list of
                              what needs an answer. Never sends anything.
```

## What cannot be automated

Four things the person does themselves, all in the Claude app:

1. **Sign in to Claude.**
2. **Connect Microsoft 365.** One click in Settings → Connectors, then a Microsoft
   sign-in. An admin must grant org-wide consent first (`docs/IT-PREREQS.md`) or the
   connector is unavailable.
3. **Upload the skills to their own Claude account.** About a minute. This one is a
   platform limit rather than a consent decision — see *How the skills reach people*.
4. **Add the vault folder to a chat.**

So: one command, then a few minutes of clicking. Steps 1, 2 and 4 are consent decisions and
always will be.

## The installer, step by step

Idempotent throughout. Nothing that exists is changed.

1. **Detect** what is installed and whether a brain already exists.
2. **Install Obsidian** — Homebrew then a direct `.dmg` on macOS; `winget --scope user`,
   then winget's default, then the per-user `.exe` with `/S` on Windows.
3. **Install the Claude desktop app** — `brew install --cask claude`;
   `winget install -e --id Anthropic.Claude`, a per-user EXE needing no admin.
   Download URLs are resolved at run time from Obsidian's own update manifest and Claude's
   installer endpoint. Landing pages are not download URLs: every download is rejected if
   it starts with `<!doctype`/`<html` or weighs under a megabyte.
4. **Create the vault** from `template/`. The folder list comes from
   `template/manifest.json`, so neither installer hard-codes the shape.
5. **Write `.obsidian/` config** — new notes into `Inbox`, attachments into
   `Meta/Attachments`, wikilinks not markdown links, Templates plugin pointed at
   `Meta/Templates`.
6. **Register the vault** by adding an entry to Obsidian's own config
   (`~/Library/Application Support/obsidian/obsidian.json`, `%APPDATA%\obsidian\obsidian.json`).
   Obsidian must not be running; the entry gets `open: false` when other vaults exist, so
   whichever vault the person currently opens keeps opening.
7. **Place it for sync** and add a home-folder shortcut if the vault lives elsewhere.
8. **Install the skills** into `<vault>/.claude/skills`, build them as zips in
   `Meta/Setup`, and write `CLAUDE.md` and `START HERE.md`.
9. **Hand over** — print the four remaining steps, offer to open Claude.

### Naming

The vault folder is the local part of the work email, lowercased, full stops removed, plus
`-brain`. `jsmith@example.com` → `jsmith-brain`; `a.chen@example.com` → `achen-brain`. Full
stops are removed rather than hyphenated so every name reads as one convention and no folder
name can be mistaken for a file. An unusable email falls back to `my-brain`.

The rule is implemented twice, once per language, and must stay identical — see the platform
READMEs for the test cases.

### Nothing asked about the work, three things inferred

The installer asks for a name, a work email, a company, and where to put the folder. It
asks nothing about the work itself. Three things about the work shape the vault, and all
three are inferred by `/brain-setup` from the mailbox, the calendar and Teams, then stated
back with the evidence and confirmed.

**What the work mainly produces** is the one that changes the folder structure — documents
and decisions, things they build and keep running, numbers and analysis, creative material,
or other people working better.

| Answer | Key | Adds |
|---|---|---|
| Documents, decisions and plans | `documents` | nothing — the base vault is already this |
| Things you build and then keep running | `assets` | `Assets/`, an `Asset` template |
| Numbers, reports and analysis | `reporting` | `Reporting/`, a `Recurring Report` template |
| Creative or editorial material | `creative` | `Resources/References/`, a `Reference` template |
| Other people working better | `enabling` | `Assets/`, `Meta/Friction Vocabulary.md`, and its own `Person` and `Asset` templates |

A role **only ever adds**, so nobody's vault is missing a place to put something.

**The installer stages all five and applies none.** It copies `template/roles/` into
`<vault>/Meta/.roles/`, substituting tokens as it goes so the skill never has to know that
tokens exist. `/brain-setup` then creates the folders in `Meta/.roles/<key>/folders.txt`
and copies `Meta/.roles/<key>/files/` into the vault at the same relative paths. A
dotfolder, because Obsidian ignores dotfolders and none of it is vault content until one
set is applied. `roles/` is excluded from the base note copy, so no overlay ever arrives as
a note by accident.

On a fresh vault a role's template **replaces** the base one of the same name, which is how
`enabling` ships a `Person.md` carrying a `## Friction` section. On a vault that is not
fresh the skill leaves an edited file alone and says which.

All five stay staged after one is applied. A person whose work changes, or whose read was
wrong, can have a different set applied later without reinstalling anything, and
`Meta/.brain.json` records which one is in force. The installer preserves that field on a
re-run rather than resetting it.

**Why this moved out of the installer.** It used to be one multiple-choice question in the
terminal, on the grounds that people know the answer instantly. They do, but the answer
decides the folder structure, and asking it first meant the structure was set before
anything had looked at the evidence. The trade is real and worth stating: thread shapes and
domain splits are strong signals, while what someone's work produces is the thinnest of the
three reads — a producer, a post supervisor and a finance analyst all send similar-looking
mail, and the signal is mostly in attachment types and document names. So the skill is
required to state its read with the evidence and offer all five options rather than ask for
a nod, to say plainly when the mail does not point one way, and to leave the other four
sets staged so a wrong answer costs a minute rather than a reinstall.

The `enabling` overlay is the one that adds a convention rather than just a folder. Its
`Meta/Friction Vocabulary.md` fixes nine words for kinds of friction (`repetition`,
`handoff`, `finding`, and so on) so that the same problem described five different ways by
five people is still countable as one. Its `Person` template asks for friction quoted and
tagged; its `Asset` template asks which friction the thing solves and whose. That join —
same vocabulary on both sides — is what makes "three people hit `handoff` on this report" a
finding rather than a hunch.

**The other two inferences.** How the work arrives — discrete jobs that finish, or ongoing
responsibilities that do not — and who it is with — mostly outside the company, mostly
inside, or mostly systems and data. Both come from thread shapes, recurring calendar
entries and the domain split of sent mail, and neither changes a folder: they change where
the weight goes, which of `Projects` and `Areas` fills up, and whether `Companies/` is the
spine or a footnote.

### Tokens

`{{OWNER_NAME}}` · `{{OWNER_EMAIL}}` · `{{COMPANY_NAME}}` · `{{VAULT_NAME}}` ·
`{{VAULT_PATH}}` · `{{SYNC_PROVIDER}}` · `{{SYNC_LOCATION}}` · `{{SETUP_DATE}}`

Substituted in the staged role extras too, at staging time, so `/brain-setup` copies
finished files rather than templates.

Substitution is by explicit token name, never a blanket `{{...}}` match: Obsidian's own
`{{title}}` placeholders live in `template/Meta/Templates/` and must survive into the
installed vault. `check.sh` tests this.

## The vault

```
<name>-brain/
├── START HERE.md          the four steps, for the person
├── WELCOME.md             the short version
├── CLAUDE.md              points any Claude session at the Vault Guide
├── Archive/               completed or dormant; nothing is deleted, it moves here
├── Areas/                 ongoing responsibilities, no end date
├── Companies/             one folder per company they work with, each a profile.md
├── Ideas/                 atomic permanent notes, Zettelkasten-style; MOCs/ for maps
├── Inbox/                 unfiled capture
├── Journal/               Sessions/ → Weekly/ → Monthly/
├── Me/                    profile.md, style.md, method.md
├── Meta/                  Vault Guide.md, Templates/, Attachments/, Setup/
├── People/                one note per person, flat; company: says who they work for
├── Projects/              things with an outcome and an end date
└── Resources/             reference material
```

Three things are load-bearing:

- **No number prefixes, and nothing hard-codes a folder's position.** The structure can be
  reshuffled without breaking a skill, a link or a scheduled task.
- **`Me/method.md` is where judgement lives** — reusable approaches, positions held, and
  what the person has changed their mind about. `profile.md` is who they are and `style.md`
  is how they write; `method.md` is the part that would be hardest to reconstruct. The scan
  fills in only what it can evidence and leaves the rest for them.
- **`Meta/Vault Guide.md` is the source of truth**, not the skills. Skills read folder names
  and conventions from it at run time, so a person can reorganise their vault without their
  Claude breaking — and conventions can be updated without anyone re-uploading a skill.
  That last part only works if a newer guide can reach a vault that already exists, so the
  guide carries `guide_version` in its frontmatter and a re-run replaces an older one. The
  old copy is moved aside rather than merged: reconciling someone's edits with a new
  shipped version is not something a script can get right, and a bad merge to the file that
  governs every skill is worse than a manual reconciliation. A guide with no version was
  written by hand or predates versioning — the case when this installer adopts a brain
  somebody built themselves — and is never touched without `--replace-guide`. Alongside it,
  `Meta/.brain.json` records the package and guide versions the vault is on, so a later run,
  or a person asked what they are running, does not have to guess.
- **Every `profile.md` carries its display name in `aliases`.** Filenames are not unique —
  every company has a `profile.md` — so the alias is what makes a `[[Company Name]]` link
  resolve.

## Running it twice

Nothing that already exists is changed. Every step checks first, skips what is there, and
says which.

| Step | If it already exists |
|---|---|
| Obsidian, the Claude app | Skipped. Nothing reinstalled or upgraded. |
| Vault folders | `mkdir -p`; missing ones appear, existing untouched. |
| Template notes | Skipped per file. An edited `Me/profile.md` is never overwritten. |
| `.obsidian/*.json` | Skipped per file. People change these. |
| Skills and their zips | Skipped. `--replace-skills` opts into the shipped versions. |
| `Meta/Vault Guide.md` | **The one exception.** Replaced when the shipped version is newer, with the old copy kept beside it. An unversioned guide is left alone unless `--replace-guide`. |
| `Meta/.brain.json` | Rewritten only when the package or guide version it records has changed. The `role` field, which `/brain-setup` writes, is preserved. |
| `Meta/.roles/` | Skipped per file. Staged once and left alone, including after a role has been applied. |
| `CLAUDE.md`, `WELCOME.md`, `START HERE.md` | Skipped. People add their own notes to these. |
| Obsidian registration | Skipped if already registered. |
| The shortcut | Skipped if it already points at the right place. |

It also **looks for a brain the person already has** — the name it would use, the older plain
`Brain`, anything `*-brain`, and the same inside any cloud folder — and offers to use that
and add only what is missing. A folder counts as a brain if it has a `Meta/Vault Guide.md`.
Shortcuts are resolved, so adopting a vault through one does not write the shortcut's path
into every note.

**Only the vault can fail the run.** Every other step is wrapped: it warns, records, and
carries on, so the person always reaches the instructions for what to do next.

`--dry-run` / `-DryRun` reports all of the above and changes nothing.

## Location and backup

Two separate questions, in this order.

**1. Where should the folder go?** Two answers: the home folder (recommended — always
exists, always writable, no dependency on a cloud client), or a path they type. A typed path
must be absolute, exist, be writable and not be inside the system; three bad answers falls
back to the home folder.

Cloud folders are not offered as options. A list of every OneDrive and Google Drive root on
the machine made a simple question look complicated, and it was never load-bearing: a typed
path inside one of them is detected by question 2 exactly the same way, so putting the vault
in a cloud folder still works and is still told to the person, in the guidance on this
question rather than as menu items.

**2. Should anything back it up?** Asked whatever the location. One constraint is stated
rather than hidden: **OneDrive only syncs what is inside the OneDrive folder**, while
**Google Drive Desktop can mirror any folder**. So a folder already inside a cloud folder
is told it is already synced; a folder elsewhere is offered a Drive mirror or nothing, with
one line explaining why OneDrive is not on the list. A OneDrive folder can still be given a
Drive mirror on top — warned about two clients on one folder, and confirmed.

**The folder's real path is the canonical one.** Every note and instruction uses it, so what
the person reads matches what they type into Claude's folder picker. A shortcut at
`~/<name>-brain` is added when the vault lives elsewhere — a symlink on macOS, a directory
junction on Windows, which needs no admin rights. The shortcut failing is a warning.

Two traps: OneDrive's Files On-Demand leaves placeholders where real bytes are needed, so
the folder is pinned and the person is told to set "Always keep on this device" anyway; and
Windows accepts `/` and `\` interchangeably, so "is this inside OneDrive?" normalises both
sides before comparing.

## How the skills reach people

There are two different things called skills, and only one reaches the Claude desktop app:

| | Where it lives | How it gets there |
|---|---|---|
| Account skills | `~/.claude/skills/synced/…` | Enabled on the person's claude.ai account, synced at session start. **What the desktop app uses.** |
| Folder skills | `<folder>/.claude/skills/…` | Files. Read by Claude Code. **Ignored by the desktop app.** |

A skill placed in a folder added to the desktop app is not offered — tested. Account skills
are, and can only be added by uploading a zip in the Claude interface. No script can do it.

So the installer builds the three zips into `Meta/Setup` at install time — built rather than
shipped, so they cannot drift from the `SKILL.md` files — and the person uploads them at
**Customize → Skills → + → Create skill → Upload a skill**. The zip must contain the skill
folder, and the folder name must match the skill name.

**`brain-setup` is optional; the other two are not.** `brain-setup` runs once, and
`START HERE.md` gives a line to paste that does the same job with no upload. `vault-filing`
and `vault-rollup` have to fire on their own — a skill not on the account never triggers by
itself — so without them nothing gets written up unless the person asks every time.

**Updates.** Once people hold their own copies there is no central switch. That is why the
skills read their conventions from `Meta/Vault Guide.md` at run time: anything likely to
change belongs in the guide, which lives in the vault, and the skills stay thin and stable.

## What `/brain-setup` does

1. **Consent and scope.** States what it wants to read before reading anything. Sent email
   is the minimum; Teams, calendar and documents are opt-in. Asks what to exclude. Records
   the answers in `Meta/Setup Log.md` before scanning.
2. **Scan**, capped at roughly 90 days and 200 sent messages — enough for a confident style
   read without being slow or vague.
3. **Settle what the work produces** — state the read from the scan with its evidence,
   offer all five options rather than ask for a nod, then apply that one set from
   `Meta/.roles/`: create its folders, copy its files into place, record the key in
   `Meta/.brain.json` and one line in `Me/method.md`. Before drafting, because it decides
   which `Person` template the rest of the run uses.
4. **Draft** `Me/profile.md`, `Me/style.md`, a `Companies/<Company>/profile.md` for each
   company with real traffic, flat `People/` notes for the top correspondents, and `Projects/`
   notes for recurring subjects that look like projects.
5. **Confirm by exception** — ask only what the scan could not settle, as multiple choice
   where possible. Which candidates are really projects; which companies they actually work
   with; what they are working on that email would not show.
6. **Guardrails**, as hard rules: working relationships only in `People/`; skip HR, Legal,
   Payroll, Occupational Health and Recruitment by sender; never quote a private message
   verbatim; no credentials; when in doubt leave it out.
7. **Wire up the loop** and write the first session note.

If the scan is declined, or the connector is unavailable, it interviews the person instead.

## Privacy

Building a profile by reading a mailbox is defensible and useful, and generates a bad
conversation if it is discovered rather than announced.

- The scan runs **as the person**, on their own consent, over data they can already see.
- Nothing is scanned until they have seen the list and agreed.
- The exclusion rules are in the skill, not in a guideline document.
- The vault is theirs, in their own storage, and nobody else reads it.
- It needs a line in whatever AI use policy applies, and whoever owns data protection
  should see it before the first non-pilot install.
