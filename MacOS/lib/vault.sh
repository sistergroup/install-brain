#!/usr/bin/env bash
# Create the vault from the template, or complete an existing one.
#
# The governing rule in this file: nothing that already exists is ever changed.
# A second run adds what is missing and reports what it left alone.

# A folder is a brain if it has a Vault Guide in it. That is the one file every
# vault has and nothing else does.
is_vault() { # is_vault PATH
  [ -f "$1/Meta/Vault Guide.md" ]
}

# Look for a brain the owner already has, so a second run adopts it instead of
# creating a rival one beside it. Checks the name this install would use, the
# older plain "Brain" name, anything else matching *-brain, and the same inside
# whichever cloud folders are present. Prints the first hit.
find_existing_vault() {
  local c
  for c in \
    "$HOME/$VAULT_NAME" \
    "$HOME/Brain" \
    "$HOME"/*-brain \
    "$HOME"/Library/CloudStorage/OneDrive-*/"$VAULT_NAME" \
    "$HOME"/Library/CloudStorage/OneDrive-*/Brain \
    "$HOME"/Library/CloudStorage/OneDrive-*/*-brain \
    "$HOME"/Library/CloudStorage/GoogleDrive-*/My\ Drive/"$VAULT_NAME" \
    "$HOME"/Library/CloudStorage/GoogleDrive-*/My\ Drive/Brain \
    "$HOME"/Library/CloudStorage/GoogleDrive-*/My\ Drive/*-brain
  do
    [ -d "$c" ] || continue
    if is_vault "$c"; then
      # Resolve symlinks: the home-folder shortcut is checked first, and adopting
      # it would put the shortcut's path into every note instead of the real one.
      ( cd "$c" 2>/dev/null && pwd -P ) 2>/dev/null || printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

# Guess the sync provider from where a vault already sits, so an adopted vault's
# notes do not get told the wrong thing.
provider_from_path() { # provider_from_path PATH
  case "$1" in
    *OneDrive*)    printf 'OneDrive' ;;
    *GoogleDrive*) printf 'Google Drive' ;;
    *)             printf 'as already configured' ;;
  esac
}

# A vault with real content in it is never overwritten. "Populated" means the
# owner or Claude has put something here — not merely that the template's own
# stubs exist, which they always do straight after an install.
vault_is_populated() { # vault_is_populated PATH
  local p="$1" d
  [ -d "$p" ] || return 1

  # Anything filed in a content folder.
  for d in Projects Areas Resources Ideas Inbox Archive Journal; do
    [ -d "$p/$d" ] || continue
    [ -n "$(/usr/bin/find "$p/$d" -type f -name '*.md' -print -quit 2>/dev/null)" ] && return 0
  done

  # Any company folder that has been started. Companies/_README.md sits at depth
  # 1 and is part of the template, so only look deeper.
  [ -d "$p/Companies" ] && [ -n "$(/usr/bin/find "$p/Companies" -mindepth 2 -type f -name '*.md' -print -quit 2>/dev/null)" ] && return 0

  # A profile that has been filled in. The template ships with status: empty.
  if [ -f "$p/Me/profile.md" ] && ! grep -q '^status: empty' "$p/Me/profile.md"; then return 0; fi

  return 1
}

# --- the Vault Guide, and why it is the one file that can be replaced ---------
#
# Every other note in a vault belongs to the person: a re-run adds what is missing
# and never overwrites. The Vault Guide is different. It is declared the source of
# truth for folder names and conventions, and the skills read it at run time rather
# than hard-coding them, which is what lets a convention change without anyone
# reinstalling anything. That only works if a newer guide can actually reach an
# existing vault, so the guide carries `guide_version` in its frontmatter and a
# re-run replaces an older one.
#
# Two rules keep that from becoming the silent damage this installer must not do:
#
#   1. The old guide is moved aside, never merged. Reconciling someone's edits with
#      a new shipped version is not something a shell script can get right, and a
#      bad merge to the file that governs every skill is worse than a manual
#      reconciliation. They get told where their copy went.
#   2. A guide with no `guide_version` is left alone. It was written by hand or
#      predates versioning, which is exactly the case when this installer adopts a
#      brain somebody built themselves. --replace-guide opts in.

guide_version_of() { # guide_version_of FILE -> integer, 0 when absent or unversioned
  local f="$1" v=""
  if [ -f "$f" ]; then
    v="$(awk 'NR<=30 && /^guide_version:/ { gsub(/[^0-9]/, "", $0); print $0; exit }' "$f")"
  fi
  case "$v" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$v" ;; esac
}

refresh_vault_guide() { # refresh_vault_guide REAL_PATH TEMPLATE_DIR
  local real="$1" tpl="$2"
  local src="$tpl/Meta/Vault Guide.md" dest="$real/Meta/Vault Guide.md"

  # A missing guide is the base note copy's job, and it has already run. A guide it
  # just wrote is current by definition, so there is nothing to say about it.
  [ -f "$src" ] || return 0
  [ -f "$dest" ] || return 0
  [ "${GUIDE_JUST_WRITTEN:-0}" = "1" ] && return 0

  local shipped installed
  shipped="$(guide_version_of "$src")"
  installed="$(guide_version_of "$dest")"

  if [ "${REPLACE_GUIDE:-0}" != "1" ]; then
    if [ "$installed" = "0" ]; then
      skip "Vault Guide carries no version, left alone"
      say  "  Yours was written by hand or predates versioning, so the shipped guide"
      say  "  (v$shipped) was not applied. --replace-guide takes it and keeps yours beside it."
      record "Vault Guide: left alone (unversioned; shipped v$shipped)"
      return 0
    fi
    if [ "$shipped" -le "$installed" ]; then
      skip "Vault Guide already at v$installed"
      record "Vault Guide: already v$installed"
      return 0
    fi
  fi

  local keep="$real/Meta/Vault Guide (previous $SETUP_DATE).md" n=2
  while [ -e "$keep" ]; do
    keep="$real/Meta/Vault Guide (previous $SETUP_DATE-$n).md"
    n=$((n+1))
  done

  if ! mv "$dest" "$keep" 2>>"$BRAIN_LOG"; then
    warn "Could not move your Vault Guide aside, so it was left exactly as it is."
    record "Vault Guide: not updated (could not move the old one aside)"
    return 0
  fi

  if ! cp "$src" "$dest" 2>>"$BRAIN_LOG"; then
    mv "$keep" "$dest" 2>>"$BRAIN_LOG" || true
    warn "Could not write the new Vault Guide, so yours was put back."
    record "Vault Guide: not updated (copy failed, old one restored)"
    return 0
  fi
  substitute_tokens "$dest"

  if [ "$shipped" -le "$installed" ]; then
    ok "Vault Guide replaced with v$shipped (--replace-guide)"
  else
    ok "Vault Guide updated, v$installed -> v$shipped"
  fi
  say "  Your previous guide is beside it as \"$(basename "$keep")\"."
  say "  Anything you had changed needs re-applying by hand."
  record "Vault Guide: v$installed -> v$shipped, previous kept as $(basename "$keep")"
  return 0
}

# What this vault is running, so a later run — or a person asked to describe their
# setup — can tell without guessing. A dotfile because Obsidian ignores dotfiles and
# this is machine state, not a note.
#
# Only written when something it records actually changed, so a re-run that changes
# nothing still leaves every file in the vault byte-identical.
write_vault_stamp() { # write_vault_stamp REAL_PATH TEMPLATE_DIR
  local real="$1" tpl="$2" dest="$real/Meta/.brain.json"
  local pkg guide installed_on

  pkg="$(manifest_value "$tpl/manifest.json" packageVersion)"
  [ -n "$pkg" ] || pkg="unknown"
  guide="$(guide_version_of "$real/Meta/Vault Guide.md")"

  # The role is not known at install time — /brain-setup works it out and writes it
  # here when it applies an overlay. So an existing value is preserved, exactly like
  # the original install date, or a re-run would undo the skill's work.
  installed_on="$SETUP_DATE"
  local role="unset" prev
  if [ -f "$dest" ]; then
    prev="$(awk -F'"' '/"installed"/ { print $4; exit }' "$dest")"
    [ -n "$prev" ] && installed_on="$prev"
    prev="$(awk -F'"' '/"role"/ { print $4; exit }' "$dest")"
    [ -n "$prev" ] && role="$prev"
    if grep -Fq "\"packageVersion\": \"$pkg\"" "$dest" 2>/dev/null &&
       grep -Fq "\"guideVersion\": $guide" "$dest" 2>/dev/null; then
      skip "Version stamp already says package $pkg, guide v$guide"
      return 0
    fi
  fi

  cat > "$dest" <<JSON
{
  "packageVersion": "$pkg",
  "guideVersion": $guide,
  "role": "$role",
  "installed": "$installed_on",
  "stamped": "$SETUP_DATE"
}
JSON
  ok "Version stamp: package $pkg, guide v$guide"
  record "Version stamp: package $pkg, guide v$guide"
  return 0
}

create_vault() { # create_vault REAL_PATH PAYLOAD_DIR
  step "Vault"
  local real="$1" tpl="$2/template" folder

  [ -d "$tpl" ] || die "The installer package has no template/ folder. Re-download it."
  [ -f "$tpl/manifest.json" ] || die "The installer package has no template/manifest.json. Re-download it."

  if vault_is_populated "$real"; then
    say "  There is already a vault with notes in it at $real."
    say "  Nothing in it gets changed. Anything missing is added; everything else"
    say "  is left exactly as it is."
    REPAIR_ONLY=1
  fi

  mkdir -p "$real" || die "Could not create $real"

  # Folders come from the manifest so there is one source of truth for the shape.
  local n=0
  while IFS= read -r folder; do
    [ -n "$folder" ] || continue
    mkdir -p "$real/$folder"
    n=$((n+1))
  done < <(manifest_folders "$tpl/manifest.json")
  [ "$n" -gt 0 ] || die "Could not read the folder list from template/manifest.json."
  ok "$n folders"

  # Obsidian settings: only ever written when missing. They look like config
  # rather than content, but people change them — attachment folder, link style,
  # which core plugins are on — and clobbering that is exactly the kind of
  # silent damage this installer must not do.
  mkdir -p "$real/.obsidian"
  local o_added=0 o_kept=0 base
  for f in "$tpl/.obsidian/"*.json; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ -e "$real/.obsidian/$base" ]; then o_kept=$((o_kept+1)); continue; fi
    cp "$f" "$real/.obsidian/$base"
    o_added=$((o_added+1))
  done
  if [ "$o_kept" -gt 0 ]; then
    skip "Obsidian settings already there ($o_kept files), left alone"
  else
    ok "Obsidian settings"
  fi
  record "Obsidian settings: $o_added written, $o_kept left alone"

  GUIDE_JUST_WRITTEN=0

  # Notes: never overwrite one that already exists.
  local copied=0 kept=0 rel dest
  while IFS= read -r rel; do
    dest="$real/$rel"
    if [ -e "$dest" ]; then kept=$((kept+1)); continue; fi
    mkdir -p "$(dirname "$dest")"
    cp "$tpl/$rel" "$dest"
    substitute_tokens "$dest"
    copied=$((copied+1))
    [ "$rel" = "Meta/Vault Guide.md" ] && GUIDE_JUST_WRITTEN=1
    # roles/ holds the per-role overlays, not vault content. add_role_extras
    # copies the one that applies; the rest must never reach the vault.
  done < <(cd "$tpl" && /usr/bin/find . -type f -name '*.md' -not -path './roles/*' | sed 's|^\./||' | sort)

  if [ "$kept" -gt 0 ]; then
    ok "$copied notes written, $kept already there"
  else
    ok "$copied notes written"
  fi
  record "Template notes: $copied written, $kept already there"

  stage_role_overlays "$real" "$tpl"
  refresh_vault_guide "$real" "$tpl"
  write_vault_stamp "$real" "$tpl"

  write_welcome "$real"
}

# What the person said they mainly produce adds folders and templates on top of the
# base vault. A role only ever ADDS: nobody's vault is missing a place to put
# something because of an answer they gave in a terminal once.
# --- role extras, staged rather than applied ---------------------------------
#
# What someone's work mainly produces decides which extra folders and templates
# their vault wants: `Assets/` for someone who builds things, `Reporting/` for
# someone who produces numbers, a friction vocabulary for someone whose job is
# other people working better.
#
# The installer does not know the answer and does not ask. A cold multiple-choice
# question in a terminal gets a guess, and this is the answer that changes the
# folder structure, so it is the last one that should be guessed. `/brain-setup`
# works it out from the mailbox, the calendar and Teams, states its read with the
# evidence, and applies the overlay the person confirms.
#
# So the installer's job is to put every overlay where the skill can reach it,
# with tokens already substituted so the skill never has to know about tokens:
#
#   <vault>/Meta/.roles/<key>/folders.txt   folders to create
#   <vault>/Meta/.roles/<key>/files/**      templates to copy into place
#
# A dotfolder, because Obsidian ignores dotfolders and this is not vault content
# until one of them is applied. All five stay after one is applied, so a person
# whose work changes can have another applied later without reinstalling.
stage_role_overlays() { # stage_role_overlays REAL_PATH TEMPLATE_DIR
  local real="$1" tpl="$2/roles" dest_root="$real/Meta/.roles"
  local rel dest added=0 kept=0 keys=0

  [ -d "$tpl" ] || return 0

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$dest_root/$rel"
    if [ -e "$dest" ]; then kept=$((kept+1)); continue; fi
    mkdir -p "$(dirname "$dest")"
    cp "$tpl/$rel" "$dest"
    case "$rel" in *.md) substitute_tokens "$dest" ;; esac
    added=$((added+1))
  done < <(cd "$tpl" && /usr/bin/find . -type f | sed 's|^\./||' | sort)

  keys="$(cd "$tpl" && /usr/bin/find . -maxdepth 1 -type d -not -name . | wc -l | tr -d ' ')"

  if [ "$added" -gt 0 ]; then
    ok "$keys sets of role extras staged for /brain-setup to apply"
  else
    skip "role extras already staged ($kept files), left alone"
  fi
  record "Role extras staged: $added written, $kept already there, $keys sets"
  return 0
}

# ~/<name>-brain is the path everything refers to. When the real vault lives
# inside OneDrive, that path becomes a symlink to it so paths, docs and skills
# stay the same.
link_vault() { # link_vault VAULT_PATH REAL_PATH
  local link="$1" real="$2"
  [ "$link" = "$real" ] && return 0

  step "Linking $link"
  if [ -L "$link" ]; then
    local current; current="$(readlink "$link")"
    if [ "$current" = "$real" ]; then skip "Already linked"; return 0; fi
    warn "$link already points at $current"
    if confirm "Repoint it at $real?"; then rm "$link"; else return 0; fi
  elif [ -e "$link" ]; then
    # Not fatal: the vault itself is fine where it is, only the tidy home-folder
    # path is missing.
    warn "$link already exists and is a real folder, so it was left alone."
    say  "  Your vault is at $real and works. Use that path when adding the folder in Claude."
    record "Link at $link: not created (a real folder is already there)"
    return 0
  fi

  if ln -s "$real" "$link" 2>>"$BRAIN_LOG"; then
    ok "$link -> $real"
    record "Link: $link -> $real"
  else
    warn "Could not create the link at $link."
    say  "  Your vault is at $real and works. Use that path when adding the folder in Claude."
    record "Link: not created — use $real directly"
  fi
  return 0
}

write_welcome() { # write_welcome REAL_PATH
  if [ -e "$1/WELCOME.md" ]; then
    skip "WELCOME.md already there, left alone"
    record "WELCOME.md: left alone"
    return 0
  fi
  cat > "$1/WELCOME.md" <<MDEOF
# Welcome to your brain

This is your context brain: an ordinary folder of markdown notes that both you and Claude
can read and write. It is yours, it lives in your own storage, and nobody else reads it.

Right now it is an empty structure. Four short steps and Claude fills it in. They all
happen in the **Claude app** — you do not need a terminal for any of it.

There is a fuller version of this in \`START HERE.md\` beside this file.

## 1. Open Claude and sign in

Open **Claude** from your Applications folder and sign in with your work account.

## 2. Connect Microsoft 365

In Claude, go to **Settings → Connectors**, find **Microsoft 365** and click **Connect**,
then sign in with your work account. Your IT team has already authorised it for the
organisation, so you should not see a permissions screen you cannot approve.

This is what lets Claude read your own sent mail and calendar to work out how you write
and who you work with. It reads as you, over data you can already see, and only after you
have said yes to each source.

## 3. Add the three brain skills to your account

They teach Claude how to work with this vault, and they go on **your own** Claude
account. Three small files are waiting in \`Meta/Setup\` in this folder.

In Claude: **Customize > Skills > + > Create skill > Upload a skill**, then upload
\`brain-setup.zip\`, \`vault-filing.zip\` and \`vault-rollup.zip\` in turn.

Claude only sees skills that are on your own account, and nothing can put them there
from outside. Three uploads, once, and they are yours for good.

## 4. Add this folder and set the brain up

Start a new chat and **add this folder** — \`${VAULT_PATH}\` — using the folder or **+**
button, so Claude can read and write your notes. Then type:

\`\`\`
/brain-setup
\`\`\`

Claude will tell you exactly what it wants to read before it reads anything, draft your
profile, writing style, the companies and people you deal with and what you appear to be
working on, then ask you about the parts it could not work out.

Skipped step 3? Paste this instead and it still works:

> Read \`.claude/skills/brain-setup/SKILL.md\` in this folder and follow it.

Do go back and do step 3 though — \`vault-filing\` and \`vault-rollup\` have to be on your
account to run on their own.

## Then what

- Read \`Meta/Vault Guide.md\` once. It is the contract between you and Claude for this
  vault, and if you disagree with something in it, change it — it is the source of truth.
- At the end of a working session with Claude, ask it to file the session, and it writes a
  note into \`Journal/Sessions\`. Those condense into weekly and monthly reviews, so detail
  becomes summary on its own.
- Put anything you are not sure where to file into \`Inbox\`.
- Your notes also open in **Obsidian**, which is the nicer way to read and link them.

Set up ${SETUP_DATE}. Sync: ${SYNC_PROVIDER}.
MDEOF
  ok "WELCOME.md"
  record "WELCOME.md: written"
}
