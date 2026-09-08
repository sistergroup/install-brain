---
name: brain-setup
description: Set up a new context brain by scanning the owner's Microsoft 365 account and drafting their profile, writing style, companies, people and projects, then confirming the uncertain parts with them. Run once, on a fresh vault. Use when the vault's Me/profile.md is still empty, when the owner asks to set up or populate their brain, or when the installer hands over with /brain-setup.
---

# Brain setup

Run this once, on a fresh vault, to turn an empty structure into a populated one.

The vault has already been created by the installer. Your job is the part no script can
do: read the owner's own Microsoft 365 account, work out who they are and how they
write, draft the standing-context notes, and ask about only what the data could not
settle.

**Read `Meta/Vault Guide.md` before anything else.** It is the source of truth for folder
names, frontmatter and conventions. Take folder names from it, never from this skill —
the vault gets reorganised and the guide is what stays current. If the guide and this
skill disagree, the guide wins.

## Before you start

Check three things and deal with each before scanning:

1. **Is this vault already populated?** If `Me/profile.md` has real content rather than
   the empty stub, stop and ask. Offer to review and update instead of starting over.
   Never overwrite a populated brain.
2. **Is the Microsoft 365 connector available?** Try `get_me`. If it fails or the tools
   are absent, do not guess and do not proceed to the scan. Say this:

   > I can't reach your Microsoft 365 account yet. To connect it: open Claude's settings,
   > go to Connectors, find Microsoft 365 and click Connect, then sign in with your work
   > account. Your IT team has already authorised it for the organisation, so you should
   > not see a permissions screen you can't approve. Come back and run `/brain-setup`
   > again once it's connected — or say "do it manually" and I'll build the brain by
   > interviewing you instead.

3. **Can you write to the vault?** Confirm you can read `Meta/Vault Guide.md` and create
   a file. If not, the owner needs to add the vault folder to this session.

## Stage 1 — consent and scope

Never scan anything before the owner has seen the list and agreed to it.

Tell them plainly, in a short message, what each source gives you and what you will do
with it. Then use `AskUserQuestion` to let them choose, multi-select:

- **Sent email (last 90 days)** — the minimum, and the only source that is on by default.
  It is the best sample of how they write and shows who they actually deal with.
- **Teams chats** — internal language: acronyms, project codenames, nicknames, shorthand.
- **Calendar** — recurring meetings, working rhythm, which teams and companies they sit
  with.
- **Meeting notes and documents** (Granola, OneDrive/SharePoint, Google Drive) — richer on
  projects; skip if they do not use them.

Ask in the same round what to **exclude** — anything they would rather you did not read.
Take the answer literally and widen it rather than narrowing it.

Then write `Meta/Setup Log.md` recording the date, the sources they agreed to, the
exclusions they named, and the scan window. That file is the audit trail; write it before
you scan, not after.

If they decline the scan altogether, switch to **Manual mode** at the bottom of this
skill.

## Stage 2 — scan

Cap the work deliberately. A 90-day window and roughly 200 sent messages is enough for a
confident style read and keeps this affordable. More data does not make the profile
better; it makes the scan slow and the notes vague.

| Tool | What you are looking for |
|---|---|
| `get_me` | Legal name, preferred name, job title, department, office, manager |
| `outlook_email_search` over **sent items** | How they write. Also: who they write to, how often, and in what register |
| `outlook_calendar_search`, recurring events | Cadence, standing meetings, which teams and companies they sit with |
| `chat_message_search`, `teams_list_chats` | Internal language. Acronyms, codenames, nicknames, shorthand |
| Correspondent frequency, grouped by email domain | Candidate companies and candidate people |

While scanning, also work out three things the installer deliberately did not ask,
because a cold question in a terminal only gets a guess and the mailbox has evidence:

- **What the work mainly produces** — documents and decisions, things they build and keep
  running, numbers and analysis, creative or editorial material, or other people working
  better. This is the one that changes the folder structure, and it is also the hardest to
  read, so gather evidence deliberately rather than forming an impression. The signal is
  in **what they attach and what they name**: spreadsheets and dashboards going out weekly
  points at numbers; decks, scripts, treatments and cuts point at creative; tools, links
  to things they have built, and mail about something being broken or live point at things
  they build and keep running; training, onboarding, walkthroughs, "how do I" questions
  coming *to* them and workshop invitations point at other people working better;
  everything else, and most people, are documents and decisions. Sent attachments carry
  more weight than received ones, and repeated file types over the window carry more
  weight than one busy week. Read the full text of a handful of their own sent messages
  about their own work rather than judging from subject lines.
