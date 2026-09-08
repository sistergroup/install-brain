# What IT needs to do first

Written to be forwarded as-is.

We are setting up a personal "context brain" for employees: a local folder of notes that
Claude populates from the person's own mailbox and calendar, so it understands their role,
colleagues and projects without being told each time.

## 1. Grant org-wide admin consent for the Claude Microsoft 365 connector

**Required, and blocking.** No employee can connect their account until this is done. It is
a one-time action for the whole tenant, and needs a Microsoft Entra Global Administrator.

Either:

- **From Claude** — a Global Administrator goes to Settings → Connectors, selects Microsoft
  365, authenticates, and ticks the box to grant access for the entire organisation.
- **From Entra ID** — add the two Anthropic service principals and visit the admin consent
  URLs to authorise the delegated permissions. Identifiers are in Anthropic's setup article
  below.

What it does and does not mean:

- It authorises the *integration* once, so employees no longer see a permissions screen they
  cannot approve themselves.
- It does **not** give Anthropic or anyone else blanket access to the tenant. Claude acts on
  behalf of each individual user and can only reach data that user can already see.
- Each employee still connects their own account, and can disconnect it.

## 2. Read access is enough

The connector covers mailbox (including archive and shared mailboxes), calendar, Teams chat
and channel messages, and OneDrive/SharePoint files.

We only need **read**. Write capabilities — sending mail, creating events or files — require
separate admin enablement and we are not asking for them.

## 3. Enable code execution on members' accounts

Each employee uploads three small skill files to their **own** Claude account during setup.
Nothing shared, nothing central. Skills depend on code execution being enabled; if it is
off, the Skills option is greyed out and that step cannot be completed.

Please confirm it is on for everyone in scope, or tell us it is blocked so we can plan
around it.

## 4. Claude seats

Everyone in scope needs a Claude seat and needs to be able to sign in.

## 5. Software installs

Two applications per machine, both per-user, neither needing administrator rights:

- **Obsidian** — the notes app. `Obsidian.Obsidian` via winget on Windows, `obsidian` via
  Homebrew on macOS.
- **The Claude desktop app** — `Anthropic.Claude` via winget, `claude` via Homebrew.

One thing to confirm: Obsidian's winget package appears to install machine-wide and may want
administrator rights on Windows. Please tell us either that a per-user install is permitted,
or that you would rather push Obsidian yourselves — the installer detects it and skips that
step.

## 6. Later, and better: push it via MDM

Right now an employee pastes one command. If these machines are managed through Intune, Jamf
or Kandji, the same package can be pushed silently instead and the employee does nothing.
That also gives you version control over what is deployed.

## Questions we expect

**Does this send our mail to a third party for training?** No. The connector reads on the
user's behalf at the moment of the request. Data handling is covered in the security guide
linked below.

**Can an employee see someone else's mail through this?** No. The connector is bounded by
that user's existing Microsoft 365 permissions.

**Where does the vault live?** In the employee's own storage — home folder, OneDrive or
Google Drive, their choice — as ordinary markdown files. Nobody else reads it.

**Can we turn it off?** Yes. Revoking the admin consent in Entra disconnects everyone at
once, and any individual can disconnect their own account at any time.

## Reference

- Set up the Microsoft 365 connector — https://support.claude.com/en/articles/12542951-set-up-the-microsoft-365-connector
- Microsoft 365 connector security guide — https://support.claude.com/en/articles/12684923-microsoft-365-connector-security-guide
