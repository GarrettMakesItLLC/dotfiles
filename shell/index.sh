# shellcheck shell=bash
# Entry point. One line in ~/.bashrc sources this:
#
#   [ -f "$HOME/workspace/dotfiles/shell/index.sh" ] && . "$HOME/workspace/dotfiles/shell/index.sh"
#
# `install.sh` adds that line. Everything else is sourced from here, so adding a
# file means adding it below rather than editing ~/.bashrc on every machine.

_DOTFILES_SHELL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for _f in general node git secrets; do
  # shellcheck source=/dev/null
  [ -f "$_DOTFILES_SHELL/$_f.sh" ] && . "$_DOTFILES_SHELL/$_f.sh"
done
unset _f

# Machine-local additions that should never be committed — a work proxy, a
# machine-specific path, a secret-bearing export. Sourced last so it can override
# anything above.
if [ -f "$HOME/.bashrc.local" ]; then
  . "$HOME/.bashrc.local"
fi

# Sourcing this file must succeed even when the optional pieces above are absent.
# A bare `[ -f x ] && . x` as the last statement returns 1 when x is missing,
# which breaks `. index.sh && something` and any caller running under `set -e`.
:
