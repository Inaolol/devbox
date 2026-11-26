#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  bash -n "$file"
done
bash -n "$ROOT/scripts/devbox-setup" "$ROOT/configs/shell/devbox-server" "$ROOT/bin/devbox"

if command -v shellcheck >/dev/null 2>&1; then
  find "$ROOT" -type f -name '*.sh' ! -path "$ROOT/tests/*" -print0 | xargs -0 shellcheck
  # This file deliberately greps for literal strings containing '$' and
  # defines stub functions consumed indirectly, so its info-level findings
  # are expected; hold it to warnings and errors only.
  shellcheck --severity=warning "$ROOT/tests/test.sh"
  shellcheck "$ROOT/scripts/devbox-setup"
  shellcheck -s bash "$ROOT/configs/shell/devbox-server"
else
  echo "shellcheck not installed; syntax checks completed"
fi

# Deleted features and dead files must stay absent.
for dead in \
  scripts/devbox-windows-vm \
  bin/devbox-sub/windows-vm.sh \
  scripts/devbox-db \
  bin/devbox-sub/databases.sh \
  scripts/install-adguard.sh \
  configs/tmux.conf \
  docs/compatibility-audit-2026-07-31.md; do
  if [[ -e $ROOT/$dead ]]; then
    echo "Deleted file still exists: $dead" >&2
    exit 1
  fi
done

# Zero curl | sh remote script execution anywhere in scripts/.
if grep -rnE 'curl[^|]*\|[[:space:]]*(ba)?sh' "$ROOT/scripts"; then
  echo "Scripts must not pipe curl directly into sh/bash" >&2
  exit 1
fi

grep -q 'set -Eeuo pipefail' "$ROOT/install.sh"
grep -q 'detect_supported_os' "$ROOT/install.sh"
grep -q 'require_sudo' "$ROOT/install.sh"
grep -q 'require_sudo' "$ROOT/scripts/lib.sh"
grep -q 'install_services' "$ROOT/install.sh"
if grep -qi '1password' "$ROOT/install.sh"; then
  echo "1Password must not be installed or managed by DevBox" >&2
  exit 1
fi
grep -q 'refresh_configs' "$ROOT/install.sh"
grep -q '.local/state/devbox' "$ROOT/install.sh"
grep -q 'run_migrations' "$ROOT/install.sh"
grep -q '.local/state/devbox/migrations' "$ROOT/scripts/migrations.sh"

# An update with no migrations must not abort the installer under set -e.
(
  set -e
  REPO_ROOT="$(mktemp -d)"
  HOME="$(mktemp -d)"
  log() { :; }
  run() { "$@"; }
  source "$ROOT/scripts/migrations.sh"
  run_migrations
  rm -rf "$REPO_ROOT" "$HOME"
)

# Structured progress: run()/run_step() captures output into a 0600 install log,
# shows a concise result line, and surfaces the failing output tail on errors.
grep -q 'DEVBOX_INSTALL_LOG_FILE' "$ROOT/scripts/lib.sh"
grep -q 'install_start_log' "$ROOT/scripts/lib.sh"
grep -q 'install_end_log' "$ROOT/scripts/lib.sh"
grep -q 'install_fail_log' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install started' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install completed' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install FAILED' "$ROOT/scripts/lib.sh"
grep -q 'Last output' "$ROOT/scripts/lib.sh"
grep -q 'if "\$@" >>"\$log_file" 2>&1; then' "$ROOT/scripts/lib.sh"
grep -q 'install_start_log' "$ROOT/install.sh"
grep -q 'DEVBOX_INSTALL_LOG_FILE' "$ROOT/install.sh"
grep -q 'run bash "\$migration"' "$ROOT/scripts/migrations.sh"

(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  export DEVBOX_INSTALL_LOG_FILE="$work/install.log"
  export DRY_RUN=0
  source "$ROOT/scripts/lib.sh"
  install_start_log
  [[ "$(stat -c %a "$work/install.log")" == "600" ]]
  run printf '%s' 'hidden output' >/dev/null 2>&1
  grep -q '^hidden output$' "$work/install.log"
  set +e
  run sh -c 'echo oops; exit 3' >/dev/null 2>&1
  status=$?
  set -e
  (( status == 3 ))
  install_end_log
  grep -q '=== Devbox install started:' "$work/install.log"
  grep -q '=== Devbox install completed:' "$work/install.log"
)

