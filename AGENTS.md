# Style

- Two spaces for indentation, no tabs.
- Use Bash 5 conditionals: `[[ ]]` for string/file tests, `(( ))` for numeric
  tests. In `[[ ]]`, don't quote variables, but do quote string literals when
  comparing values (e.g., `[[ $OS_ID == "debian" ]]`).
- Shebangs use `#!/usr/bin/env bash` consistently. Every script starts with
  `set -Eeuo pipefail` (except `configs/`, which are user-facing config files,
  not scripts).
- Scripts under `scripts/` are sourced by `install.sh` and must not call
  `exit` except when intentionally aborting the whole installer.
- No comments unless they explain a non-obvious decision (e.g., why a string
  literal must not be expanded).
- Services, databases, and the Windows VM bind to `127.0.0.1` only. Never
  expose them to the network.

# Layout

- `install.sh` — the entry point. Parses flags, detects first install vs
  update (`DEVBOX_UPDATE=1` when `~/.local/state/devbox/installed` or
  `~/.config/shell/devbox-server` exists), then runs components through
  `run_component NAME function`. Sourced component scripts define the
  `install_*` functions.
- `scripts/lib.sh` — shared helpers: `log`, `warn`, `run` (DRY_RUN-aware),
  `backup_path` (timestamped backups), `install_apt_packages`,
  `require_non_root`, `detect_supported_os` (Ubuntu 24.04+, Debian 12+,
  amd64/arm64).
- `scripts/install-*.sh` — one component each: base, docker, tailscale,
  terminal, ai, 1password, configs, services, adguard. `install-configs.sh`
  also defines `refresh_configs` (update path) and `install_devbox_editor_configs`.
- `scripts/devbox-setup` — interactive onboarding for Git, GitHub, Tailscale,
  SSH, and 1Password. Reads `DEVBOX_SETUP_*` env vars for unattended runs and
  seeds everything from one 1Password item with `--op ITEM`. See
  `docs/1password.md`.
- `scripts/devbox-db` and `scripts/devbox-windows-vm` — standalone helpers for
  the CLI. `devbox-windows-vm` reads `DEVBOX_VM_*` env vars for unattended
  installs (RAM/CORES/DISK/USER/PASS/VERSION).
- `bin/devbox` + `bin/devbox-sub/` — the CLI. `bin/devbox` exports
  `DEVBOX_PATH` and dispatches to `bin/devbox-sub/<sub>.sh`, which call the
  scripts above. `menu.sh` maps menu labels to subs; add new subs to its
  `case` and to `help.sh` and the README.
- `configs/` — shipped configs: `shell/`, `nvim/plugins/`, `lazygit/`,
  `starship.toml`, `tmux.conf`. Installed to `~/.config/...`.
- `migrations/<timestamp>-<name>.sh` — one-time changes run only on update
  (`DEVBOX_UPDATE=1`), executed with `bash`, tracked by a marker file per
  migration at `~/.local/state/devbox/migrations/<name>`.
- `docs/` — human docs (e.g., `1password.md`).
- `tests/test.sh` — the test suite (see Testing).

# Update semantics

Updates must never destroy user state. The rules:

- Onboarding (Git identity, GitHub auth in `~/.config/gh`, 1Password in
  `~/.config/op`, Tailscale enrollment, SSH keys) is first-install work and is
  never replayed on update.
- `refresh_configs` replaces only `~/.config/tmux/tmux.conf` and
  `~/.config/starship.toml` from fresh Omadots, always with a timestamped
  backup and a diff of the changes. Everything else stays user-owned.
- `install_omadots` (the `--only configs` force-replace path) preserves Git
  identity and a persisted `OP_SERVICE_ACCOUNT_TOKEN` in
  `~/.config/shell/envs`; carry those over when touching that code.
- Auth state and secrets live outside omadots-managed files
  (`~/.config/gh/hosts.yml`, `~/.config/op/`, `/var/lib/tailscale`,
  `~/.ssh/`). Keep it that way.
- New packages or file changes that must reach existing installs go in a
  migration, not by re-running the first-install path.

# Testing

- Run `bash tests/test.sh` after any change; it fails on regressions and
  requires assertions for new features (grep-based checks on the exact
  strings/behavior the feature guarantees).
- shellcheck is not installed locally; run it via:
  `docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable /mnt/<file>`
  Pre-existing SC1090/SC1091 findings in `configs/shell/devbox-server` are
  acceptable; new scripts must be clean.
- New sub-commands and scripts must also be exercised live (dry-run, then a
  sandboxed `HOME` where side effects land) before finishing.

# Git

- Atomic commits: one coherent change, no unrelated work. Follow the repo
  style: `feat:`, `fix:`, `chore:` prefixes with a lowercase subject.
- The remote requires a GitHub token; git works through the `gh` credential
  helper (`gh auth setup-git`), plain password auth is rejected.
