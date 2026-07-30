#!/usr/bin/env bash
# Bring a fresh machine to a working state: toolchain, agent config, the repo
# fleet, and dependencies.
#
#   git clone git@github.com:GarrettMakesItLLC/dotfiles.git ~/workspace/dotfiles
#   bash ~/workspace/dotfiles/bootstrap/device.sh
#
# Idempotent — re-run it any time. It never overwrites a repo that already
# exists, and every install step is skipped when already satisfied.
#
# Anything needing sudo is REPORTED, never installed. A bootstrap script that
# silently escalates is one nobody can read before running.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/workspace}"
ORG=GarrettMakesItLLC
MANIFEST="$HERE/repos.tsv"

NODE_MAJOR=20
NPM_VERSION=10.8.2

INCLUDE_ARCHIVES=0
DO_INSTALL=1
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all) INCLUDE_ARCHIVES=1 ;;
    --no-install) DO_INSTALL=0 ;;
    --only) ONLY="${2:-}"; shift ;;
    -h|--help)
      cat <<'USAGE'
device.sh — set up this machine

  --all           also clone archived repos
  --no-install    clone and link only; skip dependency installs (fast)
  --only <repo>   act on one repo from the manifest
  -h, --help      this
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

MISSING=()   # needs a human
NOTES=()     # done, but worth reading

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
skip() { printf '  \033[90mskip\033[0m  %s\n' "$*"; }
work() { printf '  \033[36m..\033[0m    %s\n' "$*"; }
bad()  { printf '  \033[31mmiss\033[0m  %s\n' "$*"; }

# --------------------------------------------------------------------------
# 1. Toolchain
# --------------------------------------------------------------------------
say "Toolchain"

for cmd in git curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd"
  else
    bad "$cmd — install it: sudo apt install $cmd"
    MISSING+=("$cmd (sudo apt install $cmd)")
  fi
done

# nvm + node live in the user's home, so they install without sudo.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  work "installing nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >/dev/null 2>&1 \
    && ok "nvm installed" || bad "nvm install failed — see https://github.com/nvm-sh/nvm"
fi
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if command -v node >/dev/null 2>&1 && [ "$(node -v | cut -c2- | cut -d. -f1)" = "$NODE_MAJOR" ]; then
  ok "node $(node -v)"
elif command -v nvm >/dev/null 2>&1; then
  work "installing node $NODE_MAJOR"
  nvm install "$NODE_MAJOR" >/dev/null 2>&1 && nvm alias default "$NODE_MAJOR" >/dev/null 2>&1 \
    && ok "node $(node -v)" || bad "node $NODE_MAJOR install failed"
else
  bad "node $NODE_MAJOR — nvm unavailable"
  MISSING+=("node $NODE_MAJOR")
fi

# npm is pinned: an npm-11 lockfile passes CI and is then rejected by the deploy.
if command -v npm >/dev/null 2>&1; then
  if [ "$(npm -v)" = "$NPM_VERSION" ]; then
    ok "npm $NPM_VERSION"
  else
    work "pinning npm to $NPM_VERSION (was $(npm -v))"
    npm i -g "npm@$NPM_VERSION" >/dev/null 2>&1 && ok "npm $(npm -v)" \
      || NOTES+=("npm is $(npm -v), not the pinned $NPM_VERSION — lockfiles may be rejected on deploy")
  fi
fi

# AdventureOS is the only pnpm consumer, but it cannot be installed without this.
# corepack is not present on every machine — WSL images built from nodesource omit
# it — so `npm i -g` is the fallback that actually works rather than the tidier one.
if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm $(pnpm -v)"
elif command -v corepack >/dev/null 2>&1 && corepack enable pnpm >/dev/null 2>&1; then
  ok "pnpm enabled via corepack"
elif command -v npm >/dev/null 2>&1; then
  work "installing pnpm"
  npm i -g pnpm >/dev/null 2>&1 && ok "pnpm $(pnpm -v)" \
    || { bad "pnpm — needed by AdventureOS"; MISSING+=("pnpm (npm i -g pnpm)"); }
else
  bad "pnpm — needed by AdventureOS"
  MISSING+=("pnpm (npm i -g pnpm)")
fi

if command -v gh >/dev/null 2>&1; then
  ok "gh $(gh --version | head -1 | awk '{print $3}')"
  if gh auth status >/dev/null 2>&1; then
    ok "gh authenticated"
  else
    bad "gh not authenticated"
    MISSING+=("gh auth login  — or set GH_TOKEN (see integrations.md)")
  fi
else
  bad "gh — install: https://cli.github.com"
  MISSING+=("gh (https://cli.github.com)")
