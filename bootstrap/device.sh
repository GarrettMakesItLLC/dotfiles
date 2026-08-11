#!/usr/bin/env bash
# Bring a fresh machine to a working state: toolchain, agent config, the repo
# fleet, and dependencies.
#
#   git clone git@github.com:GarrettMakesItLLC/dotfiles.git ~/dotfiles
#   bash ~/dotfiles/bootstrap/device.sh
#
# Idempotent — re-run it any time. It never overwrites a repo that already
# exists, and every install step is skipped when already satisfied.
#
# Anything needing sudo is REPORTED, never installed. A bootstrap script that
# silently escalates is one nobody can read before running.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/workspace}"
# Only for dotclaude, which is not in the manifest — it is a prerequisite of the
# manifest step rather than a member of the fleet. Every other repo carries its
# own owner in repos.tsv, because they are not all under one org.
DOTCLAUDE_SLUG=GarrettMakesItLLC/dotclaude
MANIFEST="$HERE/repos.tsv"

NODE_MAJOR=24
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

# Put npm's global bin on PATH for the rest of this script.
#
# Without it, `npm i -g <tool>` below "succeeds" and the tool is still not
# invocable, so a verification like `pnpm -v` fails while the install's exit code
# says everything is fine. That is how this script reported `ok pnpm` with an empty
# version. `shell/node.sh` does the same thing for interactive shells; this script
# cannot rely on that having been sourced yet.
if command -v npm >/dev/null 2>&1; then
  _npm_bin="$(npm prefix -g 2>/dev/null)/bin"
  case ":$PATH:" in
    *":$_npm_bin:"*) : ;;
    *) [ -d "$_npm_bin" ] && PATH="$_npm_bin:$PATH" && export PATH ;;
  esac
  unset _npm_bin
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

# Only bother if the manifest actually has a pnpm consumer — installing a package
# manager nothing uses is dead weight, and this fleet has flipped between npm and
# pnpm before, so check the data instead of hardcoding a repo name here.
if grep -qP '^[^#\t]+\t[^\t]+\tpnpm\t' "$MANIFEST" 2>/dev/null; then
  # corepack is not present on every machine — WSL images built from nodesource
  # omit it — so `npm i -g` is the fallback that actually works rather than the
  # tidier one.
  if command -v pnpm >/dev/null 2>&1; then
    ok "pnpm $(pnpm -v)"
  elif command -v corepack >/dev/null 2>&1 && corepack enable pnpm >/dev/null 2>&1; then
    ok "pnpm enabled via corepack"
  elif command -v npm >/dev/null 2>&1; then
    work "installing pnpm"
    # Verify by invoking it, not by trusting the installer's exit code — the two
    # disagree whenever the global bin is not on PATH.
    if npm i -g pnpm >/dev/null 2>&1 && hash -r 2>/dev/null; command -v pnpm >/dev/null 2>&1; then
      ok "pnpm $(pnpm -v)"
    else
      bad "pnpm installed but not on PATH — open a new shell, or check \`npm prefix -g\`/bin"
      MISSING+=("pnpm on PATH (installed to $(npm prefix -g 2>/dev/null)/bin)")
    fi
  else
    bad "pnpm — needed by a repo in the manifest"
    MISSING+=("pnpm (npm i -g pnpm)")
  fi
else
  skip "pnpm (no manifest consumer)"
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
  git clone -q "git@github.com:$DOTCLAUDE_SLUG.git" "$HOME/dotclaude" \
    && ok "cloned" || bad "clone failed — check SSH access to $DOTCLAUDE_SLUG"
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
while IFS=$'\t' read -r slug role pm boot; do
  case "${slug:-}" in ''|\#*) continue ;; esac
  # The manifest carries owner/repo because not every repo is under one org.
  # The local directory is named after the repo alone.
  name="${slug##*/}"
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && [ "$ONLY" != "$slug" ] && continue
  [ "$role" = archive ] && [ "$INCLUDE_ARCHIVES" -eq 0 ] && { skip "$name (archive)"; continue; }

  # `product` repos are the daily-work fleet and stay flat at the workspace root;
  # `infra`/`archive` repos group under `Tools/` so the root isn't cluttered with
  # repos nobody opens day to day. dotfiles is the one `infra` exception: this
  # script only runs from an already-cloned dotfiles checkout, so it has to stay
  # flat at $WORKSPACE/dotfiles — same reasoning as dotclaude staying outside the
  # manifest entirely, and it's where "Setup on a new machine" tells you to clone
  # it. An `infra` repo already checked out flat otherwise (a machine bootstrapped
  # before this split existed) is left there rather than re-cloned into Tools/ —
  # that would silently fork the checkout in two places, which is exactly the
  # duplication this distinction exists to avoid.
  if [ "$role" = product ] || [ "$name" = dotfiles ]; then
    dir="$WORKSPACE/$name"
  else
    dir="$WORKSPACE/Tools/$name"
    [ -d "$WORKSPACE/$name/.git" ] && dir="$WORKSPACE/$name"
  fi

  if [ -d "$dir/.git" ]; then
    ok "$name present"
  else
    mkdir -p "$(dirname "$dir")"
    work "cloning $slug"
    git clone -q "git@github.com:$slug.git" "$dir" \
      && ok "$name cloned" || { bad "$slug clone failed"; continue; }
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
  # The shared @gmi/* packages live on GitHub Packages, which requires auth even
  # for a package this org owns — a bare `npm ci` 401s. Every consumer's own
  # CLAUDE.md already documents `NODE_AUTH_TOKEN=$GITHUB_TOKEN npm ci` as the
  # manual workaround; this is that same substitution, made automatic. A no-op
  # for pnpm repos and for anyone who already exports NODE_AUTH_TOKEN.
  case "$pm" in
    npm)  ( cd "$dir" && NODE_AUTH_TOKEN="${NODE_AUTH_TOKEN:-$GH_TOKEN}" npm ci >/dev/null 2>&1 ) ;;
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
       (e.g. ~/.<app>/agent.env). See dotclaude/integrations.md.
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