# Sudo must authenticate before the command is hidden behind progress output.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  # shellcheck disable=SC2030,SC2031
  export DEVBOX_INSTALL_LOG_FILE="$work/install.log"
  # shellcheck disable=SC2030,SC2031
  export DRY_RUN=0
  authenticated=0
  sudo() {
    if [[ $1 == "-v" ]]; then
      authenticated=1
      return 0
    fi
    (( authenticated == 1 )) || return 42
    "$@"
  }
  source "$ROOT/scripts/lib.sh"
  run sudo true >/dev/null 2>&1
)

# require_sudo passes silently with passwordless sudo and prompts once
# otherwise; an account with no usable sudo must fail fast.
(
  sudo() { [[ $1 == "-n" ]]; }
  export DRY_RUN=0
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib.sh"
  require_sudo
)
(
  calls="$(mktemp)"
  trap 'rm -f "$calls"' EXIT
  sudo() {
    printf '%s\n' "$1" >>"$calls"
    [[ $1 == "-n" ]] && return 1
    return 0
  }
  export DRY_RUN=0
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib.sh"
  require_sudo 2>/dev/null
  grep -qx -- "-v" "$calls"
)
(
  sudo() { return 1; }
  export DRY_RUN=0
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib.sh"
  if require_sudo 2>/dev/null; then
    echo "require_sudo must fail when sudo authentication fails" >&2
    exit 1
  fi
)

# ensure_apt_updated runs apt-get update once until APT_REPOS_DIRTY=1.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  export DRY_RUN=0
  export DEVBOX_INSTALL_LOG_FILE=""
  updates="$work/updates"
  sudo() {
    if [[ $1 == "apt-get" && $2 == "update" ]]; then
      echo "update" >>"$updates"
    fi
  }
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib.sh"
  ensure_apt_updated
  ensure_apt_updated
  (( $(wc -l <"$updates") == 1 ))
  # shellcheck disable=SC2034
  APT_REPOS_DIRTY=1
  ensure_apt_updated
  ensure_apt_updated
  (( $(wc -l <"$updates") == 2 ))
)

# Docker installer uses signed APT repo, log rotation, removes conflicts, and warns on DOCKER-USER.
grep -q 'docker-ce' "$ROOT/scripts/install-docker.sh"
grep -q 'podman-docker' "$ROOT/scripts/install-docker.sh"
grep -q 'DOCKER-USER' "$ROOT/scripts/install-docker.sh"
grep -q '/etc/docker/daemon.json' "$ROOT/scripts/install-docker.sh"
grep -q '"max-size": "10m"' "$ROOT/scripts/install-docker.sh"
grep -q '"max-file": "5"' "$ROOT/scripts/install-docker.sh"
# shellcheck disable=SC2016
grep -q 'download.docker.com/linux/${OS_ID}' "$ROOT/scripts/install-docker.sh"

# Base ergonomics: SSH keepalives and PAM non-interactive PATH.
grep -q '20-devbox-keepalive.conf' "$ROOT/scripts/install-base.sh"
grep -q 'ServerAliveInterval 15' "$ROOT/scripts/install-base.sh"
grep -q 'pam_env.conf' "$ROOT/scripts/install-base.sh"
grep -q 'mise/shims' "$ROOT/scripts/install-base.sh"

# Tailscale uses its signed APT repo, not tailscale.com/install.sh.
grep -q 'pkgs.tailscale.com/stable' "$ROOT/scripts/install-tailscale.sh"
if grep -q 'tailscale.com/install.sh' "$ROOT/scripts/install-tailscale.sh"; then
  echo "Tailscale must use the signed APT repository, not tailscale.com/install.sh" >&2
  exit 1
fi

