#!/usr/bin/env bash
#
# Brain installer — macOS
#
# Sets up a context brain: Obsidian, the Claude desktop app, a structured vault in
# the home folder named after the owner's work email (jsmith@... -> ~/jsmith-brain),
# and the skills that populate and maintain it.
#
#     ./install.sh                    do it
#     ./install.sh --dry-run          say what it would do, change nothing
#     ./install.sh --replace-skills   also refresh skills that are already there
#     ./install.sh --replace-guide    also take the shipped Vault Guide
#
# Needs no administrator rights.
#
# It is safe to run more than once, and safe to run on a machine that already has
# a brain. Every step checks first and skips what is already there. A note, a
# skill, an Obsidian setting and Obsidian's own config are never overwritten.
#
# The one exception is Meta/Vault Guide.md, which carries a version and is
# replaced when the shipped one is newer, because it is the file every skill
# reads its conventions from and a convention change has to be able to reach an
# existing vault. The old guide is kept beside it, and an unversioned or
# hand-written guide is never touched without --replace-guide.

set -u
set -o pipefail

# --- arguments ---------------------------------------------------------------

DRY_RUN=0
REPLACE_SKILLS=0
REPLACE_GUIDE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|--check) DRY_RUN=1 ;;
    --replace-skills)  REPLACE_SKILLS=1 ;;
    --replace-guide)   REPLACE_GUIDE=1 ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'Unknown option: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# --- where the package is ----------------------------------------------------

# Where the packaged MacOS folder is hosted. Published by
# .github/workflows/pages.yml on every push, so this points at the current build.
#
# It is only ever used when this script is NOT sitting next to a template/ folder,
# because resolve_payload checks SCRIPT_DIR first. So a copy someone downloaded and
# unpacked always uses its own files and never touches the network, and a piped run
# fetches the package it belongs to. Set BRAIN_PACKAGE_URL to override.
BRAIN_PACKAGE_URL="${BRAIN_PACKAGE_URL:-https://sistergroup.github.io/install-brain/brain-macos.tar.gz}"

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TMP_PAYLOAD=""
cleanup() {
  [ -n "$TMP_PAYLOAD" ] && rm -rf "$TMP_PAYLOAD"
  [ -n "${SUMMARY_FILE:-}" ] && rm -f "$SUMMARY_FILE"
  return 0
}
trap cleanup EXIT

resolve_payload() {
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/template" ] && [ -d "$SCRIPT_DIR/lib" ]; then
    PAYLOAD="$SCRIPT_DIR"
    return 0
  fi
  if [ -z "$BRAIN_PACKAGE_URL" ]; then
    cat >&2 <<MSG

Install stopped: run this from the folder it came in.

  cd <the MacOS folder> && ./install.sh

Piping it from a URL only works if BRAIN_PACKAGE_URL points at a hosted copy
of that folder.
MSG
    exit 1
  fi
  printf '==> Fetching the installer package\n'
  TMP_PAYLOAD="$(mktemp -d)" || { echo "Could not create a temporary directory." >&2; exit 1; }
  if ! curl -fsSL --retry 3 --retry-delay 2 "$BRAIN_PACKAGE_URL" \
       | tar -xzf - -C "$TMP_PAYLOAD" 2>/dev/null; then
    cat >&2 <<MSG

Install stopped: could not download the installer package from
  $BRAIN_PACKAGE_URL

Either the network is blocked or that URL is not published yet. Ask for the
Brain installer folder, unzip it, and run ./install.sh from inside it.
MSG
    exit 1
  fi
  if [ -d "$TMP_PAYLOAD/template" ]; then
    PAYLOAD="$TMP_PAYLOAD"
  else
    _tpl="$(/usr/bin/find "$TMP_PAYLOAD" -maxdepth 2 -type d -name template -print -quit 2>/dev/null || true)"
    [ -n "$_tpl" ] || { echo "The downloaded package did not contain a template/ folder." >&2; exit 1; }
    PAYLOAD="$(dirname "$_tpl")"
  fi
}

resolve_payload

# shellcheck source=lib/common.sh
. "$PAYLOAD/lib/common.sh"
. "$PAYLOAD/lib/obsidian.sh"
. "$PAYLOAD/lib/claude.sh"
. "$PAYLOAD/lib/sync.sh"
. "$PAYLOAD/lib/vault.sh"

# --- preflight ---------------------------------------------------------------

mkdir -p "$(dirname "$BRAIN_LOG")" 2>/dev/null || true
log "=== Brain install started ($(uname -sr), $(uname -m), dry_run=$DRY_RUN) ==="

