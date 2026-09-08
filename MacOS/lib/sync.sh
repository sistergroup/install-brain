#!/usr/bin/env bash
# Two separate questions, in this order:
#
#   1. Where should the brain folder go?   -> choose_location
#   2. Should anything back it up?         -> choose_sync
#
# Question 1 offers exactly two answers: the home folder, or a path they type.
# Cloud folders are not listed as options, because a typed path inside OneDrive
# or Google Drive is detected by question 2 anyway and a list of every cloud root
# on the machine made a simple question look complicated.
#
# They are separate because they are separate decisions. Someone may well want
# the folder in ~/Documents and no cloud copy at all, or in a cloud folder and
# nothing further. Neither answer should be inferred from the other.
#
# One real constraint has to be told to people rather than hidden: OneDrive only
# syncs what is inside the OneDrive folder, so it cannot back up a folder
# elsewhere. Google Drive Desktop can mirror any folder. Where an option is
# impossible for the location chosen, say why instead of silently omitting it.
#
# What choose_location sets:
#   VAULT_REAL      where the files physically live
#   VAULT_PATH      the path everything refers to - the same thing
#   VAULT_LINK      an optional shortcut in the home folder, or empty
#
# What choose_sync sets:
#   SYNC_PROVIDER   for the notes and the closing summary
#   SYNC_LOCATION   likewise
#   NEEDS_DRIVE_MIRROR  1 when the owner has to add a mirrored folder in Drive

find_onedrive_roots() {
  # Business accounts land in ~/Library/CloudStorage/OneDrive-<Org>; older or
  # personal setups sometimes sit directly in the home folder.
  { /bin/ls -d "$HOME/Library/CloudStorage/OneDrive-"* 2>/dev/null || true
    /bin/ls -d "$HOME/OneDrive - "* 2>/dev/null || true
    [ -d "$HOME/OneDrive" ] && printf '%s\n' "$HOME/OneDrive" || true
  } | sed '/^$/d'
}

find_gdrive_roots() {
  { /bin/ls -d "$HOME/Library/CloudStorage/GoogleDrive-"*/My\ Drive 2>/dev/null || true
    [ -d "$HOME/Google Drive/My Drive" ] && printf '%s\n' "$HOME/Google Drive/My Drive" || true
  } | sed '/^$/d'
}

google_drive_installed() { [ -d "/Applications/Google Drive.app" ]; }

# Somewhere the vault must not go. A vault needs to be an ordinary writable
# folder the owner controls; these are none of those things.
path_is_sensible() { # path_is_sensible PARENT
  local p="$1"
  case "$p" in
    ""|"/"|"/System"|"/System/"*|"/Library"|"/Library/"*|"/usr"|"/usr/"*|"/bin"|"/bin/"*|"/sbin"|"/sbin/"*|"/etc"|"/etc/"*|"/private"|"/private/"*|"/Applications"|"/Volumes")
      warn "$p is not somewhere a vault can live."
      return 1 ;;
  esac
  [ "${p#/}" != "$p" ] || { warn "Please give a full path, starting with / or ~."; return 1; }
  [ -d "$p" ] || { warn "$p does not exist."; return 1; }
  [ -w "$p" ] || { warn "$p is not writable by you."; return 1; }
  return 0
}

# Bounded on purpose: a prompt that can loop forever will, if the input is
# redirected or someone keeps mistyping. Three goes, then fall back.
ask_custom_parent() { # prints a validated parent folder, or nothing
  local reply expanded tries=0
  while [ "$tries" -lt 3 ]; do
    tries=$((tries+1))
    ask reply "Full path to the folder it should go inside (blank to go back)" ""
    [ -n "$reply" ] || { printf ''; return 1; }
    # Expand a leading ~ ourselves; `ask` reads raw text, so the shell never does.
    case "$reply" in
      "~") expanded="$HOME" ;;
      "~/"*) expanded="$HOME/${reply#\~/}" ;;
      *) expanded="$reply" ;;
    esac
    expanded="${expanded%/}"
    # If they typed the vault folder itself rather than its parent, accept both.
    if [ "$(basename "$expanded")" = "$VAULT_NAME" ]; then
      expanded="$(dirname "$expanded")"
    fi
    if path_is_sensible "$expanded"; then printf '%s' "$expanded"; return 0; fi
  done
  warn "That is three tries — going with the home folder instead."
  printf ''
  return 1
}

# Which known cloud folder, if any, a path sits inside. Used only to tell people
# the truth about their options; it decides nothing on its own.
containing_cloud() { # containing_cloud PATH -> "OneDrive" | "Google Drive" | ""
  local p="$1" r
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$p" in "$r"/*) printf 'OneDrive'; return 0 ;; esac
  done <<< "$(find_onedrive_roots)"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$p" in "$r"/*) printf 'Google Drive'; return 0 ;; esac
  done <<< "$(find_gdrive_roots)"
  printf ''
  return 0
}

# --- question 1: where the folder goes ---------------------------------------

