#!/bin/bash
# Move Claude Code chat history and settings from an old Mac to a new one.
#
#   On the OLD Mac:  bash migrate-claude.sh export
#       -> creates ~/Desktop/claude-backup.tar.gz (copy it to the new Mac)
#
#   On the NEW Mac:  bash migrate-claude.sh import [path/to/claude-backup.tar.gz]
#       -> restores it, fixes chat-history paths if your username changed,
#          and installs Claude Code if it is missing.
#
#   On the NEW Mac, if you used Migration Assistant (files already there):
#                    bash migrate-claude.sh fix
#
# Close every Claude Code window/terminal before running.
# Nothing is deleted: anything replaced is moved to ~/claude-old-<timestamp>.

set -u

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/claude-old-$STAMP"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Claude Code names each history folder after the project's full path,
# with every character that isn't a letter or digit turned into "-".
encode() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# macOS sed needs  -i ''  where GNU sed needs  -i
if sed --version >/dev/null 2>&1; then SED_I=(-i); else SED_I=(-i ''); fi

check_not_running() {
  [ -n "${SKIP_RUNNING_CHECK:-}" ] && return
  if pgrep -x claude >/dev/null 2>&1; then
    die "Claude Code is still running. Quit it (type /exit in each Claude terminal) and run this again."
  fi
}

