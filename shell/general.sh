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

# repo <name> — cd to a repo by name, case-insensitively, so `repo networthy`
# finds NetWorthy.
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

# dcsync — pull latest dotclaude config, verify ~/.claude symlinks are healthy.
# Check-only (bootstrap.sh --check): no npm/uv/playwright installs, so it's fast.
dcsync() {
  git -C "$HOME/dotclaude" pull --ff-only || return
  bash "$HOME/dotclaude/bootstrap.sh" --check
}

# dfsync — cd to dotfiles, pull latest, re-run install (idempotent), sync
# dotclaude too, then reload the shell. Run this at the start of new work.
dfsync() {
  cd "$HOME/dotfiles" || return
  git pull --ff-only && ./install.sh
  dcsync
  # shellcheck source=/dev/null
  . "$HOME/.bashrc"
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
