# shellcheck shell=bash
# Load every secrets file, so adding one never means editing ~/.bashrc.
# Sourced by shell/index.sh — not meant to be run directly.

# Ordering is the point. `~/.bashrc` sources per-app env files directly, and
# one of those app-scoped files exports its own `GH_TOKEN`. That file is
# REGENERATED from Vercel OPS_* vars by that app's `bin/ops-pull.sh`, so:
#
#   - a shared token hand-added there is lost on the next pull, and
#   - whichever file is sourced last wins.
#
# This runs after those lines (the dotfiles hook sits at the end of ~/.bashrc),
# so `~/.config/secrets/github.env` supersedes the app-scoped token deliberately.
# Do not move this earlier without moving that reasoning with it.
_secrets_dir="$HOME/.config/secrets"
if [ -d "$_secrets_dir" ]; then
  for _s in "$_secrets_dir"/*.env; do
    # The glob yields itself when nothing matches.
    [ -e "$_s" ] || continue
    # A world-readable secrets file is a finding, not a warning to ignore.
    _perm=$(stat -c '%a' "$_s" 2>/dev/null || echo '')
    case "$_perm" in
      600 | 400 | '') : ;;
      *) printf 'warning: %s is mode %s — should be 600\n' "$_s" "$_perm" >&2 ;;
    esac
    # shellcheck source=/dev/null
    . "$_s"
  done
  unset _s _perm
fi
unset _secrets_dir
:
