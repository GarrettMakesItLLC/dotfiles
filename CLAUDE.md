# CLAUDE.md

**Autonomy: gated.** Carry work to a PR ready to merge, then stop.

Shell, git, and machine-bootstrap config, shared across machines. Sibling to `dotclaude`, which does
the same for the agent surface — a change to how Claude works does not belong here, and a shell alias
does not belong there.

## The thing that makes this repo dangerous

**Every file here is sourced into every interactive shell on every machine.** A syntax error in
`shell/*.sh` breaks the shell itself, and the breakage arrives on the next `git pull` with no PR in
between to catch it. Two consequences:

- `shellcheck` is the gate, and it must pass before merge. CI runs it.
- Sourcing must succeed when optional pieces are absent. A trailing `[ -f x ] && . x` returns 1 when
  `x` is missing, which breaks `. index.sh && …` and any caller under `set -e` — `index.sh` ends with
  `:` for exactly that reason.

## Layout

```text
bootstrap/device.sh   whole-machine setup; idempotent; reports anything needing sudo
bootstrap/repos.tsv   the repo fleet, as data
shell/index.sh        entry point — sources the rest, in order
shell/{general,node,git,secrets}.sh
git/config            included into ~/.gitconfig via include.path
install.sh            wires shell + git into the current machine
```

Adding a shell file means adding its name to `index.sh`'s loop, not editing `~/.bashrc`. Adding a
repo to the fleet means one line in `repos.tsv`, never a change to `device.sh`.

## Commands

```bash
shellcheck -S warning bootstrap/device.sh install.sh shell/*.sh   # the gate
bash bootstrap/device.sh --no-install --only <repo>               # safe smoke test
bash -n <file>                                                    # syntax only
```

`shellcheck` lives in npm's global bin, which `shell/node.sh` puts on PATH — so it resolves only in a
shell that has sourced this repo. In a bare shell it appears not to be installed.

The sourced `shell/*.sh` files carry `# shellcheck shell=bash` because they have no shebang by
design; without it shellcheck cannot pick a dialect and reports SC2148 on every one.

## Invariants

- **No secrets, ever.** Private is not encrypted, and a key committed here is in every clone and
  every backup. Secrets live in `~/.config/secrets/*.env`; machine-local shell state goes in
  `~/.bashrc.local`, which is sourced last and never committed.
- **No git identity in `git/config`.** It is included *before* `~/.gitconfig`'s own values, so
  identity stays per machine and overrides cleanly.
- **`device.sh` never runs `sudo`.** It reports what needs elevation and exits non-zero. Anything
  that installs into `$HOME` (nvm, node, global npm packages) is fair game.
- **Paths are derived, not hardcoded.** `npm prefix -g` rather than a versioned nvm path, or the
  config silently stops resolving on the next node upgrade.
