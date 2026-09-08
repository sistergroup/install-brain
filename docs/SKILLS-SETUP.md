# The three skills, and why each person uploads their own

## What happens

The installer builds four zips into `Meta/Setup` inside the vault. The person uploads them
to their own Claude account at **Customize → Skills → + → Create skill → Upload a skill**.
About a minute. `START HERE.md` in the vault walks them through it.

No admin involved, nothing shared, nothing central. The skills are theirs.

## Why it cannot be automated

Two different things are called skills, and only one reaches the Claude desktop app:

| | Where it lives | How it gets there |
|---|---|---|
| Account skills | `~/.claude/skills/synced/…` | Enabled on the person's claude.ai account, synced at session start. **What the desktop app uses.** |
| Folder skills | `<folder>/.claude/skills/…` | Files. Read by Claude Code. **Ignored by the desktop app.** |

Both were tested rather than assumed. A probe skill in a folder added to the desktop app was
never offered. Account skills are present on disk inside a running desktop session, fetched
at session start.

So the account is the only route, and an account skill can only be added by uploading it in
the Claude interface. A shell script cannot do it.

## Requirements

Skills work on Free, Pro, Max, Team and Enterprise plans, and **code execution must be
enabled** on the account. If **Skills** is greyed out, that is why — worth confirming with
IT before a rollout rather than during one.

## Which of them matter

- **`brain-setup`** is optional. It runs once, and `START HERE.md` gives a line to paste
  that does the same job with no upload.
- **`vault-filing`, `vault-rollup` and `email-triage` are not.** All three have to fire on
  their own — at the end of a session, and on a schedule. A skill not on the account never
  triggers by itself, so without them nothing gets written up unless the person remembers
  to ask every time. A brain that only fills in when someone remembers is a brain that
  stops filling in.

If someone does only part of this, it should be those three.

## `email-triage` runs on a schedule, and where matters

It is written to work either way, and the trade is real:

- **A task on the machine** is where to start, because the vault is a local folder and
  Claude can read it directly. It only runs when the machine is awake with the app open; a
  missed run is caught by the next one widening its window.
- **A cloud task** runs whether or not the machine is on, but cannot see a local folder — it
  needs the vault reachable through a connector, and must then be create-only, because a
  mirrored folder syncs new files down but not deletions and overwriting produces
  duplicates.

Start local. Move it to the cloud once it has proved useful and the vault is synced.

## The zips

Built at install time from `skills/` in the package — `zip -qrX` with a `ditto` fallback on
macOS, `Compress-Archive` on Windows — so they cannot drift from the `SKILL.md` files, and
no binaries live in the repo.

The zip must contain the skill folder, and **the folder name must match the skill name**, or
the upload is rejected. Existing zips are left alone on a re-run; delete them and re-run to
rebuild after changing a skill.

## Updating a skill later

Once people hold their own copies there is no central switch: a change to `vault-filing`
means everyone re-uploading, and they will not.

The mitigation is built into how the skills are written — they take folder names, naming
conventions and condensation rules from `Meta/Vault Guide.md` at run time rather than
hard-coding them. The guide lives in the vault and can be refreshed without anyone touching
their account: bump `guide_version` in the shipped guide, and a re-run of the installer
replaces an older one while keeping the person's copy beside it. Without that bump the
re-run leaves the guide alone, because every other note in a vault belongs to the person.

**So anything likely to change belongs in the Vault Guide, and the skills stay thin.**

If an organisation has a Claude owner able to provision skills centrally (claude.ai →
Organization settings → Skills), that solves this outright and removes step 3 for everyone.
Worth checking. Note that skills uploaded through the **Skills API** are a separate world
from skills on claude.ai and do not sync across surfaces — the API route does not reach the
desktop app.

## Reference

- https://support.claude.com/en/articles/12512180-use-skills-in-claude
- https://support.claude.com/en/articles/12512198-how-to-create-custom-skills
