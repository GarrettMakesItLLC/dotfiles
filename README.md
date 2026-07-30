# dotfiles

Shell, git, and terminal config shared across machines.

Sibling to [`dotclaude`](https://github.com/GarrettMakesItLLC/dotclaude), which does the same job for
the agent surface. Same reasoning: the config is the same on every machine, so it lives in one place
and each machine points at it.

## Install

```bash
git clone git@github.com:GarrettMakesItLLC/dotfiles.git ~/workspace/dotfiles
~/workspace/dotfiles/install.sh
```

Idempotent — re-run it after a pull. It appends one source line to `~/.bashrc` and adds an
`include.path` to `~/.gitconfig`, so a `git pull` here updates every machine with no re-install.

## Layout

| Path | What |
| --- | --- |
| `shell/index.sh` | Entry point. Sources everything else — add a file here, not to `~/.bashrc`. |
| `shell/general.sh` | Listing, navigation, `repo`, `mkcd`, safety prompts on `rm`/`mv`/`cp`. |
| `shell/git.sh` | Git verbs, `main`/`dev` branch switching, worktree helpers, `gclean`. |
| `git/config` | Included into `~/.gitconfig`. No identity — that stays per machine. |
| `install.sh` | Wires both into the current machine. |

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
