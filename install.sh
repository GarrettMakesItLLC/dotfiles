#!/usr/bin/env bash
# Wire this repo into the current machine. Idempotent — safe to re-run after a pull.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
marker='# dotfiles (GarrettMakesItLLC/dotfiles)'
line="[ -f \"$here/shell/index.sh\" ] && . \"$here/shell/index.sh\""

# --- shell ---------------------------------------------------------------

if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
  echo "shell: already wired in ~/.bashrc"
else
  {
    echo ""
    echo "$marker"
    echo "$line"
  } >>"$HOME/.bashrc"
  echo "shell: appended to ~/.bashrc"
fi

# --- git -----------------------------------------------------------------

# `include.path` rather than copying: a pull updates config with no re-install,
# and machine-specific values (user.email on a work box) stay in ~/.gitconfig
# where they override the include.
if [ -f "$here/git/config" ]; then
  if git config --global --get-all include.path | grep -qxF "$here/git/config"; then
    echo "git: already including $here/git/config"
  else
    git config --global --add include.path "$here/git/config"
    echo "git: added include.path"
  fi
fi

echo
echo "Done. Open a new shell, or: . ~/.bashrc"
echo "Machine-specific overrides go in ~/.bashrc.local (never committed)."
