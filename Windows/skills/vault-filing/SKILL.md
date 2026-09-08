---
name: vault-filing
description: File session work into this vault at the end of every session, following its condensation pipeline. Use when a session produced a deliverable, a decision, research worth keeping, or anything durable about how the owner works — and whenever they ask to save, file or capture something to the vault.
---

# Vault filing

## Trigger

Run this at the end of a session when any of these is true:

- A deliverable was produced (document, analysis, draft, code, plan).
- A decision was made, or an option was ruled out for a stated reason.
- Research was done that would be annoying to redo.
- The owner said anything durable about how they write, who they work with, or how their
  company operates.
- They explicitly ask to save, file or capture something to the vault.

Do **not** run it for pure Q&A, a quick lookup, or a session that produced nothing worth
re-reading. A vault full of empty session notes is worse than no session notes.

## Steps

1. **Check the vault is reachable.** It is the folder this session is working in, or a
   connected folder whose name ends in `-brain`. If it is not available, say so in one
   sentence and stop — do not recreate the structure somewhere
   else and do not copy vault files into a scratch workspace.

2. **Read `Meta/Vault Guide.md` first.** It is the source of truth for structure, naming,
   frontmatter, the condensation rules and how the vault syncs. Take folder names from it
   rather than from this skill — the vault gets reorganised, and the guide is what stays
   current. If the guide and this skill disagree, the guide wins.

3. **Write the session note.** Copy the `Session Note` template from the templates folder
   into the Journal's `Sessions/` folder as `YYYY-MM-DD-slug.md`. Slug is two to four
   words of the actual subject. If a note for that exact date and slug exists, append a
   new `##` section rather than overwriting; a different subject on the same day gets its
   own note with its own slug.

   Fill it the way it will be read six months from now:

   - **Ask** — one or two sentences.
   - **What happened** — concrete bullets. Outcomes, not narration.
   - **Decisions** — the choice and the reason. These carry up verbatim through the weekly
     and monthly layers, so write them to survive.
   - **Outputs** — wikilinks to where things landed.
   - **Open threads** — anything unfinished or waiting on someone.
   - **Seeds** — ideas worth promoting to permanent notes, each with a candidate title.

4. **File the deliverables.** Put each into the right PARA folder — `Projects` if it
   belongs to something with an end date, `Areas` if ongoing, `Resources` if it is
   reference material. When genuinely unsure, `Inbox`, and say so. Link each from the
   session note.

5. **Promote seeds sparingly.** If the session produced a reusable idea that stands on its
   own, write it into `Ideas` from the `Permanent Note` template, in full sentences, and
   link it to at least one existing note or MOC. One good permanent note per session is
   plenty; zero is common and fine.

6. **Update `Me`, `People` and `Companies` when warranted.** If the session revealed
   something durable about a colleague — their remit, how they work, what lands with them
   — update or create their note in `People/` from the `Person` template, flat, with the
   `company` field set, and linked from that company's `## People` section. If the owner
   edited a draft's voice or corrected wording, append a dated observation under the
   `## Observations` heading of `Me/style.md`. Append — never rewrite their own prose.
   Company-level facts belong in that company's `profile.md`, not in a person's note.

   **Working relationships only in `People/`.** Nothing about anyone's private life,
   health or circumstances. If something personal has a working consequence, note only the
   consequence and write "personal circumstances".

   If the vault has a `Meta/Friction Vocabulary.md`, and the session surfaced something
   that gets in a colleague's way, add it to their `## Friction` section: their own words
   quoted, then one tag from that file. Obstacles in the work only — never a judgement
   about the person.

7. **Fold in what chat learned.** Skim Claude's memory for anything durable the vault does
   not already know — a new project, a colleague, a decision, a change of direction — and
   file it where it belongs, per the guide's *Folding in what chat learned* section. The
   vault wins on wording. Say what was folded, in the session note.

8. **Tell them in one line** where things landed. Do not paste the session note back into
   the chat — they can open it.

## Duplicates and clashes

A cloud session with no access to this machine writes new notes into `Inbox` rather than
editing existing ones. When filing locally, check `Inbox` for these and merge each into
the note it belongs to. Keep both versions' content when merging; never discard a side
unseen. If a merge is not obvious, leave both blocks in place under clear headings and say
which note needs a human eye.

## Verification

Before finishing:

- The new note has valid YAML frontmatter with a `type` field.
- Its filename matches the naming convention in the Vault Guide.
- Every wikilink points at a note that exists — check, do not assume.
- Nothing you wrote hard-codes a folder's position or an old folder name.
- No credential entered a note. The whole vault syncs to a cloud provider.
- `Inbox` is not accumulating: if it has more than a few items, mention it.