- **How the work arrives** — discrete jobs that finish, or ongoing responsibilities that
  do not. Read it from thread shapes: many short threads with a subject that dies, versus
  long-running threads and recurring meetings on the same standing topic. Recurring
  calendar entries are the strongest signal of the second.
- **Who the work is with** — mostly people outside the company, mostly inside it, or
  mostly alone with systems and data. Count sent-mail recipients by domain: theirs versus
  everyone else's. Sparse correspondence with lots of automated or tooling mail points at
  the third.

The first answer adds folders and templates, and Stage 3 settles it before anything gets
drafted. The other two change no folder: they change where the weight goes, which of
`Projects` and `Areas` you fill in, and whether `Companies/` is the spine of this vault or
a footnote. Say what you concluded and why in Stage 5, and let them correct it.

**Be honest about how strong the evidence is.** Roles look far more alike in a mailbox
than they do in life, and a confident wrong read puts folders in someone's vault that do
not belong there. If the mail does not clearly point one way, say so when you ask, and
offer the choice rather than a conclusion to nod at.

While scanning, keep four running lists rather than trying to hold it all in your head:

- **People** — name, email, apparent role, how often, how they are written to.
- **Domains** — grouped, with a count. This becomes the candidate company list.
- **Recurring subjects** — thread subjects and chat topics that come back. Candidate
  projects.
- **Style evidence** — actual quoted fragments from their own sent mail. You will need
  these to justify what you write in `Me/style.md`, and to show them if they disagree.

Filter as you go, not afterwards. Newsletters, no-reply addresses, calendar invitations,
automated alerts, recruiters and vendors pitching cold are all noise and should never
reach the candidate lists.

## Stage 3 — settle what the work produces, and apply its extras

Do this before drafting anything, because it decides which templates the rest of this
skill uses. `People/` in particular gets a different template under one of the roles.

The installer staged every set of extras in **`Meta/.roles/`**, tokens already
substituted. Each `Meta/.roles/<key>/` holds a `folders.txt` of folders to create and a
`files/` tree to copy into the vault, preserving its paths. The five keys:

| Key | For work that mainly produces | Adds |
|---|---|---|
| `documents` | Documents, decisions and plans | nothing — the base vault is already this |
| `assets` | Things they build and then keep running | `Assets/`, an `Asset` template |
| `reporting` | Numbers, reports and analysis | `Reporting/`, a `Recurring Report` template |
| `creative` | Creative or editorial material | `Resources/References/`, a `Reference` template |
| `enabling` | Other people working better | `Assets/`, `Meta/Friction Vocabulary.md`, its own `Person` and `Asset` templates |

**Ask, do not assume.** State your read from Stage 2 in one line with the evidence behind
it, then use `AskUserQuestion` with all five as options so the answer is theirs. Put your
read first and say why:

> *"Most of what you send out is spreadsheets and a weekly figures mail to one person, so I
> think your work mainly produces numbers and analysis. That would add a `Reporting/`
> folder and a recurring-report template. Right, or is it one of these?"*

If the evidence was thin, say that instead of dressing it up: *"Your mail does not
strongly point one way — mostly short threads about scheduling. Which of these is closest?"*

Then apply exactly one:

1. Create every folder listed in `Meta/.roles/<key>/folders.txt`.
2. Copy everything under `Meta/.roles/<key>/files/` into the vault at the same relative
   path. On a fresh vault a template supplied by the role **replaces** the base one of the
   same name — that is the point of `enabling` shipping its own `Person` template. If the
   vault is not fresh and the file differs from what the role supplies, do not overwrite:
   say which file you left alone and why.
3. Record it: set `"role"` in `Meta/.brain.json` to the key you applied, and write one
   line at the top of `Me/method.md` saying what the work mainly produces and that they
   confirmed it.

`documents` adds nothing, so there is nothing to copy — say so in one line rather than
staying silent, or it looks like the step failed.

**Leave `Meta/.roles/` alone afterwards.** All five stay staged, so if their work changes,
or this read was wrong and they say so in a month, another set can be applied without
reinstalling anything.

## Stage 4 — draft, do not interrogate

This is the difference between a setup that feels like magic and one that feels like a
form. Write the drafts first, then show them. Do not ask the owner anything you could
have worked out.

Draft, in this order:

