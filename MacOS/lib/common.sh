#!/usr/bin/env bash
# Shared helpers. Sourced by install.sh — not meant to be run directly.

BRAIN_LOG="${BRAIN_LOG:-$HOME/Library/Logs/brain-install.log}"

# --- output ------------------------------------------------------------------

_c_reset=$'\033[0m'; _c_bold=$'\033[1m'; _c_dim=$'\033[2m'
_c_green=$'\033[32m'; _c_yellow=$'\033[33m'; _c_red=$'\033[31m'; _c_blue=$'\033[34m'

log()  { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$BRAIN_LOG"; }
say()  { printf '%s\n' "$*"; log "SAY  $*"; }
step() { printf '%s==>%s %s\n' "$_c_blue$_c_bold" "$_c_reset" "$*"; log "STEP $*"; }
ok()   { printf '  %s+%s %s\n' "$_c_green" "$_c_reset" "$*"; log "OK   $*"; }
skip() { printf '  %s-%s %s\n' "$_c_dim" "$_c_reset" "$*"; log "SKIP $*"; }
warn() { printf '  %s!%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; log "WARN $*"; }
die()  { printf '\n%sInstall stopped:%s %s\n' "$_c_red$_c_bold" "$_c_reset" "$*" >&2
         printf 'Full log: %s\n' "$BRAIN_LOG" >&2; log "DIE  $*"; exit 1; }

# --- summary -----------------------------------------------------------------
# Every step records what it did or did not do, so the end of the run says
# plainly what changed. On a re-run most lines should read "left alone".

SUMMARY_FILE="${SUMMARY_FILE:-}"

record() {
  [ -n "$SUMMARY_FILE" ] || SUMMARY_FILE="$(mktemp)"
  printf '%s\n' "$*" >> "$SUMMARY_FILE"
  log "REC  $*"
}

print_summary() {
  [ -n "$SUMMARY_FILE" ] && [ -s "$SUMMARY_FILE" ] || return 0
  printf '\n%sWhat this run did%s\n' "$_c_bold" "$_c_reset"
  while IFS= read -r line; do printf '  · %s\n' "$line"; done < "$SUMMARY_FILE"
}

# --- running a step safely ---------------------------------------------------
# The vault is the deliverable. Everything around it — app installs, the link,
# the OneDrive pin, the skills, the Obsidian registration — is a convenience and
# must never take the run down with it. The Windows twin learned this the hard
# way: a failure inside vault registration aborted the script and the employee
# never saw the four steps they still had to do.
#
# Each step runs in a subshell, so even a die() inside one is contained. Steps
# wrapped this way must not need to set variables the rest of the script reads;
# records still work because they append to a file.
run_step() { # run_step "Name" function [args...]
  local name="$1"; shift
  if ( "$@" ); then return 0; fi
  # A contained die() has already printed its own reason just above, so point at
  # it rather than repeating or contradicting it.
  warn "$name did not finish — see the message just above."
  say  "  Carrying on. This does not stop the rest of the setup."
  record "$name: did not finish, skipped (see the log)"
  return 0
}

# --- input -------------------------------------------------------------------
# Read from the terminal, not stdin. Under `curl ... | bash` stdin is the script
# itself, so a plain `read` consumes the script and the install dies silently.

TTY=/dev/tty
have_tty() { [ -r "$TTY" ] && [ -w "$TTY" ]; }

ask() { # ask VAR "Prompt" ["default"]
  local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
  if ! have_tty; then
    [ -n "$__default" ] || die "Need an answer for '$__prompt' but there is no terminal to ask on. Re-run the installer directly instead of piping it, or set ${__var}= in the environment."
    printf -v "$__var" '%s' "$__default" 2>/dev/null || eval "$__var=\$__default"
    return 0
  fi
  while :; do
    if [ -n "$__default" ]; then
      printf '  %s [%s]: ' "$__prompt" "$__default" > "$TTY"
    else
      printf '  %s: ' "$__prompt" > "$TTY"
    fi
    IFS= read -r __reply < "$TTY" || __reply=""
    [ -n "$__reply" ] || __reply="$__default"
    [ -n "$__reply" ] && break
    printf '  (needed)\n' > "$TTY"
  done
  eval "$__var=\$__reply"
}

choose() { # choose VAR "Prompt" "opt1" "opt2" ...
  local __var="$1"; shift
  local __prompt="$1"; shift
  local __opts=("$@") __i=1 __reply=""
  if ! have_tty; then
    eval "$__var=\${__opts[0]}"
    warn "No terminal to ask on — defaulting to '${__opts[0]}'."
    return 0
  fi
  printf '\n  %s\n' "$__prompt" > "$TTY"
  for __o in "${__opts[@]}"; do printf '    %d) %s\n' "$__i" "$__o" > "$TTY"; __i=$((__i+1)); done
  while :; do
    printf '  Choose 1-%d: ' "${#__opts[@]}" > "$TTY"
    IFS= read -r __reply < "$TTY" || __reply=""
    case "$__reply" in
      ''|*[!0-9]*) ;;
      *) if [ "$__reply" -ge 1 ] && [ "$__reply" -le "${#__opts[@]}" ]; then
           eval "$__var=\${__opts[$((__reply-1))]}"; return 0
         fi ;;
    esac
    printf '  (1-%d)\n' "${#__opts[@]}" > "$TTY"
  done
}

