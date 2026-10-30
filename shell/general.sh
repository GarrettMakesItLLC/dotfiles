# shellcheck shell=bash
# Navigation, listing, and the handful of everyday shortcuts.
# Sourced by shell/index.sh — not meant to be run directly.

# --- listing --------------------------------------------------------------

alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# --- navigation -----------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# The repos all live in one place, so jumping between them is constant.
export WORKSPACE="${WORKSPACE:-$HOME/workspace}"
alias ws='cd "$WORKSPACE"'

# repent — reload the current shell's config (aliases, PATH, everything).
alias repent='. "$HOME/.bashrc"'

# claude — clear the scrollback before every launch. Safe to self-reference:
# bash skips re-expanding an alias name within its own replacement, so the
# second `claude` here invokes the real command, not this alias again.
alias claude='clear && claude'

# addAlias — open the everyday-shortcuts file (this one) to add or edit one.
# Run `repent` after saving to pick it up in the current shell.
addAlias() {
  "${EDITOR:-vi}" "$HOME/dotfiles/shell/general.sh"
}

# repo <name> — cd to a repo by name, case-insensitively.
repo() {
  local name="$1" match
  if [ -z "$name" ]; then
    ls -1 "$WORKSPACE"
    return 0
  fi
  # Infra/archive repos live under Tools/ (bootstrap/repos.tsv), so a plain
  # top-level search misses `repo ci` / `repo platform` — fall back to Tools/
  # rather than searching the whole tree, which would also match a stray
  # same-named directory inside a product repo's own checkout.
  match=$(find "$WORKSPACE" -maxdepth 1 -mindepth 1 -type d -iname "$name" | head -1)
  [ -z "$match" ] && match=$(find "$WORKSPACE/Tools" -maxdepth 1 -mindepth 1 -type d -iname "$name" 2>/dev/null | head -1)
  if [ -z "$match" ]; then
    echo "no repo matching '$name' in $WORKSPACE" >&2
    return 1
  fi
  cd "$match" || return
}

# _sync_repo <dir> <branch> — put <dir> on <branch> and fast-forward it. The
# sync commands default to main so a checkout left on a feature branch doesn't
# silently "sync" that branch instead; a branch is named explicitly with -b.
# A dirty tree that blocks the switch fails loudly rather than being touched.
_sync_repo() {
  local dir="$1" branch="$2" cur
  cur=$(git -C "$dir" branch --show-current)
  if [ "$cur" != "$branch" ]; then
    echo "$(basename "$dir"): switching $cur -> $branch"
    git -C "$dir" switch "$branch" || return
  fi
  # A local-only branch has nothing to pull; that is not a failure.
  git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || return 0
  git -C "$dir" pull --ff-only
}

# _sync_branch_arg — parse `-b|--branch <name>` out of the args, leaving the rest
# in SYNC_REST. Sets SYNC_BRANCH (default main). Shared by dcsync/dfsync/dfAll.
_sync_branch_arg() {
  SYNC_BRANCH=main
  SYNC_REST=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -b | --branch)
        if [ -z "${2:-}" ]; then
          echo "$1 needs a branch name" >&2
          return 1
        fi
        SYNC_BRANCH="$2"
        shift 2
        ;;
      --branch=*)
        SYNC_BRANCH="${1#--branch=}"
        shift
        ;;
      *)
        SYNC_REST+=("$1")
        shift
        ;;
    esac
  done
}

# dcsync [-b <branch>] — switch dotclaude to main (or <branch>), pull latest,
# verify ~/.claude symlinks are healthy. Check-only (bootstrap.sh --check): no
# npm/uv/playwright installs, so it's fast.
dcsync() {
  _sync_branch_arg "$@" || return
  _sync_repo "$HOME/dotclaude" "$SYNC_BRANCH" || return
  bash "$HOME/dotclaude/bootstrap.sh" --check
}

# dfsync [-b <branch>] — cd to dotfiles, switch to main (or <branch>), pull
# latest, re-run install (idempotent), sync dotclaude on the same branch, then
# reload the shell. Run this at the start of new work.
dfsync() {
  _sync_branch_arg "$@" || return
  local branch="$SYNC_BRANCH"
  cd "$HOME/dotfiles" || return
  _sync_repo "$HOME/dotfiles" "$branch" && ./install.sh || return
  dcsync -b "$branch" || return
  # shellcheck source=/dev/null
  . "$HOME/.bashrc"
}

# dcbootstrap — full dotclaude install: symlinks + the npm/uv/playwright
# builds that dcsync's --check deliberately skips. For a stale or new machine.
dcbootstrap() {
  bash "$HOME/dotclaude/bootstrap.sh"
}

# dfbootstrap — full machine setup: toolchain, dotfiles, dotclaude, and the
# whole repo fleet (bootstrap/repos.tsv). For a brand-new or long-idle machine.
dfbootstrap() {
  bash "$HOME/dotfiles/bootstrap/device.sh" "$@"
}

# dfAll [-b <branch>] [device.sh args] — pull dotfiles + dotclaude (main unless
# -b), then run the full machine bootstrap (which runs dotclaude's full
# bootstrap.sh). One command to bring a machine current.
dfAll() {
  _sync_branch_arg "$@" || return
  local branch="$SYNC_BRANCH" rest=("${SYNC_REST[@]}")
  dfsync -b "$branch" && dfbootstrap "${rest[@]}"
}

# --- safety ---------------------------------------------------------------

# Prompt before clobbering. These are the three that cause irreversible loss.
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# --- misc -----------------------------------------------------------------

alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'

# Directory size, largest first.
alias biggest='du -sh -- * 2>/dev/null | sort -rh | head -20'

# What is listening, and on what.
alias ports='ss -tulpn 2>/dev/null || netstat -tulpn'

# mkcd <dir> — make it and enter it.
mkcd() { mkdir -p "$1" && cd "$1" || return; }