1. **`Me/profile.md`** — from the template's headings. Name, email, base and timezone;
   job title, department, reporting line; what they appear to be responsible for. Leave
   *How they work with Claude* mostly empty — that is a preference, not a fact, and Stage
   4 asks for it.

2. **`Me/style.md`** — voice, habits, register shifts by recipient, an avoid-list, and the
   by-format sections. Fill the `evidence:` frontmatter field with what you actually read,
   e.g. `184 sent emails, Jun–Sep 2026`. Be specific and falsifiable: "opens with
   'Morning —' to colleagues, 'Dear' to anyone external" is useful; "professional but
   friendly" is not. Never invent a habit you did not see at least twice.

3. **`Companies/<Company>/profile.md`** for every company with real traffic — their own
   employer always, plus any domain above a sensible threshold (roughly five or more
   distinct threads in the window). Use the `Company Profile` template. **Put the company
   name in `aliases`** — without it the note is unlinkable.

4. **`People/<Person>.md`** for the top correspondents — the people they clearly work
   with, not everyone who ever emailed. Use the `Person` template. People is flat: one
   note per person, and the `company` field says who they work for, not who the owner
   deals with them about. Someone who spans two companies gets one note listing both.
   Link each person from their company's `## People` section as you go.

   If `Meta/Friction Vocabulary.md` exists — it does when Stage 3 applied the `enabling`
   role — read it, and use the `Person` template's `## Friction`
   section where the mail actually shows friction. A quoted line from someone's own
   message plus one tag from that file. If the mail does not show it, leave the section
   empty: guessed friction is worse than none, and Stage 5 can ask.

5. **`Projects/<name>.md`** for each recurring subject that genuinely looks like a project
   — an outcome and an end. If it is ongoing with no end, it is an Area. If it is neither,
   leave it out; Stage 5 will ask.

6. **`Me/method.md`** — only the parts the scan can actually support. Stage 3 put one line
   at the top saying what their work mainly produces; leave it. Fill *How I work* only
   where you saw the same approach used more than once, and leave *Positions I hold* and
   *What I have changed my mind about* empty. Those are theirs to write, and a
   guessed position is worse than a blank heading. Say in Stage 8 that the file is there
   and mostly for them.

Weight what you write by what Stage 2 concluded and Stage 3 settled. If the work is a
continuous service, most of it belongs in `Areas` and a thin `Projects`; if it is discrete
jobs, the reverse. If the work is mostly internal, expect one company profile with most of
`People/` pointing at it rather than several thin ones. Do not force notes into a folder to
make the vault look balanced.

Set `status: draft` in the frontmatter of everything you write here, so it is obvious what
has been confirmed and what has not.

## Stage 5 — confirm by exception

Now ask, and only about what the scan could not settle. Use `AskUserQuestion`, multiple
choice wherever the answer is a choice. Keep it to two or three rounds — this should feel
like a short conversation, not an intake form.

Start with the two things still open from Stage 2, how the work arrives and who it is with,
because getting them wrong skews everything else. What the work produces was already
settled in Stage 3. State the conclusion and the evidence in one line each, and offer the
alternative:

- *"Your mail looks like discrete jobs that finish — 30-odd threads that each ran for a
  week or two. So I have put the weight in Projects rather than Areas. Right?"*
- *"About 80% of your sent mail goes outside the company, so I have treated Companies and
  People as the centre of this vault. Right?"*

If either is wrong, move the weight before drafting anything else — do not leave a vault
organised around a wrong read of how someone works.

Then, worth asking:

- **"Which of these are actually projects?"** — multi-select from the candidates. This is
  the single most valuable question, because a busy thread and a project look identical
  from outside.
- **"These companies came up. Which do you actually work with?"** — multi-select. This is
  what kills the residual noise.
- **"Is X your manager?"** — only if the org data was unclear. If `get_me` answered it,
  do not ask.
- **"You write quite differently to A than to B — deliberate?"** — only if you saw a real
  register shift.
- **"What are you working on that email wouldn't show?"** — free text. This is the
  question that catches everything the scan structurally cannot see.
- **"Anything I should always do, or never do, when working with you?"** — free text, and
  the answer goes into *How they work with Claude* in `Me/profile.md`.

Apply the answers, drop `status: draft`, and delete the notes they rejected rather than
leaving them lying around.

## Stage 6 — guardrails

These are not advisory. A mailbox scan walks straight into sick notes, HR threads, salary
discussions and grievances, and getting this wrong is the one failure that is not
recoverable.

