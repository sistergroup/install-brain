#!/usr/bin/env bash
# Install Obsidian, and register a vault so the app opens straight into it.

# Obsidian publishes the current version in the manifest its own updater reads.
# Resolve the version from there, then build the real GitHub release URL.
# Do NOT point at obsidian.md/download — that is an HTML landing page, and
# downloading it produces a "dmg" that is actually a web page.
OBSIDIAN_RELEASES_JSON="${OBSIDIAN_RELEASES_JSON:-https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/desktop-releases.json}"
OBSIDIAN_CONFIG_DIR="$HOME/Library/Application Support/obsidian"

obsidian_latest_version() {
  curl -fsSL --retry 2 "$OBSIDIAN_RELEASES_JSON" 2>>"$BRAIN_LOG" \
    | sed -n 's/.*"latestVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1
}

obsidian_dmg_url() { # obsidian_dmg_url VERSION
  printf 'https://github.com/obsidianmd/obsidian-releases/releases/download/v%s/Obsidian-%s.dmg' "$1" "$1"
}

# Printed whenever the automated install does not work. Installing Obsidian by
# hand takes a minute and nothing else in the setup depends on it having
# happened first, so this is a warning and never a failure.
obsidian_manual_note() {
  warn "Could not install Obsidian automatically."
  say  "  Everything else here is done — your vault is set up and Claude can use it."
  say  "  To read your notes in Obsidian, install it from https://obsidian.md/download"
  say  "  and then re-run this installer; it will register the vault and skip the rest."
  record "Obsidian: NOT installed — install it from obsidian.md/download and re-run"
}