[ "$(uname -s)" = "Darwin" ] || die "This is the macOS installer and this is not a Mac. Use the Windows package instead."
[ "$(id -u)" != "0" ] || die "Do not run this with sudo. It installs into your own home folder and needs no administrator rights."
command -v curl >/dev/null 2>&1 || die "curl is missing, which should not be possible on a Mac. Ask IT."

SETUP_DATE="$(date +%Y-%m-%d)"
NEEDS_DRIVE_MIRROR=0
ADOPTED=0

# Created here, not lazily, so records written inside a run_step subshell all
# land in the same file.
SUMMARY_FILE="$(mktemp)" || SUMMARY_FILE=""

if [ "$DRY_RUN" = "1" ]; then
cat <<BANNER

  Brain — dry run
  ─────────────────────────────────────────────────────────────
  Nothing will be installed, created or changed. This only
  reports what a real run would do.

BANNER
else
cat <<BANNER

  Brain — setup
  ─────────────────────────────────────────────────────────────
  Installs Obsidian and the Claude desktop app, then creates
  your vault in your home folder.

  No administrator rights needed. Safe to run again: every
  step checks first and never overwrites anything that is
  already there.

BANNER
fi

# --- who you are -------------------------------------------------------------

step "About you"
say "  Used to label your own notes. Nothing is sent anywhere."
ask OWNER_NAME    "Your full name"        "${OWNER_NAME:-}"
ask OWNER_EMAIL   "Your work email (the Microsoft 365 one)" "${OWNER_EMAIL:-}"
ask COMPANY_NAME  "The company you work for" "${COMPANY_NAME:-}"

# Nothing is asked about the work itself. What it produces, how it arrives and who
# it is with are all inferred by /brain-setup from the mailbox, calendar and Teams,
# then stated back with the evidence and confirmed. The installer stages every set
# of role extras into the vault so the skill can apply the one that fits.

# The folder is named from the email so it is recognisable inside a sync folder.
# Where it goes is the next question — the home folder is only the default.
VAULT_NAME="$(vault_name_from_email "$OWNER_EMAIL")"
VAULT_PATH=""
VAULT_REAL=""
VAULT_LINK=""

# --- a brain you already have ------------------------------------------------

step "Looking for a brain you already have"
if EXISTING="$(find_existing_vault)"; then
  say "  Found one at $EXISTING"
  if confirm "Use that one, and just add anything it is missing?"; then
    ADOPTED=1
    VAULT_PATH="$EXISTING"
    VAULT_REAL="$EXISTING"
    VAULT_LINK=""
    SYNC_PROVIDER="$(provider_from_path "$EXISTING")"
    SYNC_LOCATION="$EXISTING"
    ok "Using your existing vault. Its notes, settings and skills stay exactly as they are."
    say "  Its location is not changed either."
    record "Existing vault at $EXISTING adopted — nothing in it replaced"
  else
    say "  Leaving it alone and setting up a separate one."
    record "Existing vault at $EXISTING left untouched; created a separate vault"
  fi
else
  skip "None found — setting one up"
fi

# --- where it goes -----------------------------------------------------------

if [ "$ADOPTED" = "1" ]; then
  step "Where your brain folder should go"
  skip "Leaving your existing vault where it is: $VAULT_REAL"
  step "Backing it up"
  skip "Leaving your existing setup alone (looks like: $SYNC_PROVIDER)"
else
  choose_location
  choose_sync
fi

# --- dry run stops here ------------------------------------------------------

