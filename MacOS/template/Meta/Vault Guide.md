---
type: meta
tags: [meta]
updated: {{SETUP_DATE}}
guide_version: 1
---

# Vault Guide

The contract between {{OWNER_NAME}} and Claude for this vault. Any Claude session with
this folder connected reads this file first and follows it. If a convention here is
wrong, change this file — it is the source of truth, and skills take folder names from
it rather than hard-coding them.

## Structure

| Folder | Holds |
|---|---|
| `Inbox` | Unfiled capture. Should be empty most of the time. |
| `Projects` | Things with an outcome and an end date. One note per project. |
| `Areas` | Ongoing responsibilities with no end date. |
| `Resources` | Reference material, research, things that are useful but not owned. |
| `Archive` | Completed or dormant. Nothing is deleted, it moves here. |
| `Ideas` | Atomic permanent notes, Zettelkasten-style — one idea each, heavily linked. `MOCs/` holds maps of content. Their frontmatter `type` stays `zettel`: the folder is named for what it holds, the type for the method. |
| `Me` | `profile.md` (role, remit, how Claude works with you) and `style.md` (how you write). |
| `Companies` | One folder per company you work with, holding its `profile.md`. See *Me, Companies and People* below. |
| `People` | One note per person, flat. Working relationships only. |
| `Journal` | The condensation pipeline: `Sessions/` → `Weekly/` → `Monthly/`. |
| `Meta` | This guide, `Templates/` and `Attachments/`. |

Folders carry no number prefixes; Obsidian sorts them alphabetically. Nothing should
ever hard-code a folder's position, so the structure can be reshuffled without breaking
a skill, a scheduled task or a link.

## Me, Companies and People

Three folders carry the standing context Claude needs to read a request the way a
colleague would. Everything in them is about *who*, not *what* — the work itself still
lives in `Projects`, `Areas` and `Resources`.

### `Me`

- `Me/profile.md` — who you are at work: role, remit, reporting lines, the standing
  rules for how Claude works with you. Read it early in a session.
- `Me/style.md` — how you write. Read it before drafting anything you will send as
  yourself. Claude appends dated observations under `## Observations`; it never rewrites
  your own prose.

### `Companies`

One folder per company you actually work with — your own employer, other companies in
the same group once there is real work with them, and outside companies whose people you deal with.
Each folder holds one file:

```
Companies/<Company Name>/
  profile.md          what the company does, structure, internal language,
                      rhythms, who works there, the AI work there
```

- Start a new company from `Meta/Templates/Company Profile.md`.
- Company-level context — structure, language, rhythms — belongs in that company's
  `profile.md`, never in a person's note.
- Do not scaffold a company before there is work with it. An empty profile that nobody
  fills in is worse than no folder.

### `People`

One note per person, flat — no subfolders, from `Meta/Templates/Person.md`.

- **The `company` field does the grouping**, not the folder. It names who they work for,
  not who you deal with them about: an external advisor carries their own firm, not the
  client they advise. Someone who spans two companies lists both. Someone who changes
  employer keeps the same note and you change the field. This is why People is flat —
  one person, one note, however their affiliation moves.
- Each company's `profile.md` keeps a `## People` section of wikilinks to the people
  there. That is the index; the folder is just storage.
- **Working relationships only.** Nothing about anyone's private life, health or
  circumstances. If something personal is relevant, note only its working consequence
  and say "personal circumstances".

### Why aliases matter here

Every company folder has a file called `profile.md`, so basenames are not unique and a
bare `[[profile]]` is ambiguous. The fix is `aliases` in frontmatter: the note
`Companies/{{COMPANY_NAME}}/profile.md` carries `aliases: [{{COMPANY_NAME}}]`, and that
alias is what makes `[[{{COMPANY_NAME}}]]` resolve from anywhere in the vault. So:

- **Every `profile.md` must list its own display name in `aliases`.** No exceptions —
  without it the note is unlinkable.
- Link companies and yourself by alias (`[[{{COMPANY_NAME}}]]`, `[[{{OWNER_NAME}}]]`),
  never by path. If a folder gets renamed or moved, the alias keeps the links working.

## The condensation pipeline

Detail flows in one direction and gets shorter at each step. Nothing is deleted along
the way — each level links back to its sources.

1. **Sessions** (`Journal/Sessions/YYYY-MM-DD-slug.md`) — written at the end of every
   Claude session. Detailed. This is the raw layer.
2. **Weekly** (`Journal/Weekly/YYYY-Www.md`) — every Sunday evening, all that week's
   session notes condense into one review. Target: skimmable in two minutes.
3. **Monthly** (`Journal/Monthly/YYYY-MM.md`) — on the 1st, that month's weekly reviews
   condense into one. Target: readable in thirty seconds. The monthly also looks at the
   vault itself: a *Needs a look* section listing notes untouched for 60 days or more and
   anything that stayed open across every week of the month. It is a report only —
   nothing gets tagged or restatused because it appears there.

Condensation rules, in priority order:

