# shellcheck shell=bash
# Node toolchain PATH.
# Sourced by shell/index.sh — not meant to be run directly.

# nvm, if present. Lazy would be nicer for shell startup, but several repos'
# tooling shells out to `node` non-interactively and needs it resolvable.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
fi

# Put npm's global bin on PATH.
#
# Without this, `npm i -g <tool>` installs successfully into a directory nothing
# searches, so the binary exists and the command does not — which reads as a
# failed install. On this setup only `node` and `npm` were symlinked into
# ~/.local/bin by hand, leaving pnpm, corepack, shellcheck and vercel installed
# but unreachable.
#
# Derived from `npm prefix -g` rather than hardcoded: pinning the path would
# silently stop resolving the moment node's version changes.
if command -v npm >/dev/null 2>&1; then
  _npm_global_bin="$(npm prefix -g 2>/dev/null)/bin"
  if [ -d "$_npm_global_bin" ]; then
    case ":$PATH:" in
      *":$_npm_global_bin:"*) : ;;
      *) PATH="$_npm_global_bin:$PATH" ;;
    esac
    export PATH
  fi
  unset _npm_global_bin
fi