# Terminal tools: signed APT repos (gh, gum, mise), checksum-verified mise tools
# (including herdr & delta), btop/ncdu, and checksum-verified JetBrainsMono Nerd Font,
# without bloated compiler/manual packages.
grep -q 'mise.jdx.dev/deb' "$ROOT/scripts/install-terminal.sh"
grep -q 'repo.charm.sh/apt' "$ROOT/scripts/install-terminal.sh"
grep -q 'cli.github.com/packages' "$ROOT/scripts/install-terminal.sh"
grep -q 'bash-completion bat btop ncdu' "$ROOT/scripts/install-terminal.sh"
grep -q 'command -v batcat' "$ROOT/scripts/install-terminal.sh"
grep -q 'kitty-terminfo' "$ROOT/scripts/install-terminal.sh"
grep -q 'neovim herdr starship zoxide eza delta lazygit lazydocker' "$ROOT/scripts/install-terminal.sh"
grep -q 'install_nerd_font' "$ROOT/scripts/install-terminal.sh"
grep -q 'NERD_FONT_VERSION=' "$ROOT/scripts/install-terminal.sh"
grep -q 'verify_sha256' "$ROOT/scripts/install-terminal.sh"
grep -q 'sha256sum' "$ROOT/scripts/lib.sh"
for bloated in clang llvm libyaml-dev luarocks whois man-db; do
  if grep -qw "$bloated" "$ROOT/scripts/install-terminal.sh"; then
    echo "Bloated package must not be in install-terminal.sh: $bloated" >&2
    exit 1
  fi
done

# AI tools and user-owned skill roots.
grep -q 'aqua:modem-dev/hunk' "$ROOT/scripts/install-ai.sh"
grep -q 'antigravity-cli' "$ROOT/scripts/install-ai.sh"
if grep -qE '(^|[[:space:]])gemini([[:space:]]|$)' "$ROOT/scripts/install-ai.sh"; then
  echo "Deprecated Gemini CLI should not be installed; Antigravity CLI replaces it" >&2
  exit 1
fi
if grep -q 'github:basecamp/basecamp-cli' "$ROOT/scripts/install-ai.sh"; then
  echo "Product-specific Basecamp CLI should not be installed" >&2
  exit 1
fi
grep -q 'No API keys are stored' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.agents/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.claude/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.codex/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.gemini/antigravity-cli/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.pi/agent/skills"' "$ROOT/scripts/install-ai.sh"

# Configs: pinned SHAs, single-fetch, raw refresh, and user-state preservation.
grep -q 'omacom-io/omadots' "$ROOT/scripts/install-configs.sh"
grep -qE 'OMADOTS_REF="[0-9a-f]{40}"' "$ROOT/scripts/install-configs.sh"
grep -qE 'LAZYVIM_STARTER_REF="[0-9a-f]{40}"' "$ROOT/scripts/install-configs.sh"
grep -q 'clone_pinned https://github.com/omacom-io/omadots.git "\$OMADOTS_REF"' "$ROOT/scripts/install-configs.sh"
grep -q 'clone_pinned https://github.com/LazyVim/starter.git "\$LAZYVIM_STARTER_REF"' "$ROOT/scripts/install-configs.sh"
grep -q 'rev-parse HEAD' "$ROOT/scripts/install-configs.sh"
grep -q 'raw.githubusercontent.com/omacom-io/omadots/\${OMADOTS_REF}/config' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'backup_path "$HOME/.bashrc"' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'git config --file "$HOME/.gitconfig" user.name' "$ROOT/scripts/install-configs.sh"
grep -q 'core.pager delta' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'HERDR_ENV' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'DEVBOX_NO_HERDR' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'DEVBOX_NO_TMUX' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q '$HOME/.config/devbox/startup' "$ROOT/scripts/install-configs.sh"
grep -q 'tmux new-session -s Work' "$ROOT/scripts/install-configs.sh"
grep -q 'configs/herdr/config.toml' "$ROOT/scripts/install-configs.sh"
grep -q 'configs/starship.toml' "$ROOT/scripts/install-configs.sh"
grep -q 'configs/nvim/plugins' "$ROOT/scripts/install-configs.sh"
grep -q 'configs/lazygit/config.yml' "$ROOT/scripts/install-configs.sh"
grep -q 'refresh_configs' "$ROOT/scripts/install-configs.sh"
grep -q 'refresh_managed_file' "$ROOT/scripts/install-configs.sh"
grep -q 'diff -u' "$ROOT/scripts/install-configs.sh"
grep -q 'mise_tools' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -qF '\[tools\]' "$ROOT/scripts/install-configs.sh"
if grep -q 'OP_SERVICE_ACCOUNT_TOKEN' "$ROOT/scripts/install-configs.sh"; then
  echo "Legacy 1Password token handling must be removed" >&2
  exit 1
