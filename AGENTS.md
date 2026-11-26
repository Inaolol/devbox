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

# Layout

- `install.sh` — the entry point. Parses flags, detects first install vs
  update (`DEVBOX_UPDATE=1` when `~/.local/state/devbox/installed` exists),
  prepares APT repositories once for full installs, and runs active components
  with numbered `step_header` progress. Sourced component scripts define the
  `install_*` (and `setup_*_apt_repo*`) functions.
- `scripts/lib.sh` — shared helpers: `log`, `warn`, `step_header`,
  `run_step`, `run` (DRY_RUN-aware), `backup_path` (timestamped backups),
  `ensure_apt_updated`, `ensure_apt_keyring`, `ensure_apt_source`,
  `install_apt_packages`, `find_mise`, `register_temp_dir`,
  `cleanup_temp_dirs`, `require_non_root`, `require_sudo` (fail-fast sudo
  preflight; SSH keys do not grant sudo), `detect_supported_os` (Ubuntu
  24.04+, Debian 12+, amd64/arm64).
- `scripts/install-*.sh` — one component each: `base`, `docker`, `tailscale`,
  `terminal`, `ai`, `configs`, `services`. `install-configs.sh` also defines
  `refresh_configs` (update path) and `install_devbox_editor_configs`.
- `scripts/devbox-setup` — interactive onboarding for Git, GitHub, Tailscale,
  and SSH. `install-services.sh` reads `DEVBOX_SETUP_*` env vars for
  unattended runs.
- `bin/devbox` + `bin/devbox-sub/` — the CLI. `bin/devbox` exports
  `DEVBOX_PATH` and dispatches to `bin/devbox-sub/menu.sh`, which routes to
  `bin/devbox-sub/<sub>.sh` (`setup`, `install`, `remove`, `update`, `help`).
  Add new subs to `menu.sh`'s `case`, `help.sh`, and `README.md`.
- `configs/` — shipped configs: `shell/`, `herdr/config.toml`, `starship.toml`,
  `nvim/plugins/`, `lazygit/`. Installed to `~/.config/...`.
- `migrations/<timestamp>-<name>.sh` — one-time changes run only on update
  (`DEVBOX_UPDATE=1`), executed with `bash`, tracked by a marker file per
  migration at `~/.local/state/devbox/migrations/<name>`.
- `tests/test.sh` — the test suite (see Testing).

# Update semantics

Updates must never destroy user state. The rules:

- Onboarding (Git identity, GitHub auth in `~/.config/gh`, Tailscale
  enrollment, SSH keys) is first-install work and is
  never replayed on update.
- `refresh_configs` replaces only `~/.config/tmux/tmux.conf` (from pinned
  Omadots), `~/.config/starship.toml`, and `~/.config/herdr/config.toml` (from
  shipped `configs/`), always with a timestamped backup and a diff of the
  changes. Everything else stays user-owned.
- `install_configs` (the `--only configs` force-replace path) preserves Git
  identity and `~/.config/mise/config.toml` `[tools]`.
- Auth state and secrets live outside omadots-managed files
  (`~/.config/gh/hosts.yml`, `/var/lib/tailscale`,
  `~/.ssh/`). Keep it that way.
- New packages or file changes that must reach existing installs go in a
  migration, not by re-running the first-install path.

# Testing

- Run `bash tests/test.sh` after any change; it fails on regressions and
  requires assertions for new features (grep-based and behavioral checks on the
  exact behavior the feature guarantees).
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