- **Decisions carry up verbatim.** A decision is the one thing that must survive to the
  monthly layer intact. Never paraphrase a decision into vagueness.
- **Open threads carry up until closed.** If something is still open at month end, it
  appears in the monthly review.
- **Narration drops out.** "Researched X, then built Y" becomes "Y, because X".
- **Patterns emerge upward.** Things that recur across weeks get named at the monthly
  layer, and are candidates for `Ideas` or a new Area.
- **Every level links down.** A weekly review lists its source sessions; a monthly lists
  its source weeks.

## Folding in what chat learned

Plain chat on web and mobile cannot write to this vault — it has no file tools. What it
*can* do is write to Claude's memory, which is shared across surfaces and updates as you
talk. Memory is therefore the inbox for everything typed outside a session that has this
folder connected, and this vault is where it becomes a note.

Fold it in at two points:

- **At the end of every session**, as part of filing: skim memory for anything durable
  this vault does not already know — a new project, a colleague, a decision, a change of
  direction — and file it in the right folder.
- **During the weekly rollup**, as the backstop, before writing the review.

Rules for the fold:

- **The vault wins on wording.** If a fact is already here, leave it.
- **File it where it belongs**, not into a "from memory" dumping ground. A colleague goes
  to `People/`, a decision to the project it belongs to, something durable about how you
  write or work to `Me`.
- **Working relationships only in `People/`**, exactly as elsewhere in this guide,
  whatever memory happens to hold.
- **Say what was folded** in the session note or weekly review, so the trail exists.

This is the honest seam in the setup: something typed into chat reaches the vault at the
next session or the Sunday rollup, whichever comes first — not instantly.

## Naming

- Session notes: `2026-09-01-vault-setup.md`
- Weekly: `2026-W36.md` (ISO week)
- Monthly: `2026-09.md`
- Permanent notes: the claim itself as the title, e.g. `Condensation beats archiving.md`
- Projects, Areas, People: their plain name.
- Company profiles: always `Companies/<Company Name>/profile.md`, with the company name
  in `aliases`.

## Frontmatter

Every note gets `type` at minimum. Use the templates in `Meta/Templates`. `type` is one
of: `session`, `weekly`, `monthly`, `zettel`, `project`, `area`, `resource`, `person`,
`company`, `me`, `meta`.

Notes whose filename is not unique in the vault — every `profile.md` — must also carry
their display name in `aliases`. See *Why aliases matter here* above.

## Linking

Wikilinks, always. A session note links to the projects and people it touched. A
permanent note with no outbound links is a note that will never be found again — link it
to at least one MOC or sibling note.

## Where the vault lives, and how it syncs

The vault is `{{VAULT_PATH}}`. That folder *is* the vault: it is what Obsidian opens,
what Claude edits directly, and the current state of everything here.

**Backup: {{SYNC_PROVIDER}} — {{SYNC_LOCATION}}.** That is the whole sync story.

There is no repo, no branch, no commit and no push. Nothing is waiting on a sync step.

**Working locally (Claude in this folder):** edit the files in place. Saving is the sync
— there is nothing to do at the start of a session and nothing to do at the end. Only ask
for delete permission if the task genuinely involves removing a file, which is rare:
moving to `Archive` is the delete.

**Working from the cloud, with no access to this machine:** write new notes into `Inbox`
and say so. **Create only — never edit or delete an existing note from the cloud.** A
mirrored folder syncs creations down but not deletions, so a cloud-side replacement under
the same name produces two files. The next local session merges anything left in `Inbox`.

**Never write a credential into a note.** No tokens, passwords or keys anywhere in the
vault — every file here is synced to a cloud provider.

## What Claude does at session end

1. Read this guide.
2. Write a session note from the `Session Note` template into `Journal/Sessions/`.
3. File any deliverable into the right PARA folder and link it from the session note.
4. If the session produced a genuinely new, reusable idea, draft it as a permanent note
   in `Ideas` and link it both ways.
5. If the session revealed something durable about how you write, append to
   `Me/style.md`; about your role, remit or how you want Claude to work, update
   `Me/profile.md`. If it revealed something about a colleague — their remit, how they
   work, what lands with them — update or create their note in `People/`, and add a
   wikilink to it from their company's `## People` section if it is not there yet.
   If it revealed something about a company itself, update its `profile.md`. A company
   you have genuinely started working with gets a new folder under `Companies/` from the
   `Company Profile` template.
6. Never modify `Journal/Weekly` or `Journal/Monthly` outside a rollup run.
7. Say in one line where things landed.

## What Claude does not do

- Does not write to `Archive` except to move something completed.
- Does not delete notes. Moving to `Archive` is the delete.
- Does not rewrite your own prose in `Me/style.md` — it appends observations under a
  dated heading and lets you fold them in.
- Does not put private details about anyone's life, health or circumstances in a
  `People/` note. Those notes cover working relationships only.
- Does not create a company folder speculatively, and does not write a `profile.md`
  without an `aliases` entry.