fi
test -f "$ROOT/configs/herdr/config.toml"
grep -q 'prefix = "ctrl+space"' "$ROOT/configs/herdr/config.toml"
grep -q 'onboarding = false' "$ROOT/configs/herdr/config.toml"
grep -q 'accent = "blue"' "$ROOT/configs/herdr/config.toml"
grep -q 'pane_gaps = false' "$ROOT/configs/herdr/config.toml"
test -f "$ROOT/configs/starship.toml"
grep -q 'ssh_only = true' "$ROOT/configs/starship.toml"
grep -q 'truncation_length = 2' "$ROOT/configs/starship.toml"
test -f "$ROOT/configs/nvim/plugins/colorscheme.lua"
test -f "$ROOT/configs/nvim/plugins/disable-news-alert.lua"
test -f "$ROOT/configs/nvim/plugins/snacks-animated-scrolling.lua"
test -f "$ROOT/configs/lazygit/config.yml"
grep -q '#7aa2f7' "$ROOT/configs/lazygit/config.yml"
grep -q 'showGraph' "$ROOT/configs/lazygit/config.yml"

# refresh_configs refreshes tmux.conf, starship.toml, and herdr/config.toml with timestamped backups.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  HOME="$work/home"
  # shellcheck disable=SC2034
  REPO_ROOT="$ROOT"
  mkdir -p "$HOME/.config/tmux" "$HOME/.config/herdr"
  printf 'old tmux\n' >"$HOME/.config/tmux/tmux.conf"
  printf 'old starship\n' >"$HOME/.config/starship.toml"
  printf 'old herdr\n' >"$HOME/.config/herdr/config.toml"
  export DRY_RUN=0
  export DEVBOX_INSTALL_LOG_FILE=""
  source "$ROOT/scripts/lib.sh"
  source "$ROOT/scripts/install-configs.sh"
  curl() {
    local url="" out=""
    while (( $# )); do
      case "$1" in
        -o) out="$2"; shift 2 ;;
        http*) url="$1"; shift ;;
        *) shift ;;
      esac
    done
    [[ $url == *"/$OMADOTS_REF/config/tmux/tmux.conf" ]] || return 1
    printf 'new tmux.conf\n' >"$out"
  }
  refresh_configs >/dev/null
  grep -q 'new tmux.conf' "$HOME/.config/tmux/tmux.conf"
  grep -q 'ssh_only = true' "$HOME/.config/starship.toml"
  grep -q 'prefix = "ctrl+space"' "$HOME/.config/herdr/config.toml"
  compgen -G "$HOME/.config/tmux/tmux.conf.backup.*" >/dev/null
  compgen -G "$HOME/.config/starship.toml.backup.*" >/dev/null
  compgen -G "$HOME/.config/herdr/config.toml.backup.*" >/dev/null
)

