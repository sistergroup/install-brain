#!/usr/bin/env bash
#
# Check that MacOS/ and Windows/ are complete and consistent before you zip and
# share them. Run this after any change:
#
#     ./check.sh
#
# It reports and exits non-zero on a problem. It changes nothing.

set -u
cd "$(dirname "$0")" || exit 1

fail=0
pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
note() { printf '  \033[2m-\033[0m    %s\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

MAC_FILES="install.sh lib/common.sh lib/obsidian.sh lib/claude.sh lib/sync.sh lib/vault.sh README.md"
WIN_FILES="install.ps1 lib/Common.ps1 lib/Obsidian.ps1 lib/Claude.ps1 lib/Sync.ps1 lib/Vault.ps1 README.md"
# One per line. Read with `while read`, so names with spaces stay intact.
PAYLOAD='template/manifest.json
template/README.md
template/START HERE.md
template/Companies/_README.md
template/People/_README.md
template/Me/profile.md
template/Me/style.md
template/Meta/Vault Guide.md
template/Meta/Templates/Company Profile.md
template/Meta/Templates/Monthly Review.md
template/Meta/Templates/Permanent Note.md
template/Meta/Templates/Person.md
template/Meta/Templates/Project.md
template/Meta/Templates/Session Note.md
template/Meta/Templates/Weekly Review.md
template/.obsidian/app.json
template/.obsidian/core-plugins.json
template/.obsidian/templates.json
template/.obsidian/appearance.json
skills/brain-setup/SKILL.md
skills/vault-filing/SKILL.md
skills/vault-rollup/SKILL.md
skills/email-triage/SKILL.md
template/Me/method.md
template/roles/documents/folders.txt
template/roles/assets/folders.txt
template/roles/assets/files/Meta/Templates/Asset.md
template/roles/reporting/folders.txt
template/roles/reporting/files/Meta/Templates/Recurring Report.md
template/roles/creative/folders.txt
template/roles/creative/files/Meta/Templates/Reference.md
template/roles/enabling/folders.txt
template/roles/enabling/files/Meta/Friction Vocabulary.md
template/roles/enabling/files/Meta/Templates/Person.md
template/roles/enabling/files/Meta/Templates/Asset.md'

head_ "Files present"
for f in $MAC_FILES; do
  [ -f "MacOS/$f" ] && pass "MacOS/$f" || bad "MacOS/$f is missing"
done
for f in $WIN_FILES; do
  [ -f "Windows/$f" ] && pass "Windows/$f" || bad "Windows/$f is missing"
done
payload_missing=0
payload_count=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  payload_count=$((payload_count+1))
  for base in MacOS Windows; do
    if [ ! -f "$base/$f" ]; then bad "$base/$f is missing"; payload_missing=$((payload_missing+1)); fi
  done
done <<< "$PAYLOAD"
[ "$payload_missing" = "0" ] && pass "all $payload_count shared payload files present in both folders"

head_ "The installer is executable"
[ -x MacOS/install.sh ] && pass "MacOS/install.sh has the execute bit" \
  || bad "MacOS/install.sh is not executable — run: chmod +x MacOS/install.sh"

head_ "Shell syntax"
for f in MacOS/install.sh MacOS/lib/*.sh sync-shared.sh check.sh; do
  bash -n "$f" 2>/dev/null && pass "$f" || bad "$f has a syntax error"
done

head_ "PowerShell syntax"
if command -v pwsh >/dev/null 2>&1; then
  for f in Windows/install.ps1 Windows/lib/*.ps1; do
    if pwsh -NoProfile -Command "
        \$e=\$null; \$t=\$null
        [System.Management.Automation.Language.Parser]::ParseFile('$PWD/$f',[ref]\$t,[ref]\$e) | Out-Null
        if (\$e -and \$e.Count) { exit 1 } else { exit 0 }" >/dev/null 2>&1; then
      pass "$f"
    else
      bad "$f has a syntax error"
    fi
  done
else
  note "pwsh not installed, so PowerShell syntax was not checked"
  note "install it with: brew install --cask powershell"
fi

head_ "MacOS and Windows carry identical shared files"
if diff -r MacOS/template Windows/template >/dev/null 2>&1; then pass "template/ matches"
else bad "template/ differs — run ./sync-shared.sh"; fi
if diff -r MacOS/skills Windows/skills >/dev/null 2>&1; then pass "skills/ matches"
else bad "skills/ differs — run ./sync-shared.sh"; fi

head_ "Tokens line up"
declared="$(grep -oE '"name": "[A-Z_]+"' MacOS/template/manifest.json | sed 's/.*: "//;s/"//' | sort)"
used="$(grep -rhoE '\{\{[A-Z_]+\}\}' MacOS/template | tr -d '{}' | sort -u)"
subbed="$(grep -oE '\{\{[A-Z_]+\}\}' MacOS/lib/common.sh | tr -d '{}' | sort -u)"
[ "$declared" = "$subbed" ] && pass "manifest and the macOS substitution list agree" \
  || bad "manifest declares [$(echo "$declared" | tr '\n' ' ')] but macOS substitutes [$(echo "$subbed" | tr '\n' ' ')]"
missing="$(comm -23 <(echo "$used") <(echo "$subbed") || true)"
[ -z "$missing" ] && pass "every token used in the template gets substituted" \
  || bad "used but never substituted: $(echo "$missing" | tr '\n' ' ')"

head_ "Role extras are staged, not applied"
# The installer no longer asks what someone's work produces. It stages every set of
# extras into the vault and /brain-setup infers which one fits, confirms it, and
# applies it. That splits one mechanism across a script and a skill, so the things
# that have to agree are checked here: the sets exist, both installers stage them,
# neither installer asks, and the skill knows where to look.
n_overlay="$(find MacOS/template/roles -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n_overlay" -gt 0 ]; then
  pass "$n_overlay role overlay templates under template/roles"
else
  bad "no role overlay templates under template/roles"
fi

if grep -q "not -path './roles/\*'" MacOS/lib/vault.sh; then
  pass "macOS base note copy excludes roles/"
else
  bad "macOS base note copy would copy roles/ into the vault as notes"
fi
if grep -q 'rolesDir' Windows/lib/Vault.ps1; then
  pass "Windows base note copy excludes roles\\"
else
  bad "Windows base note copy would copy roles\\ into the vault as notes"
fi

role_keys="$(sed -n '/"keys": \[/,/\]/p' MacOS/template/manifest.json |
  grep -o '"[a-z]*"' | grep -v '^"keys"$' | tr -d '"')"
if [ -z "$role_keys" ]; then
  bad "could not read roles.keys from template/manifest.json"
else
  missing=""
  for k in $role_keys; do
    [ -d "MacOS/template/roles/$k" ]   || missing="$missing $k(macOS folder)"
    [ -d "Windows/template/roles/$k" ] || missing="$missing $k(Windows folder)"
    # The skill applies these by name, so every key has to appear in it.
    grep -q "\`$k\`" MacOS/skills/brain-setup/SKILL.md || missing="$missing $k(brain-setup)"
  done
  n_keys="$(echo $role_keys | wc -w | tr -d ' ')"
  if [ -z "$missing" ]; then
    pass "all $n_keys role keys have an overlay folder on both platforms and appear in brain-setup"
  else
    bad "role keys not fully wired up:$missing"
  fi
fi

if grep -q 'stage_role_overlays "$real" "$tpl"' MacOS/lib/vault.sh &&
   grep -q 'Add-StagedRoleOverlays -RealPath' Windows/lib/Vault.ps1; then
  pass "both installers stage the role extras into the vault"
else
  bad "an installer no longer stages the role extras, so /brain-setup has nothing to apply"
fi

if grep -q 'Meta/.roles' MacOS/skills/brain-setup/SKILL.md; then
  pass "brain-setup knows the staged extras are in Meta/.roles"
else
  bad "brain-setup does not mention Meta/.roles — the staged extras would never be applied"
fi

# Guards against the question creeping back into the installer, which is where it used
# to be and where a mailbox scan beats a terminal prompt.
if grep -rq "What does your work mainly produce" MacOS/install.sh Windows/install.ps1; then
  bad "an installer asks what the work produces again — that is /brain-setup's job now"
else
  pass "neither installer asks what the work produces"
fi

head_ "Obsidian's own placeholders survive"
n="$(grep -rl '{{title}}' MacOS/template/Meta/Templates 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" = "7" ] && pass "{{title}} present in all 7 note templates" \
  || bad "{{title}} found in $n of 7 note templates"

head_ "No landing pages used as download URLs"
if grep -rn 'obsidian\.md/download\|claude\.ai/download' MacOS/lib Windows/lib 2>/dev/null \
     | grep -v '^\S*: *#' | grep -viE 'do not|install it from|get it from|NOT installed' | grep -q .; then
  bad "a landing page is being used as a download URL — see ARCHITECTURE.md"
else
  pass "downloads point at real files, not landing pages"
fi

head_ "Nothing organisation-specific in what ships"
# The template and skills go to every employee at any organisation, so they must
# carry no real names, email addresses or company names. Tokens are how anything
# person-specific gets in, at install time.
leaks=0
if grep -rnoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
     MacOS/template MacOS/skills Windows/template Windows/skills 2>/dev/null \
     | grep -viE 'example\.(com|org|net)|example\.co\.uk' | grep -q .; then
  bad "a real-looking email address is in the shipped payload (use example.com)"
  leaks=1
fi
if [ -f .brand-deny ]; then
  # Optional: one name or phrase per line that must never ship. Useful while
  # de-branding a copy that started life inside one organisation.
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    if grep -rniqF "$term" MacOS/template MacOS/skills Windows/template Windows/skills 2>/dev/null; then
      bad "'$term' (from .brand-deny) is in the shipped payload"
      leaks=1
    fi
  done < .brand-deny
else
  note "no .brand-deny file — add one with names or company names that must never ship"
fi
[ "$leaks" = "0" ] && pass "no real addresses or denied terms in template/ or skills/"

head_ "The Vault Guide can actually be updated"
# The guide is the one file a re-run may replace, because every skill reads its
# conventions from it at run time and a convention change has to be able to reach a
# vault that already exists. That only works if all four parts are present: a version
# in the shipped guide, a package version to stamp, the refresh branch in both
# installers, and the flag that forces it. Losing any one of them silently turns the
# documented update path back into a dead end.
gv="$(awk 'NR<=30 && /^guide_version:/ { gsub(/[^0-9]/, "", $0); print $0; exit }' "MacOS/template/Meta/Vault Guide.md")"
case "$gv" in
  ''|*[!0-9]*) bad "template/Meta/Vault Guide.md has no numeric guide_version in its frontmatter" ;;
  *)           pass "shipped Vault Guide is v$gv" ;;
esac

pv="$(awk -F'"' '/"packageVersion"/ { print $4; exit }' MacOS/template/manifest.json)"
[ -n "$pv" ] && pass "manifest declares packageVersion $pv" \
             || bad "template/manifest.json has no packageVersion for the vault stamp to record"

if grep -q 'refresh_vault_guide "$real" "$tpl"' MacOS/lib/vault.sh &&
   grep -q 'write_vault_stamp "$real" "$tpl"' MacOS/lib/vault.sh; then
  pass "macOS create_vault refreshes the guide and writes the stamp"
else
  bad "macOS create_vault no longer calls refresh_vault_guide and write_vault_stamp"
fi

if grep -q 'Update-VaultGuide -RealPath' Windows/lib/Vault.ps1 &&
   grep -q 'Write-VaultStamp  -RealPath' Windows/lib/Vault.ps1; then
  pass "Windows New-Vault refreshes the guide and writes the stamp"
else
  bad "Windows New-Vault no longer calls Update-VaultGuide and Write-VaultStamp"
fi

grep -q -- '--replace-guide' MacOS/install.sh && pass "macOS has --replace-guide" \
                                              || bad "macOS install.sh lost --replace-guide"
grep -q -- 'ReplaceGuide' Windows/install.ps1 && pass "Windows has -ReplaceGuide" \
                                              || bad "Windows install.ps1 lost -ReplaceGuide"

# -Path applies wildcard rules, where [ ] is a character class and a backslash escapes
# the next character, so a vault under "OneDrive - Company [UK]" is not found. The guide
# functions take paths straight from the person's answers, so they must use -LiteralPath.
# Checked only over those functions: the rest of Vault.ps1 predates this rule.
guide_fns="$(sed -n '/^function Get-GuideVersion/,/^function New-Vault/p' Windows/lib/Vault.ps1)"
if printf '%s' "$guide_fns" | grep -q 'Test-Path \$\|Get-Content -Path\|Get-Content -Raw -Path\|Move-Item -Path\|Copy-Item -Path'; then
  bad "a Vault Guide function uses -Path where it needs -LiteralPath"
else
  pass "the Vault Guide functions use -LiteralPath throughout"
fi

head_ "The public site and the installers agree"
# The repo is public and the site is built from it, so two things are checked here:
# that no working notes are tracked, and that the filenames the installers fetch are
# the filenames the workflow publishes. Renaming an archive in one place and not the
# other gives every colleague a 404 with no other symptom.
if [ -f .github/workflows/pages.yml ]; then
  pass "the Pages workflow is present"
else
  bad ".github/workflows/pages.yml is missing — nothing publishes the site"
fi

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  tracked="$(git ls-files docs/brainstorms docs/sessions 2>/dev/null)"
  if [ -z "$tracked" ]; then
    pass "no working notes are tracked by git"
  else
    bad "working notes are tracked and this repo is public: $(echo "$tracked" | tr '\n' ' ')"
  fi
else
  note "not a git repo here, so tracked-file check skipped"
fi

for pair in "MacOS/install.sh:brain-macos.tar.gz" "Windows/install.ps1:brain-windows.zip"; do
  f="${pair%%:*}"; asset="${pair##*:}"
  if grep -q "$asset" "$f" && grep -q "$asset" .github/workflows/pages.yml; then
    pass "$f and the workflow agree on $asset"
  else
    bad "$f and the workflow disagree about $asset — a piped install would 404"
  fi
done

if [ -f site/index.html ]; then
  missing=""
  for asset in brain-macos.tar.gz brain-windows.zip; do
    grep -q "$asset" site/index.html || missing="$missing $asset"
  done
  [ -z "$missing" ] && pass "the install guide links both archives" \
                    || bad "site/index.html does not mention:$missing"
else
  bad "site/index.html is missing — the site would publish no install guide"
fi

head_ "No stray build artefacts"
if [ -d dist ] || ls ./*.zip >/dev/null 2>&1; then
  bad "there is a dist/ folder or a stray zip — the two platform folders are the deliverable"
else
  pass "no dist/ folder, no stray zips"
fi

printf '\n'
if [ "$fail" = "0" ]; then
  printf '\033[32mAll checks passed.\033[0m Both folders are ready to zip and share.\n\n'
  exit 0
else
  printf '\033[31m%s check(s) failed.\033[0m Fix those before sharing.\n\n' "$fail"
  exit 1
fi
