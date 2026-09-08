#!/usr/bin/env bash
# Install the Claude desktop app, and put the brain skills where a session with
# the vault folder connected will find them.
#
# The desktop app, not the Claude Code CLI: almost nobody getting a brain will be
# working in a terminal, so the app is what they will actually open.

# The real installer endpoint. claude.ai/download is an HTML landing page — the
# API redirect below is what its macOS button actually points at.
CLAUDE_DMG_URL="${CLAUDE_DMG_URL:-https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect}"

claude_manual_note() {
  warn "Could not install the Claude desktop app automatically."
  say  "  Get it from https://claude.ai/download — everything else here is done."
  record "Claude desktop app: NOT installed — get it from claude.ai/download"
}

claude_app_path() {
  for p in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
    [ -d "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

# Only used to decide whether to mention the terminal route in the closing
# message. Its absence is not a problem and nothing installs it.
claude_cli_path() {
  command -v claude 2>/dev/null || return 1
}

install_claude_app() {
  step "Claude desktop app"

  local existing
  if existing="$(claude_app_path)"; then
    skip "Already installed at $existing"
    record "Claude desktop app: already installed, left alone"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    say "  Installing via Homebrew..."
    if brew install --cask claude >>"$BRAIN_LOG" 2>&1 && claude_app_path >/dev/null; then
      ok "Installed"
      record "Claude desktop app: installed"
      return 0
    fi
    warn "Homebrew install failed — falling back to a direct download. See the log."
  else
    skip "Homebrew not present — using a direct download instead"
  fi

  install_claude_app_from_dmg
}

# Direct .dmg install into ~/Applications. Needs no administrator rights, which
# matters on a managed Mac where Homebrew is absent and sudo is not available.
install_claude_app_from_dmg() {
  local tmp dmg mount app dest
  tmp="$(mktemp -d)" || { claude_manual_note; return 0; }
  dmg="$tmp/Claude.dmg"

  say "  Downloading the Claude desktop app..."
  if ! download_file "$CLAUDE_DMG_URL" "$dmg" "Claude desktop app"; then
    rm -rf "$tmp"
    claude_manual_note
    return 0
  fi

  mount="$tmp/mnt"; mkdir -p "$mount"
  if ! hdiutil attach -nobrowse -quiet -mountpoint "$mount" "$dmg" >>"$BRAIN_LOG" 2>&1; then
    rm -rf "$tmp"
    warn "Downloaded Claude but could not open the disk image."
    claude_manual_note
    return 0
  fi

  app="$(/usr/bin/find "$mount" -maxdepth 2 -name 'Claude.app' -print -quit 2>/dev/null || true)"
  if [ -z "$app" ]; then
    hdiutil detach "$mount" -quiet >>"$BRAIN_LOG" 2>&1 || true
    rm -rf "$tmp"
    warn "That download did not contain Claude.app."
    claude_manual_note
    return 0
  fi

  mkdir -p "$HOME/Applications"
  dest="$HOME/Applications/Claude.app"
  if cp -R "$app" "$dest" >>"$BRAIN_LOG" 2>&1; then
    xattr -dr com.apple.quarantine "$dest" >>"$BRAIN_LOG" 2>&1 || true
    ok "Installed to ~/Applications/Claude.app"
    record "Claude desktop app: installed"
  else
    warn "Could not copy Claude into ~/Applications."
    claude_manual_note
  fi

  hdiutil detach "$mount" -quiet >>"$BRAIN_LOG" 2>&1 || true
  rm -rf "$tmp"
  return 0
}

# The skills live inside the vault, so they travel with it: a Claude session with
# this folder connected picks them up, and there is nothing to keep in sync
# separately.
#
# Existing skills are never replaced. Someone who has edited their own copy keeps
# it, and re-running this installer will not undo their work. Pass
# --replace-skills to take the shipped versions instead.
install_skills() { # install_skills VAULT_PATH PAYLOAD_DIR
  step "Brain skills"
  local vault="$1" payload="$2" dest="$1/.claude/skills"
  local added=0 kept=0 replaced=0 name

  [ -d "$payload/skills" ] || die "The installer package has no skills/ folder. Re-download it."

  mkdir -p "$dest"
  for d in "$payload"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ -n "$name" ] || continue

    if [ -e "$dest/$name" ]; then
      if [ "${REPLACE_SKILLS:-0}" = "1" ]; then
        # ${name:?} so a surprise empty value can never make this rm -rf "$dest/".
        rm -rf "$dest/${name:?}"
        cp -R "$d" "$dest/$name"
        replaced=$((replaced+1))
      else
        kept=$((kept+1))
        continue
      fi
    else
      cp -R "$d" "$dest/$name"
      added=$((added+1))
    fi
  done

  [ "$added" -gt 0 ]    && ok "$added skills installed"
  [ "$replaced" -gt 0 ] && ok "$replaced skills replaced (--replace-skills)"
  if [ "$kept" -gt 0 ]; then
    skip "$kept skills already there, left exactly as they are"
    say  "  (re-run with --replace-skills to take the shipped versions instead)"
  fi
  record "Skills: $added added, $kept left alone, $replaced replaced"

  build_skill_zips "$vault" "$payload"
  write_claude_md "$vault"
}

# The desktop app only sees skills that are on the person's own claude.ai account,
# and the only way to put one there is to upload a zip of the skill folder by hand.
# So build the zips here, into the vault, ready to upload. Built at install time
# rather than shipped as binaries, so they can never drift from the SKILL.md files.
build_skill_zips() { # build_skill_zips VAULT_PATH PAYLOAD_DIR
  local vault="$1" payload="$2" dest="$1/Meta/Setup"
  local made=0 kept=0 name zip

  mkdir -p "$dest"

  for d in "$payload"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ -n "$name" ] || continue
    zip="$dest/$name.zip"

    if [ -e "$zip" ]; then kept=$((kept+1)); continue; fi

    # The zip must contain the skill folder itself, and the folder name must match
    # the skill name or claude.ai rejects the upload. -X drops the mac-specific
    # extra attributes that can confuse it.
    if ( cd "$payload/skills" && zip -qrX "$zip" "$name" ) 2>>"$BRAIN_LOG"; then
      made=$((made+1))
    elif ( cd "$payload/skills" && ditto -c -k --keepParent "$name" "$zip" ) 2>>"$BRAIN_LOG"; then
      made=$((made+1))
    else
      warn "Could not build $name.zip — you can still start setup by pasting the line in START HERE.md."
    fi
  done

  [ "$made" -gt 0 ] && ok "$made skill uploads prepared in Meta/Setup"
  [ "$kept" -gt 0 ] && skip "$kept skill uploads already in Meta/Setup, left alone"
  record "Skill uploads: $made built, $kept left alone"
  return 0
}