# DevBox server shell additions and migrations.
grep -q "alias lzd='lazydocker'" "$ROOT/configs/shell/devbox-server"
grep -q "alias h='herdr'" "$ROOT/configs/shell/devbox-server"
grep -q "alias cls='clear'" "$ROOT/configs/shell/devbox-server"
# shellcheck disable=SC2016
grep -q 'export LANG="${LANG:-C.UTF-8}"' "$ROOT/configs/shell/devbox-server"
grep -q 'C.UTF-8' "$ROOT/migrations/20260731-set-utf8-locale.sh"
grep -q 'lazygit' "$ROOT/migrations/20260805-install-editor-configs.sh"
grep -q 'colorscheme.lua' "$ROOT/migrations/20260805-install-editor-configs.sh"
grep -q 'DEVBOX_NO_TMUX' "$ROOT/migrations/20260917-auto-attach-tmux.sh"
grep -q 'tmux new-session -s Work' "$ROOT/migrations/20260917-auto-attach-tmux.sh"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  HOME="$work"
  touch "$HOME/.bashrc"
  bash "$ROOT/migrations/20260917-auto-attach-tmux.sh"
  grep -q 'DEVBOX_NO_TMUX' "$HOME/.bashrc"
  grep -q 'tmux new-session -s Work' "$HOME/.bashrc"
  bash "$ROOT/migrations/20260917-auto-attach-tmux.sh"
  (( $(grep -c 'tmux new-session -s Work' "$HOME/.bashrc") == 1 ))
)
# Herdr migration upgrades old tmux auto-attach block idempotently, preserves tmux
# in startup when upgrading old auto-attach, leaves startup off otherwise, and
# never overwrites user herdr config.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  HOME="$work/old"
  mkdir -p "$HOME/.config/shell"
  touch "$HOME/.bashrc" "$HOME/.config/shell/devbox-server"
  bash "$ROOT/migrations/20260917-auto-attach-tmux.sh"
  REPO_ROOT="$ROOT" bash "$ROOT/migrations/20261127-herdr-and-omarchy-defaults.sh"
  grep -q 'HERDR_ENV' "$HOME/.bashrc"
  grep -q 'startup' "$HOME/.bashrc"
  [[ $(cat "$HOME/.config/devbox/startup") == "tmux" ]]
  grep -q "alias h='herdr'" "$HOME/.config/shell/devbox-server"
  grep -q 'prefix = "ctrl+space"' "$HOME/.config/herdr/config.toml"
  printf '# user customized\n' >"$HOME/.config/herdr/config.toml"
  REPO_ROOT="$ROOT" bash "$ROOT/migrations/20261127-herdr-and-omarchy-defaults.sh"
  (( $(grep -c 'HERDR_ENV' "$HOME/.bashrc") == 1 ))
  (( $(grep -c "alias h='herdr'" "$HOME/.config/shell/devbox-server") == 1 ))
  grep -qx '# user customized' "$HOME/.config/herdr/config.toml"

  HOME="$work/plain"
  mkdir -p "$HOME"
  printf '# plain\n' >"$HOME/.bashrc"
  REPO_ROOT="$ROOT" bash "$ROOT/migrations/20261127-herdr-and-omarchy-defaults.sh"
  grep -q 'HERDR_ENV' "$HOME/.bashrc"
  [[ ! -e $HOME/.config/devbox/startup ]]
)

# Services: no redundant gh install, passes --auth-key-stdin, safe DEVBOX_PATH quoting.
if grep -q 'install_apt_packages gh' "$ROOT/scripts/install-services.sh"; then
  echo "install-services.sh must not redundantly install gh" >&2
  exit 1
fi
grep -q -- '--auth-key-stdin' "$ROOT/scripts/install-services.sh"
if grep -q -- '--auth-key "' "$ROOT/scripts/install-services.sh"; then
  echo "install-services.sh must pass Tailscale auth key via stdin, not argv" >&2
  exit 1
fi
grep -q 'DEVBOX_SETUP_GH_TOKEN DEVBOX_SETUP_TS_AUTH_KEY' "$ROOT/scripts/install-services.sh"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  HOME="$work/home"
  REPO_ROOT="$work/dir with spaces"
  mkdir -p "$REPO_ROOT/bin" "$REPO_ROOT/scripts"
  cp "$ROOT/scripts/devbox-setup" "$REPO_ROOT/scripts/devbox-setup"
  cat >"$REPO_ROOT/bin/devbox" <<'WRAP'
#!/usr/bin/env bash
printf 'ok:%s\n' "$1"
WRAP
  chmod +x "$REPO_ROOT/bin/devbox"
  export DRY_RUN=0 DEVBOX_UPDATE=1 DEVBOX_INSTALL_LOG_FILE=""
  source "$ROOT/scripts/lib.sh"
  source "$ROOT/scripts/install-services.sh"
  install_services >/dev/null
  [[ "$("$HOME/.local/bin/devbox" ping)" == "ok:ping" ]]
)

