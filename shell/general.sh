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
  match=$(find "$WORKSPACE" -maxdepth 1 -mindepth 1 -type d -iname "$name" | head -1)
  if [ -z "$match" ]; then
    echo "no repo matching '$name' in $WORKSPACE" >&2
    return 1
  fi
  cd "$match" || return
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