- **`People/` notes cover working relationships only** — remit, cadence, what lands with
  them, what they need. Nothing about anyone's private life, health or circumstances. If
  something personal has a genuine working consequence, note only the consequence and
  write "personal circumstances".
- **Skip mail and chat involving HR, Legal, Payroll, Occupational Health and Recruitment**
  by sender and by domain. Do not summarise it, do not count it, do not mention it.
- **Never quote a colleague's private message verbatim** into a note about them. Describe
  the working pattern instead.
- **Never write a credential, token, password or key into any note.** The vault syncs to a
  cloud provider.
- **Nothing about the owner's own health, finances, family or personal life** goes in the
  vault, even if their mailbox is full of it. The brain is for work.
- **Honour the exclusions** they gave in Stage 1, and treat anything adjacent to them as
  excluded too.
- **When in doubt, leave it out.** A thinner brain gets filled in over time. A brain that
  quietly records something it should not is a problem you cannot take back.
- **Friction is about work, never about a person.** If the vault has a
  `Meta/Friction Vocabulary.md`, a `## Friction` line records an obstacle in the work —
  "approvals sit for a week". It never records a judgement about a colleague. Nothing in
  these notes should be uncomfortable if that colleague read it.

If you find yourself reasoning towards why an exception is fine, that is the signal to
leave it out.

## Stage 7 — wire up the ongoing loop

A brain that is populated once and never again decays within a month. Before finishing:

1. Confirm `vault-filing`, `vault-rollup` and `email-triage` are available. The installer put them in
   `.claude/skills/` inside the vault; if they are not being offered, say so and point at
   the installer's README rather than trying to reinstall them yourself.
2. Explain the loop in two sentences: a session note gets written at the end of every
   session, and those condense into weekly and monthly reviews.
3. Offer to set up the recurring tasks: the weekly rollup on Sunday evening, the monthly
   on the 1st, and — if they want it — `email-triage` each working morning. Set the email
   one up as a task **on this machine**, since the vault is a local folder and a cloud task
   cannot see it. Say plainly that a local task only runs when the machine is awake with
   the app open, and that a missed run is caught by the next one widening its window. If scheduled tasks cannot be created from here, say so plainly and tell them the
   fallback: run `/vault-rollup weekly` when they think of it, and it will catch up.

## Stage 8 — finish

1. Write the first session note into `Journal/Sessions/` from the `Session Note` template,
   dated today, slug `brain-setup`. Record what was scanned, what was drafted, what they
   corrected, and anything left open.
2. Update `Meta/Setup Log.md` with what was actually created — a file list.
3. Tell them, in a short message and no more:
   - what got created, as counts not lists ("your profile, a style note, 3 companies,
     11 people, 4 projects");
   - the two or three things worth their eye — usually `Me/profile.md` and anything still
     marked `draft`;
   - one sentence on what happens from now on.

Do not paste the notes back into the chat. They can open the vault.

## Manual mode

If the owner declines the scan, or the connector cannot be reached and they want to get
on with it, build the brain by interviewing them instead. Same destination, slower road.

Ask in this order, one short round at a time, writing after each round rather than saving
it all for the end:

1. Name, role, who they report to, who they work alongside.
2. **What their work mainly produces** — the five options in Stage 3, asked as a question
   rather than inferred, since there is no mail to read. Apply the overlay from
   `Meta/.roles/` the same way before drafting anything.
3. What they are actually responsible for right now, in their own words.
4. The companies they deal with, and the three or four people they deal with most.
5. What they are working on that has an end date, and what is ongoing.
6. Any internal language a newcomer would not understand.
7. Anything Claude should always or never do when working with them.

Then draft the same notes, and offer to run the scan later to fill in the gaps.

## Verification

Before you finish, check — do not assume:

- `Me/profile.md` and `Me/style.md` have real content and no remaining `{{TOKEN}}`
  placeholders.
- Every `profile.md` you created carries its display name in `aliases`.
- Every wikilink you wrote points at a note that actually exists.
- Every note has valid YAML frontmatter with a `type` field, and no note still says
  `status: draft` unless it genuinely is one.
- Nothing you wrote breaches Stage 6. Re-read the `People/` notes specifically, with that
  list in front of you.
- No credential anywhere.
- `Meta/Setup Log.md` exists and matches what you actually did.
- Exactly one role was applied, its folders exist, and `Meta/.brain.json` records it.
  `Meta/.roles/` is still there with all five sets in it — it is not yours to clean up.