# devbox-setup: auth key env safety, multi-line SSH key rejection, missing flag arg guard.
grep -q 'Git identity is already configured' "$ROOT/scripts/devbox-setup"
grep -q 'GitHub is already authenticated' "$ROOT/scripts/devbox-setup"
grep -q 'gh auth login --hostname github.com --git-protocol https --web </dev/null' "$ROOT/scripts/devbox-setup"
grep -q 'Tailscale is already connected' "$ROOT/scripts/devbox-setup"
grep -q 'An SSH public key is already installed' "$ROOT/scripts/devbox-setup"
grep -q 'disable-password-auth' "$ROOT/scripts/devbox-setup"
grep -q 'sshd -t' "$ROOT/scripts/devbox-setup"
grep -q 'not Tailscale SSH' "$ROOT/scripts/devbox-setup"
grep -q 'TS_AUTHKEY' "$ROOT/scripts/devbox-setup"
if grep -qF -- '--auth-key=$auth_key' "$ROOT/scripts/devbox-setup"; then
  echo "Tailscale auth key must not be passed as a command argument" >&2
  exit 1
fi
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/bin"
  cat >"$work/bin/sudo" <<'STUB'
#!/usr/bin/env bash
if [[ $1 == "env" ]]; then
  shift
  env "$@"
else
  "$@"
fi
STUB
  cat >"$work/bin/tailscale" <<'STUB'
#!/usr/bin/env bash
printf '%s|%s\n' "${TS_AUTHKEY:-}" "$*" >"$DEVBOX_TS_CALL"
STUB
  chmod +x "$work/bin/sudo" "$work/bin/tailscale"
  export DEVBOX_TS_CALL="$work/ts.call"
  if PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" git --name 2>/dev/null; then
    echo "devbox-setup must reject missing flag argument" >&2
    exit 1
  fi
  if PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" ssh --key $'ssh-ed25519 AAAA\nextra' 2>/dev/null; then
    echo "devbox-setup must reject multi-line SSH keys" >&2
    exit 1
  fi
  printf 'tskey-secret\n' | PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" tailscale --hostname srv1 --auth-key-stdin >/dev/null
  grep -q '^tskey-secret|up --ssh --accept-routes --hostname=srv1$' "$work/ts.call"
)

# devbox-setup startup: defaults to off and toggles between herdr, tmux, and off.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  HOME="$work/home"
  mkdir -p "$work/bin" "$HOME"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$work/bin/herdr"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$work/bin/tmux"
  chmod +x "$work/bin/herdr" "$work/bin/tmux"
  [[ "$(HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup status)" == "Startup auto-attach: off" ]]
  [[ ! -e $HOME/.config/devbox/startup ]]
  HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup herdr >/dev/null
  [[ $(cat "$HOME/.config/devbox/startup") == "herdr" ]]
  [[ "$(HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup status)" == "Startup auto-attach: herdr" ]]
  HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup tmux >/dev/null
  [[ $(cat "$HOME/.config/devbox/startup") == "tmux" ]]
  [[ "$(HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup status)" == "Startup auto-attach: tmux" ]]
  HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup off >/dev/null
  [[ ! -e $HOME/.config/devbox/startup ]]
  [[ "$(HOME="$HOME" PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-setup" startup status)" == "Startup auto-attach: off" ]]
  if HOME="$HOME" bash "$ROOT/scripts/devbox-setup" startup screen >/dev/null 2>&1; then
    echo "devbox-setup startup must reject invalid modes" >&2
    exit 1
  fi
)

# Bootstrap safety: refuses root and unsafe DEVBOX_DIR values ($HOME, /, non-checkout).
grep -q 'EUID' "$ROOT/bootstrap.sh"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/target"
  touch "$work/target/keepme"
  if DEVBOX_DIR="$work/target" bash "$ROOT/bootstrap.sh" >/dev/null 2>&1; then
    echo "bootstrap must refuse a non-empty non-checkout DEVBOX_DIR" >&2
    exit 1
  fi
  [[ -e $work/target/keepme ]]
  if HOME="$work/home" DEVBOX_DIR="$work/home" bash "$ROOT/bootstrap.sh" >/dev/null 2>&1; then
    echo "bootstrap must refuse DEVBOX_DIR=\$HOME" >&2
    exit 1
  fi
)