fi

# --------------------------------------------------------------------------
# 2. Shell + git config
# --------------------------------------------------------------------------
say "Shell and git config"
if [ -x "$HERE/../install.sh" ]; then
  bash "$HERE/../install.sh" 2>&1 | sed 's/^/  /'
else
  bad "dotfiles install.sh not found at $HERE/../install.sh"
fi

# --------------------------------------------------------------------------
# 3. Agent config — delegate to dotclaude, never reimplement its linking
# --------------------------------------------------------------------------
say "Agent config (dotclaude)"
if [ -d "$HOME/dotclaude/.git" ]; then
  ok "dotclaude present"
else
  work "cloning dotclaude"
  git clone -q "git@github.com:$ORG/dotclaude.git" "$HOME/dotclaude" \
    && ok "cloned" || bad "clone failed — check SSH access to $ORG"
fi
if [ -f "$HOME/dotclaude/bootstrap.sh" ]; then
  bash "$HOME/dotclaude/bootstrap.sh" 2>&1 | tail -20 | sed 's/^/  /'
else
  skip "dotclaude/bootstrap.sh not found"
fi

# --------------------------------------------------------------------------
# 4. The repo fleet
# --------------------------------------------------------------------------
say "Repos"
mkdir -p "$WORKSPACE"

if [ ! -f "$MANIFEST" ]; then
  bad "manifest missing: $MANIFEST"
  exit 1
fi

# Field-split on tabs; skip comments and blanks.
while IFS=$'\t' read -r name role pm boot; do
  case "${name:-}" in ''|\#*) continue ;; esac
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
  [ "$role" = archive ] && [ "$INCLUDE_ARCHIVES" -eq 0 ] && { skip "$name (archive)"; continue; }

  dir="$WORKSPACE/$name"
  if [ -d "$dir/.git" ]; then
    ok "$name present"
  else
    work "cloning $name"
    git clone -q "git@github.com:$ORG/$name.git" "$dir" \
      && ok "$name cloned" || { bad "$name clone failed"; continue; }
  fi

  # Put the checkout on the repo's default branch, current.
  def=$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  if [ -n "$def" ]; then
    git -C "$dir" switch -q "$def" 2>/dev/null || git -C "$dir" switch -qc "$def" "origin/$def" 2>/dev/null
    git -C "$dir" pull -q --ff-only 2>/dev/null || NOTES+=("$name: could not fast-forward $def — diverged or dirty")
  fi

  [ "$DO_INSTALL" -eq 0 ] && continue
  [ "$pm" = none ] && continue

  work "$name: installing ($pm)"
  case "$pm" in
    npm)  ( cd "$dir" && npm ci >/dev/null 2>&1 ) ;;
    pnpm) ( cd "$dir" && pnpm install --frozen-lockfile >/dev/null 2>&1 ) ;;
  esac
  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then
    ok "$name: dependencies installed"
    if [ "$boot" != "-" ] && [ -n "$boot" ]; then
      ( cd "$dir" && eval "$boot" >/dev/null 2>&1 ) \
        && ok "$name: $boot" \
        || NOTES+=("$name: '$boot' failed — usually needs env vars, see its CLAUDE.md")
    fi
  else
    NOTES+=("$name: dependency install failed — run it by hand to see why")
  fi
done < "$MANIFEST"

# --------------------------------------------------------------------------
# 5. What still needs a human
# --------------------------------------------------------------------------
say "Summary"

if [ ${#NOTES[@]} -gt 0 ]; then
  echo "  Worth reading:"
  for n in "${NOTES[@]}"; do echo "    - $n"; done
  echo
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "  Blocking — install or authenticate these, then re-run:"
  for m in "${MISSING[@]}"; do echo "    - $m"; done
  echo
fi

cat <<'HUMAN'
  These cannot be scripted — they are interactive or per-machine:

    1. Secrets. Populate ~/.config/secrets/*.env and any per-app env file
       (e.g. ~/.musclebuddy/agent.env). See dotclaude/integrations.md.
    2. MCP connectors. OAuth ones (Notion, Google, Sentry) authenticate in a
       browser on first use — run `/mcp` in a Claude session.
    3. Deployment env vars. Pull per app rather than copying: `npx vercel env pull`
       for frontends, the Railway MCP for backends.

  Then open a new shell (or `. ~/.bashrc`) and check with:

    bash ~/dotclaude/bootstrap.sh --check
HUMAN

# Blocking gaps are a non-zero exit so a caller can branch on it.
[ ${#MISSING[@]} -gt 0 ] && exit 1
exit 0