obsidian_installed_path() {
  for p in "/Applications/Obsidian.app" "$HOME/Applications/Obsidian.app"; do
    [ -d "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

install_obsidian() {
  step "Obsidian"
  local existing
  if existing="$(obsidian_installed_path)"; then
    skip "Already installed at $existing"
    record "Obsidian: already installed, left alone"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    say "  Installing via Homebrew..."
    if brew install --cask obsidian >>"$BRAIN_LOG" 2>&1; then
      ok "Installed via Homebrew"
      record "Obsidian: installed"
      return 0
    fi
    warn "Homebrew install failed — falling back to a direct download. See the log."
  else
    skip "Homebrew not present — using a direct download instead"
  fi

  install_obsidian_from_dmg
}

# Direct .dmg install into ~/Applications. Needs no administrator rights, which
# matters on a managed Mac where Homebrew is absent and sudo is not available.
install_obsidian_from_dmg() {
  local tmp dmg mount app dest version url

  version="$(obsidian_latest_version)"
  if [ -z "$version" ]; then
    warn "Could not work out the current Obsidian version."
    obsidian_manual_note
    return 0
  fi

  url="$(obsidian_dmg_url "$version")"
  tmp="$(mktemp -d)" || { obsidian_manual_note; return 0; }
  dmg="$tmp/Obsidian.dmg"

  say "  Downloading Obsidian $version..."
  if ! download_file "$url" "$dmg" "Obsidian $version"; then
    rm -rf "$tmp"
    obsidian_manual_note
    return 0
  fi

  mount="$tmp/mnt"; mkdir -p "$mount"
  if ! hdiutil attach -nobrowse -quiet -mountpoint "$mount" "$dmg" >>"$BRAIN_LOG" 2>&1; then
    rm -rf "$tmp"
    warn "Downloaded Obsidian but could not open the disk image."
    obsidian_manual_note
    return 0
  fi

  app="$(/usr/bin/find "$mount" -maxdepth 2 -name 'Obsidian.app' -print -quit 2>/dev/null || true)"
  if [ -z "$app" ]; then
    hdiutil detach "$mount" -quiet >>"$BRAIN_LOG" 2>&1 || true
    rm -rf "$tmp"
    warn "The Obsidian disk image did not contain Obsidian.app."
    obsidian_manual_note
    return 0
  fi

  mkdir -p "$HOME/Applications"
  dest="$HOME/Applications/Obsidian.app"
  if cp -R "$app" "$dest" >>"$BRAIN_LOG" 2>&1; then
    # Downloaded apps carry a quarantine flag; clearing it avoids a scary
    # first-launch dialog for an app the user did in fact ask for.
    xattr -dr com.apple.quarantine "$dest" >>"$BRAIN_LOG" 2>&1 || true
    ok "Installed Obsidian $version to ~/Applications"
    record "Obsidian: installed ($version)"
  else
    warn "Could not copy Obsidian into ~/Applications."
    obsidian_manual_note
  fi

  hdiutil detach "$mount" -quiet >>"$BRAIN_LOG" 2>&1 || true
  rm -rf "$tmp"
  return 0
}

# Add the vault to Obsidian's own config so the app opens into it rather than
# showing the vault picker. Obsidian must not be running while this is written,
# and must be restarted afterwards to pick the vault up.
register_vault() { # register_vault VAULT_PATH
  step "Registering the vault with Obsidian"
  local vault="$1" cfg="$OBSIDIAN_CONFIG_DIR/obsidian.json" id ts tmp

  [ -d "$vault/.obsidian" ] || { warn "No .obsidian folder in the vault — Obsidian will not recognise it. Skipping registration."
    record "Obsidian registration: skipped (no .obsidian folder)"; return 0; }

  # Already known to Obsidian: nothing to do, and no reason to touch the config.
  if [ -s "$cfg" ] && grep -Fq "\"$vault\"" "$cfg"; then
    skip "Already registered with Obsidian"
    record "Obsidian registration: already registered, left alone"
    return 0
  fi

  if pgrep -xq Obsidian 2>/dev/null; then
    if confirm "Obsidian is running and has to be closed to register the vault. Close it now?"; then
      osascript -e 'tell application "Obsidian" to quit' >>"$BRAIN_LOG" 2>&1 || true
      sleep 2
    else
      warn "Left Obsidian running — open the vault yourself with File > Open folder as vault."
      record "Obsidian registration: skipped (Obsidian left running)"
      return 0
    fi
  fi

  mkdir -p "$OBSIDIAN_CONFIG_DIR"
  id="$(openssl rand -hex 8 2>/dev/null || date +%s%N | shasum | cut -c1-16)"
  ts="$(( $(date +%s) * 1000 ))"

  if [ ! -s "$cfg" ]; then
    # No vaults yet, so this one is the one to open.
    cat > "$cfg" <<JSON
{
  "vaults": {
    "$id": {
      "path": "$vault",
      "ts": $ts,
      "open": true
    }
  }
}
JSON
    ok "Registered, and set as the vault Obsidian opens"
    record "Obsidian registration: registered as the default vault"
    return 0
  fi

  # There are other vaults already. Register this one but leave "open" false, so
  # whichever vault the owner currently has open stays the one that opens. Two
  # entries both claiming to be open makes Obsidian's startup unpredictable.
  cp "$cfg" "$cfg.brain-backup.$(date +%Y%m%d%H%M%S)"
  if ! tmp="$(mktemp)"; then
    warn "Could not create a temporary file, so Obsidian's config was left untouched."
    say  "  Open the vault once with File > Open folder as vault and Obsidian will remember it."
    record "Obsidian registration: config left untouched (no temporary file)"
    return 0
  fi
  # Insert a vault entry immediately after the opening of the "vaults" object.
  # Existing entries are preserved; a backup of the original sits alongside.
  if awk -v id="$id" -v path="$vault" -v ts="$ts" '
      !done && /"vaults"[[:space:]]*:[[:space:]]*\{/ {
        print
        printf "    \"%s\": { \"path\": \"%s\", \"ts\": %s, \"open\": false },\n", id, path, ts
        done = 1
        next
      }
      { print }
      END { if (!done) exit 3 }
    ' "$cfg" > "$tmp"; then
    mv "$tmp" "$cfg"
    ok "Registered alongside your existing vaults (they still open as before)"
    say "  Pick it from Obsidian's vault switcher, bottom left."
    record "Obsidian registration: added alongside existing vaults"
  else
    rm -f "$tmp"
    warn "Could not edit Obsidian's config safely — left it untouched. Open the vault once with File > Open folder as vault and Obsidian will remember it."
    record "Obsidian registration: config left untouched (could not edit safely)"
  fi
}
