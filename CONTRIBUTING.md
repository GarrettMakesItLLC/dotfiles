# Contributing

This is Garrett's personal shell/git/terminal configuration, public for
reference. It's opinionated and tuned to one person's workflow — most changes
here won't be a good fit for a fork's dotfiles, and that's fine.

Maintained solo, in spare time, with no SLA on issues or PRs.

## Reporting a bug

Open an issue — a broken `install.sh`, a script that doesn't run on a
platform it claims to support, etc.

## Pull requests

- Fork and branch from `main`.
- Keep the change scoped and platform-portable (bash/zsh, macOS + Linux
  unless noted otherwise).
- CI (shellcheck) must pass.
- Merges require the maintainer's approval.

Preference changes (aliases, prompt styling, etc.) are unlikely to be
accepted upstream — fork and adapt instead. Bug fixes and portability fixes
are welcome.
