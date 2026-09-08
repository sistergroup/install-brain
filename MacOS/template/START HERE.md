---
type: meta
tags: [meta]
---

# START HERE

Your brain is set up but empty. Four short steps in the **Claude app** and it fills
itself in. About fifteen minutes, most of it reading what Claude drafted and correcting
it.

## 1. Open Claude and sign in

Open **Claude** and sign in with your {{COMPANY_NAME}} account.

## 2. Connect Microsoft 365

**Settings → Connectors → Microsoft 365 → Connect**, then sign in with your work
account. Your IT team has already authorised it for {{COMPANY_NAME}}, so you should not
see a permissions screen you cannot approve.

This is what lets Claude read your own sent mail and calendar to work out how you write
and who you work with. It reads as you, over data you can already see, and only after you
have said yes to each source.

## 3. Add the three brain skills to your account

These teach Claude how to work with this vault. They are three small files sitting in
`Meta/Setup` in this folder, and they go on **your own** Claude account — nobody else's.

In Claude: **Customize → Skills → + → Create skill → Upload a skill**, then upload each
zip in `Meta/Setup` in turn:

- `brain-setup.zip` — sets your brain up, once
- `vault-filing.zip` — writes a note at the end of a working session
- `vault-rollup.zip` — condenses those notes weekly and monthly
- `email-triage.zip` — reads your inbox each morning and writes a ranked list of what
  actually needs you into `Inbox`. It never sends, replies to or forwards anything.

If **Skills** is greyed out, code execution needs enabling in your account settings —
ask whoever set your Claude account up.

**Why by hand?** Claude only sees skills that are on your own account, and there is no
way to put them there from outside. It is three uploads, once, and then they are yours
for good.

## 4. Add this folder and set the brain up

Start a new chat, **add this folder** — `{{VAULT_PATH}}` — using the folder or **+**
button, so Claude can read and write your notes. Then type:

```
/brain-setup
```

Claude will tell you what it wants to read before it reads anything, then draft your
profile, your writing style, the companies and people you deal with and what you appear
to be working on, and ask you about the parts it could not work out.

**Skipped step 3?** This still works — paste this instead:

> Read `.claude/skills/brain-setup/SKILL.md` in this folder and follow it.

That gets your brain built. But do go back and do step 3 afterwards: `vault-filing` and
`vault-rollup` need to be on your account to run on their own, and without them nothing
gets written up unless you ask every single time.

## Then what

- Read `Meta/Vault Guide.md` once. It is the contract between you and Claude for this
  vault. If you disagree with something in it, change it — it is the source of truth.
- At the end of a working session, Claude writes a note into `Journal/Sessions`. Those
  condense into weekly and monthly reviews, so detail becomes summary on its own.
- Your notes also open in **Obsidian**, which is the nicer way to read and link them.
- Anything you are not sure where to file goes in `Inbox`.