confirm() { # confirm "Question" -> 0 yes / 1 no. Defaults to yes with no terminal.
  local __reply=""
  have_tty || return 0
  printf '  %s [Y/n]: ' "$1" > "$TTY"
  IFS= read -r __reply < "$TTY" || __reply=""
  case "$__reply" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
}

# --- vault name --------------------------------------------------------------
# The vault folder is named after the local part of the owner's work email, so it
# is recognisable in a sync folder shared with other things: jsmith-brain,
# achen-brain. Lowercased, full stops removed, and anything else that is not safe
# in a folder name becomes a hyphen.
#
# Full stops are removed rather than turned into hyphens: it keeps a.chen@ and
# jsmith@ looking like the same convention, and a folder name with no dots in it
# can never be mistaken for a file.

vault_name_from_email() { # vault_name_from_email EMAIL -> "jsmith-brain"
  local part
  part="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/@.*//')"
  part="$(printf '%s' "$part" | sed -e 's/\.//g' -e 's/[^a-z0-9_-]/-/g' -e 's/--*/-/g' -e 's/^[-_]*//' -e 's/[-_]*$//')"
  [ -n "$part" ] || part="my"
  printf '%s-brain' "$part"
}

# --- token substitution ------------------------------------------------------
# Only the tokens we know about are replaced. Obsidian's own {{title}} and
# {{date}} placeholders inside Meta/Templates must survive untouched, so never
# do a blanket {{.*}} substitution here.

_sed_escape() { printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'; }

substitute_tokens() { # substitute_tokens FILE
  local f="$1" tmp
  tmp="$(mktemp)" || die "Could not create a temporary file."
  sed \
    -e "s/{{OWNER_NAME}}/$(_sed_escape "$OWNER_NAME")/g" \
    -e "s/{{OWNER_EMAIL}}/$(_sed_escape "$OWNER_EMAIL")/g" \
    -e "s/{{COMPANY_NAME}}/$(_sed_escape "$COMPANY_NAME")/g" \
    -e "s/{{VAULT_NAME}}/$(_sed_escape "$VAULT_NAME")/g" \
    -e "s/{{VAULT_PATH}}/$(_sed_escape "$VAULT_PATH")/g" \
    -e "s/{{SYNC_PROVIDER}}/$(_sed_escape "$SYNC_PROVIDER")/g" \
    -e "s/{{SYNC_LOCATION}}/$(_sed_escape "$SYNC_LOCATION")/g" \
    -e "s/{{SETUP_DATE}}/$(_sed_escape "$SETUP_DATE")/g" \
    "$f" > "$tmp" && mv "$tmp" "$f"
}

# --- downloads ---------------------------------------------------------------
# Download to a file and refuse anything that is obviously a web page.
#
# This exists because of a real bug: obsidian.md/download and claude.ai/download
# are HTML landing pages, not installers. curl happily saved the page as
# Obsidian.dmg and the mount then failed with a baffling error. Checking what
# actually arrived turns that into a clear message.
download_file() { # download_file URL DEST DESCRIPTION
  local url="$1" dest="$2" what="$3"

  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url" >>"$BRAIN_LOG" 2>&1; then
    log "DL-FAIL $what <- $url"
    return 1
  fi

  # An HTML landing page instead of a binary.
  if head -c 512 "$dest" 2>/dev/null | LC_ALL=C grep -qi '<!doctype\|<html'; then
    log "DL-HTML $what <- $url (got a web page, not a file)"
    return 1
  fi

  # Anything under a megabyte is not a desktop app installer.
  local size
  size="$(wc -c < "$dest" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ] || [ "$size" -lt 1000000 ]; then
    log "DL-SMALL $what <- $url ($size bytes)"
    return 1
  fi

  log "DL-OK $what ($size bytes)"
  return 0
}

# --- manifest ----------------------------------------------------------------
# manifest.json is the single source of truth for the folder list. Parsed with
# awk so the installer needs no jq and no python.

# A single top-level string value, e.g. manifest_value manifest.json packageVersion.
# Same awk-not-jq rule as the folder list: the installer must need nothing installed.
manifest_value() { # manifest_value MANIFEST_PATH KEY
  awk -v key="\"$2\"" '
    index($0, key) && index($0, ":") {
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      gsub(/^"|",?$|,$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$1"
}

manifest_folders() { # manifest_folders MANIFEST_PATH
  awk '
    /"folders"[[:space:]]*:[[:space:]]*\[/ { inside = 1; next }
    inside && /\]/                        { inside = 0 }
    inside {
      line = $0
      gsub(/[",]/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (length(line)) print line
    }
  ' "$1"
}
