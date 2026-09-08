---
name: vault-rollup
description: Condense this vault's session notes into a weekly or monthly review, following the vault's condensation pipeline. Use when asked for a weekly or monthly rollup or review, or when a scheduled rollup task fires. Takes "weekly" or "monthly" as its argument.
argument-hint: "[weekly|monthly]"
---

# Vault rollup

Condense detail upward. Nothing is deleted along the way — each level links back to its
sources.

**Read `Meta/Vault Guide.md` first** for folder names, the naming convention and the
condensation rules. The guide wins over this skill.

If no period was given, infer it: on or near the 1st of a month, ask whether they want the
monthly, the weekly, or both. Otherwise assume weekly.

## Weekly

1. Read every session note dated in the ISO week.
2. Before writing, **fold in what chat learned** — skim Claude's memory for anything
   durable the vault does not already know, and file it in the right folder first. This is
   the backstop for anything typed into chat during the week. Say what was folded.
3. Write the review from the `Weekly Review` template, using the guide's naming
   convention.

Target: skimmable in two minutes.

- **Carry decisions up verbatim.** Do not paraphrase a decision into vagueness. This is
  the one rule that matters most.
- **Carry open threads up** until they are closed.
- **Drop narration.** "Researched X, then built Y" becomes "Y, because X".
- **List every source session** as a wikilink.

## Monthly

1. Read that month's weekly reviews — not the session notes.
2. Work out what needs a look, per *Staleness and stuck threads* below.
3. Write the review from the `Monthly Review` template.

Target: readable in thirty seconds.

- **Name the patterns** that recurred across weeks. These are the candidates for a new
  Area or a permanent note in `Ideas`, and naming them is the main value of the monthly
  layer. If the vault has a `Meta/Friction Vocabulary.md`, count the tags across the
  month's `People` notes and name any that came up for more than one person — that is the
  clearest signal the vault produces about what to build next.
- **Drop decisions that have since been superseded**, and say which superseded them.
- **List every source week** as a wikilink.

### Staleness and stuck threads

The monthly is the only place the vault looks at itself. Fill the template's
*Needs a look* section with two lists — both statements of fact, not verdicts:

**Stale.** Notes in `Projects`, `Areas` and `Companies` whose file has not been modified
for 60 days or more. Get the dates from the filesystem, not from frontmatter — an
`updated:` field that nobody maintains is exactly the thing being checked. Something like
`find Projects Areas Companies -name '*.md' -mtime +60` gives the list; if you cannot run
a command, fall back to the `updated:` field and say that is what you used. Report each as
one line: the wikilink and the date it was last touched. Skip `_README.md` files, and skip
anything already in `Archive` — moving something there is the point, not a failure.

**Stuck.** Anything that appeared under open threads in *every* weekly review this month.
One line each: the wikilink and the week it first appeared.

Two rules about this section:

- **It is a report, not a tag.** Do not add a `stale` field, a `#stuck` tag or a status
  change to any note. Nothing outside the monthly review is modified.
- **Do not editorialise.** "Untouched since 2026-06-12" is the finding. Whether that
  matters is the owner's call, and a project that is genuinely dormant for a quarter is a
  normal thing rather than a problem. If both lists are empty, leave the heading out and
  say so in one line.

## Rules for both

- **Never edit session notes during a rollup.** The raw layer is immutable.
- **If a period has no session notes, write nothing and say so.** Do not manufacture a
  review of an empty week. This matters — an invented review is worse than a gap, because
  it will be trusted.
- Do not touch `Weekly` when running the monthly, or the other way round.
- If a rollup for that period already exists, do not overwrite it. Say it exists and offer
  to revise it.

## Verification

- Valid YAML frontmatter with `type` and the period field filled in.
- Filename matches the guide's naming convention.
- Every wikilink resolves to a note that exists.
- Every decision in the source layer appears in this one, or was explicitly dropped as
  superseded with the reason given.
