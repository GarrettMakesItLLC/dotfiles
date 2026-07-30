# shellcheck shell=bash
# Git aliases and branch-switching helpers.
# Sourced by shell/index.sh — not meant to be run directly.

# --- status and history ---------------------------------------------------

alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -20'

# --- the everyday verbs ---------------------------------------------------

alias gpl='git pull'
alias gp='git push'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gco='git switch'
alias gcb='git switch -c'
alias gf='git fetch --all --prune'

# --- branch switching -----------------------------------------------------

# `main` and `dev` as bare commands: switch and bring it current in one step.
# Almost every switch to an integration branch is immediately followed by a pull,
# and forgetting it is how you branch off a stale base.
#
# Functions rather than aliases so they can take the pull with them, and so they
# fail with a useful message instead of a raw git error when the branch is absent.
_switch_and_pull() {
  local branch="$1"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "not a git repository" >&2
    return 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/$branch" &&
    ! git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "no '$branch' branch here (local or on origin)" >&2
    return 1
  fi
  git switch "$branch" && git pull --ff-only
}

main() { _switch_and_pull main; }
dev() { _switch_and_pull dev; }

# Back to whatever branch you were on before.
alias back='git switch -'

# --- worktrees ------------------------------------------------------------

# The repos here use a `.worktrees/` convention, so these come up constantly.
alias gwl='git worktree list'

# gw <name> [branch] — create and enter a worktree. Branch defaults to
# feature/<name>, which is what the convention expects.
gw() {
  local name="$1" branch="${2:-feature/$1}"
  if [ -z "$name" ]; then
    echo "usage: gw <name> [branch]" >&2
    return 1
  fi
  git worktree add ".worktrees/$name" -b "$branch" && cd ".worktrees/$name" || return
}

# --- cleanup --------------------------------------------------------------

# Delete local branches whose upstream is gone. Prints them first — a silent bulk
# delete of branches is not something to run on trust.
gclean() {
  git fetch --prune
  local gone
  gone=$(git branch -vv | awk '/: gone]/ { print $1 }')
  if [ -z "$gone" ]; then
    echo "nothing to clean"
    return 0
  fi
  echo "$gone"
  read -r -p "delete these? [y/N] " reply
  [ "$reply" = "y" ] && echo "$gone" | xargs -r git branch -D
}
