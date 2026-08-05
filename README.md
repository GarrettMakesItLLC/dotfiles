# dotfiles

Shell, git, and terminal config shared across machines.

Sibling to [`dotclaude`](https://github.com/GarrettMakesItLLC/dotclaude), which does the same job for
the agent surface. Same reasoning: the config is the same on every machine, so it lives in one place
and each machine points at it.

## New machine, from nothing

This is the only repo you have to clone by hand. It fetches everything else.

```bash
git clone git@github.com:GarrettMakesItLLC/dotfiles.git ~/dotfiles
bash ~/dotfiles/bootstrap/device.sh
```

`dotfiles` itself lives at `~/dotfiles`, not inside `~/workspace/` — same reasoning as `dotclaude`
staying at `~/dotclaude`: it bootstraps the machine, so it can't live inside the tree it's the one
creating.

That installs the toolchain, wires the shell and git config, clones `dotclaude` and runs its
`bootstrap.sh` to link `~/.claude`, clones the repo fleet, and installs each repo's dependencies.
Idempotent — re-run it any time; it never overwrites an existing checkout.

`product`-role repos (the daily-work fleet) land flat at `~/workspace/<name>`; `infra` and `archive`
repos group under `~/workspace/Tools/<name>` so the root isn't cluttered with repos nobody opens day
to day. `repos.tsv` is the source of truth for which is which — see its header comment.

It ends by printing what it could not do, because those things are interactive or per-machine:
secrets, MCP connector OAuth, and deployment env vars. Anything needing `sudo` is **reported, never
installed** — a bootstrap script that silently escalates is one nobody can read before running.

```bash
bash bootstrap/device.sh --no-install     # clone and link only; skip dependency installs
bash bootstrap/device.sh --only NetWorthy # one repo
bash bootstrap/device.sh --all            # include archived repos
```

Exit status is non-zero when something blocking is missing, so it can gate a larger script.

### Shell and git config only

```bash
~/dotfiles/install.sh
```

Appends one source line to `~/.bashrc` and an `include.path` to `~/.gitconfig`, so a `git pull` here
updates every machine with no re-install.

## Layout

| Path | What |
| --- | --- |
| `bootstrap/device.sh` | Whole-machine setup. Toolchain, agent config, repo fleet, dependencies. |
| `bootstrap/repos.tsv` | The repo fleet as data. Adding a repo is one line here, never a script edit. |
| `shell/index.sh` | Entry point. Sources everything else — add a file here, not to `~/.bashrc`. |
| `shell/general.sh` | Listing, navigation, `repo`, `mkcd`, safety prompts on `rm`/`mv`/`cp`. |
| `shell/node.sh` | nvm, and npm's global bin on PATH. |
| `shell/git.sh` | Git verbs, `main`/`dev` branch switching, worktree helpers, `gclean`. |
| `git/config` | Included into `~/.gitconfig`. No identity — that stays per machine. |
| `install.sh` | Wires shell and git into the current machine. |

## Why `shell/node.sh` exists

`npm i -g <tool>` installs into `$(npm prefix -g)/bin`, which is not necessarily on `PATH`. When it
isn't, the install succeeds and the command still does not exist — which reads as a broken install
and gets worked around instead of fixed.

That was the state on the WSL box: only `node` and `npm` were symlinked into `~/.local/bin` by hand,
leaving `pnpm`, `corepack`, `shellcheck`, and `vercel` installed but unreachable. `node.sh` derives
the directory from `npm prefix -g` rather than hardcoding it, so a node upgrade does not silently
stop resolving.

## The ones worth knowing

```
main          switch to main and pull        gs      status, short + branch
dev           switch to dev and pull         gl      last 20 commits, graphed
back          switch to the previous branch  gpl     pull
gw <name>     create + enter a worktree      gf      fetch --all --prune
gclean        delete branches whose upstream is gone (prompts first)
repo <name>   cd to a repo, case-insensitive ws      cd to the workspace
```

`main` and `dev` switch **and pull**, because almost every switch to an integration branch is
followed by one, and forgetting it is how you branch off a stale base.

## Machine-specific things

`~/.bashrc.local` is sourced last and never committed. A work proxy, a machine-only path, an export
carrying a secret — those go there, not here.

Git identity stays in `~/.gitconfig`, which git reads after the include, so a per-machine
`user.email` overrides anything set here.

## What does not belong here

Anything secret. This repo is private, but private is not encrypted, and a key committed here is a
key in every clone and every backup. Secrets live in `~/.config/secrets/*.env`.

Agent configuration — that is `dotclaude`. Keeping them separate means a change to how Claude works
does not touch the shell, and a machine can take one without the other.