# devbox CLI menu, subs, and setup arg forwarding.
grep -q 'DEVBOX_PATH' "$ROOT/bin/devbox"
grep -q 'devbox-sub' "$ROOT/bin/devbox"
grep -q 'gum choose' "$ROOT/bin/devbox-sub/menu.sh"
grep -q -- '--only tailscale' "$ROOT/bin/devbox-sub/install.sh"
grep -q 'tailscaled' "$ROOT/bin/devbox-sub/remove.sh"
grep -q 'bootstrap.sh' "$ROOT/bin/devbox-sub/update.sh"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/bin"
  ln -s "$ROOT/scripts/devbox-setup" "$work/bin/devbox-setup"
  PATH="$work/bin:$PATH" "$ROOT/bin/devbox" setup --help | grep -q -- '--auth-key-stdin'
  HOME="$work/home" PATH="$work/bin:$PATH" "$ROOT/bin/devbox" setup startup status | grep -q 'Startup auto-attach: off'
)

# install.sh flag validation & update detection.
if grep -q 'devbox-server".*DEVBOX_UPDATE\|DEVBOX_UPDATE.*devbox-server' "$ROOT/install.sh"; then
  echo "Update detection must rely on the installed marker only" >&2
  exit 1
fi
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  if HOME="$work" bash "$ROOT/install.sh" --only servieces >/dev/null 2>&1; then
    echo "--only must reject unknown components" >&2
    exit 1
  fi
  set +e
  HOME="$work" bash "$ROOT/install.sh" --only >/dev/null 2>&1
  rc=$?
  set -e
  (( rc == 2 ))
  [[ ! -e $work/.local/state/devbox/installed ]]
)

# OS detection tests (independent of host).
# shellcheck disable=SC1091
source "$ROOT/scripts/lib.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
OS_ARCHITECTURE=amd64

cat >"$tmp/ubuntu" <<'OS'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
PRETTY_NAME="Ubuntu 24.04 LTS"
OS
OS_RELEASE_FILE="$tmp/ubuntu" detect_supported_os
[[ $OS_ID == "ubuntu" && $OS_CODENAME == "noble" ]]

cat >"$tmp/debian12" <<'OS'
ID=debian
VERSION_ID="12"
VERSION_CODENAME=bookworm
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
OS
OS_RELEASE_FILE="$tmp/debian12" detect_supported_os
[[ $OS_ID == "debian" && $OS_CODENAME == "bookworm" ]]

cat >"$tmp/debian13" <<'OS'
ID=debian
VERSION_ID="13"
VERSION_CODENAME=trixie
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
OS
OS_RELEASE_FILE="$tmp/debian13" detect_supported_os
[[ $OS_ID == "debian" && $OS_CODENAME == "trixie" ]]

OS_ARCHITECTURE=i386
if OS_RELEASE_FILE="$tmp/debian13" detect_supported_os 2>/dev/null; then
  echo "Unsupported architecture test failed" >&2
  exit 1
fi
# shellcheck disable=SC2034
OS_ARCHITECTURE=amd64

cat >"$tmp/old-debian" <<'OS'
ID=debian
VERSION_ID="11"
VERSION_CODENAME=bullseye
PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
OS
if OS_RELEASE_FILE="$tmp/old-debian" detect_supported_os 2>/dev/null; then
  echo "Old Debian version test failed" >&2
  exit 1
fi

cat >"$tmp/unsupported" <<'OS'
ID=opensuse-leap
VERSION_ID="15.6"
VERSION_CODENAME=leap
OS
if OS_RELEASE_FILE="$tmp/unsupported" detect_supported_os 2>/dev/null; then
  echo "Unsupported OS detection test failed" >&2
  exit 1
fi

# Base packages must not include ufw or Ubuntu-only software-properties-common.
(
  # shellcheck disable=SC1091
  source "$ROOT/scripts/install-base.sh"
  base_packages=()
  log() { :; }
  run_step() { :; }
  sudo() { :; }
  install_apt_packages() { base_packages=("$@"); }
  OS_ID=debian
  install_base
  for unwanted in software-properties-common ufw; do
    if [[ " ${base_packages[*]} " == *" $unwanted "* ]]; then
      echo "Base packages must not include $unwanted" >&2
      exit 1
    fi
  done
  for wanted in rsync xz-utils; do
    if [[ " ${base_packages[*]} " != *" $wanted "* ]]; then
      echo "Base packages must include $wanted" >&2
      exit 1
    fi
  done
)

echo "All tests passed"