if [ "$DRY_RUN" = "1" ]; then
  step "What a real run would do"

  if obsidian_installed_path >/dev/null; then
    skip "Obsidian — already installed, would skip"
  else
    say "  + would install Obsidian"
  fi

  if claude_app_path >/dev/null; then
    skip "Claude desktop app — already installed, would skip"
  else
    say "  + would install the Claude desktop app"
  fi

  if is_vault "$VAULT_REAL"; then
    say "  · vault at $VAULT_REAL exists — would add only missing folders and notes"
  else
    say "  + would create the vault at $VAULT_REAL"
  fi

  if [ -f "$VAULT_REAL/Meta/Vault Guide.md" ]; then
    _iv="$(guide_version_of "$VAULT_REAL/Meta/Vault Guide.md")"
    _sv="$(guide_version_of "$PAYLOAD/template/Meta/Vault Guide.md")"
    if [ "$REPLACE_GUIDE" = "1" ]; then
      say  "  + would replace the Vault Guide with v$_sv, keeping yours beside it (--replace-guide)"
    elif [ "$_iv" = "0" ]; then
      skip "Vault Guide — carries no version, would leave it alone"
    elif [ "$_sv" -gt "$_iv" ]; then
      say  "  + would update the Vault Guide v$_iv -> v$_sv, keeping yours beside it"
    else
      skip "Vault Guide — already v$_iv, would leave it alone"
    fi
  fi

  if [ -n "$VAULT_LINK" ]; then
    if [ -e "$VAULT_LINK" ]; then
      skip "shortcut $VAULT_LINK — something is already there, would leave it alone"
    else
      say "  + would add a shortcut at $VAULT_LINK"
    fi
  fi

  for d in "$PAYLOAD"/skills/*/; do
    [ -d "$d" ] || continue
    s="$(basename "$d")"
    if [ -e "$VAULT_PATH/.claude/skills/$s" ]; then
      skip "skill $s - already there, would leave alone"
    else
      say "  + would install skill $s"
    fi
  done

  if [ -d "$VAULT_PATH/Meta/.roles" ]; then
    skip "role extras — already staged, would leave alone"
  else
    say "  + would stage every set of role extras for /brain-setup to apply"
  fi

  if [ -e "$VAULT_PATH/CLAUDE.md" ]; then skip "CLAUDE.md — exists, would leave alone"
  else say "  + would write CLAUDE.md"; fi

  if [ -s "$OBSIDIAN_CONFIG_DIR/obsidian.json" ] && grep -Fq "\"$VAULT_REAL\"" "$OBSIDIAN_CONFIG_DIR/obsidian.json" 2>/dev/null; then
    skip "Obsidian registration — already registered, would leave alone"
  elif [ -s "$OBSIDIAN_CONFIG_DIR/obsidian.json" ]; then
    say "  + would register the vault alongside your existing ones, without changing which opens"
  else
    say "  + would register the vault as Obsidian's default"
  fi

  printf '\n  Nothing was changed. Drop --dry-run to do it for real.\n\n'
  exit 0
fi

# --- do the work -------------------------------------------------------------

# The vault is the deliverable, so a failure there is fatal. Everything else is
# wrapped: a convenience must never take the run down with it, or the employee
# never reaches the instructions for what to do next.
run_step "Installing Obsidian"       install_obsidian
run_step "Installing the Claude app" install_claude_app

create_vault "$VAULT_REAL" "$PAYLOAD"

if [ "$ADOPTED" != "1" ]; then
  [ -z "$VAULT_LINK" ] || run_step "Adding a shortcut in your home folder" link_vault "$VAULT_LINK" "$VAULT_REAL"
  run_step "Pinning the OneDrive folder" pin_onedrive_folder "$VAULT_REAL"
fi

run_step "Installing the brain skills"            install_skills "$VAULT_PATH" "$PAYLOAD"
run_step "Registering the vault with Obsidian"    register_vault "$VAULT_REAL"

# --- what is left ------------------------------------------------------------

print_summary

step "Done — four short steps left, and they all happen in the Claude app"
cat <<NEXT

  Your vault is at $VAULT_PATH
  Sync: $SYNC_PROVIDER
NEXT

if [ -n "$VAULT_LINK" ] && [ -L "$VAULT_LINK" ]; then
  printf '  Shortcut: %s\n' "$VAULT_LINK"
fi

if [ "$NEEDS_DRIVE_MIRROR" = "1" ]; then
cat <<DRIVE

  Google Drive needs one manual step, because it cannot be scripted:
  open Google Drive for desktop > Preferences > Folders from your computer,
  click "Add folder", choose $VAULT_PATH, and set it to Mirror.
DRIVE
fi

cat <<NEXT

  1. Open Claude and sign in.
  2. Connect Microsoft 365, in Settings > Connectors > Microsoft 365 > Connect.
  3. Add the three brain skills to your own account. They are waiting as zips in
     $VAULT_PATH/Meta/Setup
     In Claude: Customize > Skills > + > Create skill > Upload a skill.
  4. Start a chat, add the folder $VAULT_PATH, and type:  /brain-setup

  Claude will say what it wants to read before it reads anything, draft your
  profile, style, companies, people and projects, then ask about the rest.

  Step 3 is by hand because Claude only sees skills that are on your own
  account, and nothing can put them there from outside. One minute, once.

  All of this is written out in $VAULT_PATH/START HERE.md
  Install log: $BRAIN_LOG

NEXT

if have_tty && claude_app_path >/dev/null 2>&1; then
  if confirm "Open Claude now?"; then
    open -a "$(claude_app_path)" >>"$BRAIN_LOG" 2>&1 || true
  fi
fi

log "=== Brain install finished ==="
