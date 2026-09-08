# State and release

## Proven

- Both installers run end to end and are idempotent: a second run over a vault with edited
  notes, edited skills and customised Obsidian settings leaves every file byte-identical,
  while restoring anything deleted.
- Bash and shellcheck clean; all six PowerShell files parse; the folder-name rule agrees
  across both languages on nine test cases; `{{title}}` survives substitution; notes are
  written LF with no BOM.
- The installer stages all five sets of role extras into `<vault>/Meta/.roles/` on both
  platforms, with tokens substituted and `{{title}}` intact, and applies none of them.
  Applying each set the way `/brain-setup` is told to creates the right folders and lands
  every file at the right path, `enabling` replaces the base `Person` template with the
  friction one, `documents` changes nothing, and a re-run of the installer afterwards
  leaves the applied role, its folders, its templates and the `role` field in
  `Meta/.brain.json` untouched.
- The location and backup questions work in every branch. The location question offers two
  answers, home folder or a typed path, and both were driven through a real terminal: the
  home answer takes the default with no shortcut, and a typed path lands the vault there and
  adds the home-folder shortcut. The backup question still covers inside OneDrive, inside
  Google Drive, neither, and the nothing-available case, reached now by a typed path rather
  than a menu item.
- Only the vault can fail a run. Every other step warns and carries on.
- `/brain-setup` produces a populated vault from a real Microsoft 365 account.
- The Vault Guide update path, on macOS: a fresh install says nothing about it, a re-run
  with the same version leaves the vault byte-identical, a bumped `guide_version` replaces
  the guide and keeps the person's copy as `Meta/Vault Guide (previous <date>).md`, an
  unversioned guide is left untouched, `--replace-guide` forces it, and two replacements on
  one day get distinct names. `Meta/.brain.json` is written once and then only when the
  versions it records change.

## Not proven

In priority order.

1. **The ongoing loop.** Whether `vault-filing` fires unprompted at the end of a session
   once uploaded to an account. This is the difference between a brain that keeps itself
   current and one that fills in only when asked.
2. **The Claude desktop app install on Windows.** It has failed on a real run and needed
   doing by hand. Detection checks four paths then the Start Menu shortcut.
3. **A clean Mac end to end**, ideally one without Homebrew, so the `.dmg` fallback is the
   path actually exercised.
4. **A typed custom path on Windows.** The validator correctly rejects Unix paths, so it
   cannot be fully exercised outside Windows.
5. **The Vault Guide update path on Windows.** Every branch was unit-tested under pwsh and
   matches the macOS behaviour message for message, but it has not run inside a real
   Windows install. `Get-GuideVersion`, `Update-VaultGuide` and `Write-VaultStamp` use
   `-LiteralPath`, because `-Path` applies wildcard rules and would not find a vault under
   a folder named like `OneDrive - Company [UK]`. The rest of the Windows code still uses
   `-Path` with variable paths in about 47 places, which is a latent version of the same
   bug and worth a pass of its own.

## Before rolling out

- [ ] Send `docs/IT-PREREQS.md`. Org-wide connector consent blocks everything.
- [ ] Confirm code execution is enabled on people's Claude accounts, or Skills is greyed
      out and the uploads cannot be done at all.
- [ ] Get mailbox scanning into whatever AI use policy applies, and past whoever owns data
      protection.
- [ ] Run it with one person, watching without helping. Every hesitation is the backlog.
- [ ] Then a small friendly group, then wider.

## Releasing

```bash
./sync-shared.sh   # if template/ or skills/ changed — macOS is the source of truth
./check.sh         # must pass
```

Two version numbers to bump by hand, both in `template/manifest.json` and the shipped
guide:

- `packageVersion` in `manifest.json`, on any release. It is what `Meta/.brain.json`
  records, and the only way to tell what somebody is running.
- `guide_version` in `template/Meta/Vault Guide.md`, **whenever the guide changes**. This is
  the one that matters: without the bump, a re-run leaves an existing vault's guide alone
  and the change reaches nobody who already has a brain.

Then zip `MacOS/` or `Windows/` and distribute. Each folder is self-contained.

Then push. `.github/workflows/pages.yml` verifies the package, builds both archives and
publishes them with the install guide to
**https://sistergroup.github.io/install-brain/**. Both installers already carry that site
as their default `BRAIN_PACKAGE_URL`, so there is nothing to configure per machine.

Zipping and sending a folder by hand still works and is unchanged. It is now the fallback
rather than the route.

Signing is not worth it. An unsigned download is blocked by Gatekeeper and SmartScreen
anyway, so a signed installer costs an Apple Developer membership, a Windows certificate and
a notarisation step per release to produce a worse experience than a pasted command. MDM
(Intune, Jamf, Kandji) is the real answer at scale, and turns a pasted command into nothing
at all.

## Layout

```
install-brain/
├── README.md            how to run it
├── ARCHITECTURE.md      how it works, and what cannot be automated
├── BUILD-PLAN.md        this file
├── check.sh             verify both folders before sharing
├── sync-shared.sh       copy template/ and skills/ macOS → Windows, then diff
├── docs/
│   ├── IT-PREREQS.md    what an admin has to do first
│   └── SKILLS-SETUP.md  why each person uploads their own skills
├── MacOS/
│   ├── install.sh · lib/{common,obsidian,claude,sync,vault}.sh
│   ├── template/        manifest.json, Vault Guide, Templates/, Me/, roles/, .obsidian/
│   └── skills/{brain-setup,vault-filing,vault-rollup,email-triage}/SKILL.md
└── Windows/
    ├── install.ps1 · lib/{Common,Obsidian,Claude,Sync,Vault}.ps1
    ├── template/        identical to MacOS/template
    └── skills/          identical to MacOS/skills
```

The duplication of `template/` and `skills/` is deliberate: a folder someone emails should
need nothing else. `sync-shared.sh` and `check.sh` stop the two drifting.