do_export() {
  check_not_running
  say "Packing up Claude Code from this Mac"
  [ -d "$HOME/.claude" ] || die "No ~/.claude folder found here - is this the old Mac?"
  OUT="$HOME/Desktop/claude-backup.tar.gz"
  items=".claude"
  [ -f "$HOME/.claude.json" ] && items="$items .claude.json"
  # Record this Mac's home folder so the new Mac knows what to rename from.
  printf '%s\n' "$HOME" > "$HOME/.claude/.migrated-from-home"
  # shellcheck disable=SC2086
  tar -czf "$OUT" -C "$HOME" $items || die "Could not create the backup."
  rm -f "$HOME/.claude/.migrated-from-home"
  n=$(find "$HOME/.claude/projects" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  ok "Saved $OUT ($(du -h "$OUT" | cut -f1), $n chats)"
  say "Next: copy claude-backup.tar.gz to the new Mac (AirDrop is easiest), then run there:"
  echo "    bash migrate-claude.sh import ~/Downloads/claude-backup.tar.gz"
}

do_import() {
  check_not_running
  ARCHIVE="${1:-}"
  if [ -z "$ARCHIVE" ]; then
    for c in "$HOME/Downloads/claude-backup.tar.gz" "$HOME/Desktop/claude-backup.tar.gz"; do
      [ -f "$c" ] && ARCHIVE="$c" && break
    done
  fi
  [ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || die "Can't find claude-backup.tar.gz. Pass its path: bash migrate-claude.sh import /path/to/claude-backup.tar.gz"

  say "Restoring Claude Code from $ARCHIVE"
  STAGE=$(mktemp -d)
  tar -xzf "$ARCHIVE" -C "$STAGE" || die "Could not unpack the backup."
  [ -d "$STAGE/.claude" ] || die "That file doesn't look like a Claude backup."

  # Keep anything already on this Mac (e.g. new chats) by merging, but
  # stash the originals first.
  if [ -e "$HOME/.claude" ] || [ -e "$HOME/.claude.json" ]; then
    mkdir -p "$BACKUP_DIR"
    [ -e "$HOME/.claude" ] && cp -R "$HOME/.claude" "$BACKUP_DIR/"
    [ -e "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$BACKUP_DIR/"
    ok "Copied what was already here to $BACKUP_DIR"
  fi
  mkdir -p "$HOME/.claude"
  # Merge: old-Mac files are added alongside anything new on this Mac.
  cp -R "$STAGE/.claude/." "$HOME/.claude/" || die "Copy failed."
  ok "Restored chat history, settings, skills, commands and agents"
  if [ -f "$STAGE/.claude.json" ]; then
    if [ -f "$HOME/.claude.json" ]; then
      warn "Replacing ~/.claude.json with the old Mac's (MCP servers, project settings). Original kept in $BACKUP_DIR"
    fi
    cp "$STAGE/.claude.json" "$HOME/.claude.json"
    ok "Restored ~/.claude.json"
  fi
  rm -rf "$STAGE"
  do_fix
}

do_fix() {
  say "Checking chat history matches this Mac's folders"
  P="$HOME/.claude/projects"
  [ -d "$P" ] || { warn "No chat history found in ~/.claude/projects."; finish; return; }

  OLD_HOME=""
  if [ -f "$HOME/.claude/.migrated-from-home" ]; then
    OLD_HOME=$(head -1 "$HOME/.claude/.migrated-from-home")
  elif [ -f "$HOME/.claude.json" ]; then
    # Most common /Users/<name> among the saved project paths.
    OLD_HOME=$(grep -o '"/Users/[^/"]*' "$HOME/.claude.json" | tr -d '"' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
  fi
  if [ -z "$OLD_HOME" ]; then
    OLD_HOME=$(ls "$P" | grep -o '^-Users-[^-]*' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}' | sed 's/^-Users-/\/Users\//')
  fi

  if [ -z "$OLD_HOME" ] || [ "$OLD_HOME" = "$HOME" ]; then
    ok "Your home folder is the same as before ($HOME) - no renaming needed"
  else
    warn "Old Mac home was $OLD_HOME, this Mac is $HOME - updating history to match"
    OLD_ENC=$(encode "$OLD_HOME")
    NEW_ENC=$(encode "$HOME")
    moved=0
    for d in "$P"/"$OLD_ENC"*; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      case "$name" in
        "$OLD_ENC"|"$OLD_ENC"-*) ;;   # exact home or something inside it
        *) continue ;;                # e.g. /Users/chris2 when old was /Users/chris
      esac
      new="$P/$NEW_ENC${name#"$OLD_ENC"}"
      if [ -d "$new" ]; then
        # Folder already exists (new chats on this Mac) - merge into it.
        mv -n "$d"/* "$new"/ 2>/dev/null
        rmdir "$d" 2>/dev/null || warn "Some files in $name were left in place (same name already existed)"
      else
        mv "$d" "$new"
      fi
      moved=$((moved + 1))
    done
    ok "Updated $moved project history folders"

    if [ -f "$HOME/.claude.json" ]; then
      [ -f "$BACKUP_DIR/.claude.json" ] || { mkdir -p "$BACKUP_DIR"; cp "$HOME/.claude.json" "$BACKUP_DIR/"; }
      # Only rewrite the path when followed by / or " so /Users/chris doesn't hit /Users/chris2.
      old_esc=$(printf '%s' "$OLD_HOME" | sed 's/[.[\*^$/]/\\&/g')
      new_esc=$(printf '%s' "$HOME" | sed 's/[&/\]/\\&/g')
      sed "${SED_I[@]}" -e "s/${old_esc}\([/\"]\)/${new_esc}\1/g" "$HOME/.claude.json"
      ok "Updated project paths in ~/.claude.json"
    fi
  fi
  rm -f "$HOME/.claude/.migrated-from-home"

  # Claude Code deletes chats older than cleanupPeriodDays (default 30).
  # Raise it so restored history isn't wiped on first launch.
  S="$HOME/.claude/settings.json"
  if [ ! -f "$S" ]; then
    printf '{\n  "cleanupPeriodDays": 365\n}\n' > "$S"
    ok "Set chat history to be kept for a year (it was 30 days)"
  elif ! grep -q cleanupPeriodDays "$S"; then
    cp "$S" "$S.bak-$STAMP"
    if [ -z "$(tr -d ' \t\n\r{}' < "$S")" ]; then
      printf '{\n  "cleanupPeriodDays": 365\n}\n' > "$S"
    else
      # Insert after the opening brace; keeps the rest of the file untouched.
      awk 'BEGIN{d=0} !d && /\{/ {sub(/\{/, "{\n  \"cleanupPeriodDays\": 365,"); d=1} {print}' "$S.bak-$STAMP" > "$S"
    fi
    ok "Set chat history to be kept for a year (it was 30 days)"
  else
    ok "History retention already set in settings.json"
  fi

  finish
}

finish() {
  say "Claude Code app"
  if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    ok "Claude Code is installed"
  else
    warn "Claude Code isn't installed - installing now"
    curl -fsSL https://claude.ai/install.sh | bash && ok "Installed Claude Code"
  fi

  say "Done. Your projects with saved chats:"
  ls "$HOME/.claude/projects" 2>/dev/null | sed "s/^$(encode "$HOME")-\{0,1\}/  ~\//" | head -40
  echo
  echo "To see old chats: open Terminal in one of those folders, run  claude  then type  /resume"
  echo "If a project now lives in a different folder than on the old Mac, tell Claude"
  echo "where it is and it can rename the matching history folder."
}

case "${1:-}" in
  export) do_export ;;
  import) shift; do_import "${1:-}" ;;
  fix)    check_not_running; do_fix ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