choose_location() {
  step "Where your brain folder should go"

  say "  Just the folder location. Backing it up is the next question."
  say "  The home folder is the recommendation: it always exists, it is always"
  say "  writable, and it does not depend on a cloud client being signed in."
  say "  To have a cloud client sync the vault, type a folder inside OneDrive or"
  say "  Google Drive — the next question picks that up."

  local answer chosen_parent
  choose answer "Where should the folder go?" \
    "Your home folder — $HOME/$VAULT_NAME  (Recommended)" \
    "Somewhere else — I will type the folder"

  case "$answer" in
    "Somewhere else"*)
      # Three bad answers falls back to the home folder rather than looping.
      if ! chosen_parent="$(ask_custom_parent)"; then
        say "  Using the home folder instead."
        chosen_parent="$HOME"
      fi
      ;;
    *) chosen_parent="$HOME" ;;
  esac

  VAULT_REAL="$chosen_parent/$VAULT_NAME"
  VAULT_PATH="$VAULT_REAL"

  # A shortcut in the home folder, so there is always a short path to the vault
  # even when the real one is buried somewhere deep. Never for a vault that
  # already lives in the home folder.
  if [ "$chosen_parent" = "$HOME" ]; then VAULT_LINK=""; else VAULT_LINK="$HOME/$VAULT_NAME"; fi

  ok "Folder: $VAULT_REAL"
  return 0
}

# --- question 2: whether anything backs it up --------------------------------

choose_sync() {
  step "Backing it up"

  local inside answer
  inside="$(containing_cloud "$VAULT_REAL")"

  if [ -n "$inside" ]; then
    # Already in a synced folder. Still their call whether to add anything on
    # top, but say plainly that they do not need to.
    ok "This folder is inside $inside, so $inside already syncs it."
    SYNC_PROVIDER="$inside"
    SYNC_LOCATION="$VAULT_REAL"

    if [ "$inside" = "OneDrive" ] && { google_drive_installed || [ -n "$(find_gdrive_roots)" ]; }; then
      choose answer "Add anything else?"         "No — OneDrive is enough  (Recommended)"         "Also mirror it into Google Drive"
      case "$answer" in
        "Also"*)
          warn "Two sync clients on one folder can produce duplicate files and lose edits."
          if confirm "Do it anyway?"; then
            SYNC_PROVIDER="OneDrive and Google Drive"
            SYNC_LOCATION="$VAULT_REAL, synced by OneDrive and mirrored into Google Drive"
            NEEDS_DRIVE_MIRROR=1
          else
            ok "Leaving it to OneDrive."
          fi
          ;;
        *) ok "Leaving it to $inside." ;;
      esac
    fi
    return 0
  fi

  # Not in a cloud folder. Google Drive can mirror any folder; OneDrive cannot,
  # and people deserve to know why it is not on the list.
  if ! google_drive_installed && [ -z "$(find_gdrive_roots)" ]; then
    SYNC_PROVIDER="None"
    SYNC_LOCATION="the vault folder itself, with no cloud copy"
    say "  Nothing on this machine can back up a folder in this location:"
    say "  Google Drive for desktop is not installed, and OneDrive only syncs"
    say "  folders inside OneDrive itself."
    say "  Get Drive from https://www.google.com/drive/download/ and re-run this,"
    say "  or re-run and type a folder inside OneDrive."
    record "Sync: none available for this location"
    return 0
  fi

  say "  Google Drive can mirror a folder anywhere. OneDrive cannot — it only"
  say "  syncs folders inside OneDrive — so if you want OneDrive, re-run this and"
  say "  type a folder inside OneDrive."

  choose answer "Back this folder up to Google Drive?"     "Yes — mirror it into Google Drive"     "No — not for now"

  case "$answer" in
    Yes*)
      SYNC_PROVIDER="Google Drive"
      SYNC_LOCATION="$VAULT_REAL, mirrored into Google Drive"
      NEEDS_DRIVE_MIRROR=1
      google_drive_installed || warn "Google Drive for desktop is not installed — get it from https://www.google.com/drive/download/"
      ;;
    *)
      SYNC_PROVIDER="None"
      SYNC_LOCATION="the vault folder itself, with no cloud copy"
      ok "No cloud copy. You can add one later."
      ;;
  esac
  return 0
}

# OneDrive's Files On-Demand leaves placeholder stubs instead of real files, and
# both Obsidian and Claude need real bytes on disk. Ask OneDrive to keep the
# folder materialised; if the flag is unavailable, tell the user to do it by hand
# rather than pretending it worked.
pin_onedrive_folder() { # pin_onedrive_folder REAL_PATH
  [ "$SYNC_PROVIDER" = "OneDrive" ] || return 0
  local p="$1"
  if command -v xattr >/dev/null 2>&1; then
    xattr -w com.apple.fileprovider.pinned 1 "$p" >>"$BRAIN_LOG" 2>&1 || true
  fi
  say "  One thing to do in OneDrive: right-click the $VAULT_NAME folder and choose"
  say "  \"Always keep on this device\". Without it OneDrive can replace notes with"
  say "  placeholders and Obsidian will show them as empty."
  return 0
}