# CLAUDE.md is what tells a session in this folder to read the Vault Guide. It is
# never overwritten — someone may well have added their own standing instructions
# to it.
write_claude_md() { # write_claude_md VAULT_PATH
  local f="$1/CLAUDE.md"
  if [ -e "$f" ]; then
    skip "CLAUDE.md already there, left alone"
    record "CLAUDE.md: left alone"
    return 0
  fi

  cat > "$f" <<MDEOF
# Working in this vault

This folder is ${OWNER_NAME}'s context brain.

**Read \`Meta/Vault Guide.md\` before doing anything here.** It is the source of truth
for the folder structure, naming, frontmatter and the condensation pipeline. Take folder
names from it rather than assuming them.

Skills for this vault are in \`.claude/skills\`:

- \`brain-setup\` — one-time setup: scans Microsoft 365 and drafts the standing-context
  notes. Run it once, on a fresh vault.
- \`vault-filing\` — run at the end of a session that produced anything worth re-reading.
- \`vault-rollup\` — weekly and monthly condensation.
- \`email-triage\` — reads the inbox and writes a ranked list of what needs an answer into
  \`Inbox\`. Never sends, replies to or forwards anything.

These are plain files, so they work whether or not this Claude offers them as commands.
If \`/brain-setup\` is not offered by name, read \`.claude/skills/brain-setup/SKILL.md\`
and follow it. Same for the others.

Never write a credential into a note. Every file here syncs to a cloud provider.
MDEOF
  ok "Wrote CLAUDE.md"
  record "CLAUDE.md: written"
}
