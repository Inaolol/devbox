#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  bash -n "$file"
done
bash -n "$ROOT/scripts/devbox-setup" "$ROOT/configs/shell/devbox-server"
bash -n "$ROOT/bin/devbox" "$ROOT/scripts/devbox-db"

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

grep -q 'set -Eeuo pipefail' "$ROOT/install.sh"
grep -q 'require_supported_os' "$ROOT/install.sh"
grep -q 'run_component services install_services' "$ROOT/install.sh"
if grep -qi '1password' "$ROOT/install.sh"; then
  echo "1Password must not be installed or managed by DevBox" >&2
  exit 1
fi
grep -q 'run_component configs refresh_configs' "$ROOT/install.sh"
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

# Structured progress: run() captures output into the install log, shows a
# concise result line, and surfaces the failing output tail on errors.
grep -q 'DEVBOX_INSTALL_LOG_FILE' "$ROOT/scripts/lib.sh"
grep -q 'install_start_log' "$ROOT/scripts/lib.sh"
grep -q 'install_end_log' "$ROOT/scripts/lib.sh"
grep -q 'install_fail_log' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install started' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install completed' "$ROOT/scripts/lib.sh"
grep -q '=== Devbox install FAILED' "$ROOT/scripts/lib.sh"
grep -q 'Last output' "$ROOT/scripts/lib.sh"
grep -q "✓" "$ROOT/scripts/lib.sh"
grep -q "✗" "$ROOT/scripts/lib.sh"
# Failed and interrupted commands must reach the spinner cleanup under set -e.
grep -q 'if "\$@" >>"\$log_file" 2>&1; then' "$ROOT/scripts/lib.sh"
grep -q 'install_start_log' "$ROOT/install.sh"
grep -q 'DEVBOX_INSTALL_LOG_FILE' "$ROOT/install.sh"
grep -q "run bash \"\$migration\"" "$ROOT/scripts/migrations.sh"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  export DEVBOX_INSTALL_LOG_FILE="$work/install.log"
  export DRY_RUN=0
  source "$ROOT/scripts/lib.sh"
  run printf '%s' 'hidden output' >/dev/null 2>&1
  grep -q '^hidden output$' "$work/install.log"
  set +e
  run sh -c 'echo oops; exit 3' >/dev/null 2>&1
  status=$?
  set -e
  (( status == 3 ))
  install_start_log
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
grep -q 'docker-ce' "$ROOT/scripts/install-docker.sh"
grep -q 'podman-docker' "$ROOT/scripts/install-docker.sh"
grep -q 'DOCKER-USER' "$ROOT/scripts/install-docker.sh"
# The literal placeholder must appear in the installer.
# shellcheck disable=SC2016
grep -q 'download.docker.com/linux/${OS_ID}' "$ROOT/scripts/install-docker.sh"
grep -q 'nvim-linux-x86_64.tar.gz' "$ROOT/scripts/install-terminal.sh"
grep -q '0.11.2' "$ROOT/scripts/install-terminal.sh"
grep -q 'bash-completion bat' "$ROOT/scripts/install-terminal.sh"
grep -q 'command -v batcat' "$ROOT/scripts/install-terminal.sh"
grep -q 'install_eza' "$ROOT/scripts/install-terminal.sh"
grep -q 'install_gum' "$ROOT/scripts/install-terminal.sh"
grep -q 'kitty-terminfo' "$ROOT/scripts/install-terminal.sh"
# zoxide must come from the pinned mise registry, not an unpinned install.sh
# from the project's default branch.
grep -q '"$mise_bin" use --global --yes zoxide' "$ROOT/scripts/install-terminal.sh"
if grep -q 'ajeetdsouza/zoxide' "$ROOT/scripts/install-terminal.sh"; then
  echo "zoxide must not be installed from an unpinned remote script" >&2
  exit 1
fi
# The literal release URL placeholders must appear in the installer.
# shellcheck disable=SC2016
grep -q 'lazygit_${version}_linux_${arch}.tar.gz' "$ROOT/scripts/install-terminal.sh"
# The latest-release lookup must fail clearly on rate limits and empty
# responses instead of flowing the literal tag "null" into download URLs.
grep -q '.tag_name // empty' "$ROOT/scripts/install-terminal.sh"
grep -q 'Could not determine the latest release tag' "$ROOT/scripts/install-terminal.sh"
(
  # shellcheck disable=SC1091
  source "$ROOT/scripts/install-terminal.sh"
  curl() { printf '%s' '{"message":"API rate limit exceeded"}'; }
  if latest_github_release_tag eza-community/eza >/dev/null 2>&1; then
    echo "latest_github_release_tag must fail on a rate-limited response" >&2
    exit 1
  fi
  curl() { printf '%s' '{"tag_name":"v0.21.4"}'; }
  [[ "$(latest_github_release_tag eza-community/eza)" == "v0.21.4" ]]
)
grep -q 'aqua:modem-dev/hunk' "$ROOT/scripts/install-ai.sh"
grep -q 'antigravity-cli' "$ROOT/scripts/install-ai.sh"
# Match the tool name as a standalone token: the Antigravity skills path
# contains ".gemini/" but must not trip this guard.
if grep -qE '(^|[[:space:]])gemini([[:space:]]|$)' "$ROOT/scripts/install-ai.sh"; then
  echo "Deprecated Gemini CLI should not be installed; Antigravity CLI replaces it" >&2
  exit 1
fi
if grep -q 'github:basecamp/basecamp-cli' "$ROOT/scripts/install-ai.sh"; then
  echo "Product-specific Basecamp CLI should not be installed" >&2
  exit 1
fi
grep -q 'No API keys are stored' "$ROOT/scripts/install-ai.sh"
# These literal HOME paths must remain user-owned skill roots.
# shellcheck disable=SC2016
grep -q '"$HOME/.agents/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.claude/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.codex/skills"' "$ROOT/scripts/install-ai.sh"
# The Antigravity CLI reads global skills from ~/.gemini/antigravity-cli/skills.
# shellcheck disable=SC2016
grep -q '"$HOME/.gemini/antigravity-cli/skills"' "$ROOT/scripts/install-ai.sh"
# shellcheck disable=SC2016
grep -q '"$HOME/.pi/agent/skills"' "$ROOT/scripts/install-ai.sh"
(
  HOME="$(mktemp -d)"
  log() { :; }
  run() { "$@"; }
  source "$ROOT/scripts/install-ai.sh"
  install_agent_skill_directories
  touch "$HOME/.agents/skills/user-skill"
  install_agent_skill_directories
  test -d "$HOME/.claude/skills"
  test -d "$HOME/.codex/skills"
  test -d "$HOME/.gemini/antigravity-cli/skills"
  test -d "$HOME/.pi/agent/skills"
  test -e "$HOME/.agents/skills/user-skill"
  rm -rf "$HOME"
)
grep -q 'set -g prefix C-Space' "$ROOT/configs/tmux.conf"
grep -q 'prefix2 C-b' "$ROOT/configs/tmux.conf"
grep -q 'omacom-io/omadots' "$ROOT/scripts/install-configs.sh"
# Upstream configs are sourced by every login shell; they must stay pinned
# to full commit SHAs so upstream changes land deliberately.
grep -qE 'OMADOTS_REF="[0-9a-f]{40}"' "$ROOT/scripts/install-configs.sh"
grep -qE 'LAZYVIM_STARTER_REF="[0-9a-f]{40}"' "$ROOT/scripts/install-configs.sh"
grep -q 'clone_pinned https://github.com/omacom-io/omadots.git "\$OMADOTS_REF"' "$ROOT/scripts/install-configs.sh"
grep -q 'clone_pinned https://github.com/LazyVim/starter.git "\$LAZYVIM_STARTER_REF"' "$ROOT/scripts/install-configs.sh"
# The pinned checkout must be verified against the expected SHA.
grep -q 'rev-parse HEAD' "$ROOT/scripts/install-configs.sh"
# The literal HOME expression must appear in the installer.
# shellcheck disable=SC2016
grep -q 'backup_path "$HOME/.bashrc"' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'git config --file "$HOME/.gitconfig" user.name' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -q 'git config --file "$HOME/.gitconfig" user.email' "$ROOT/scripts/install-configs.sh"
grep -q 'tmux-free' "$ROOT/scripts/install-configs.sh"
grep -q 'Git identity is already configured' "$ROOT/scripts/devbox-setup"
grep -q 'GitHub is already authenticated' "$ROOT/scripts/devbox-setup"
grep -q 'gh auth login --hostname github.com --git-protocol https --web </dev/null' "$ROOT/scripts/devbox-setup"
grep -q 'Tailscale is already connected' "$ROOT/scripts/devbox-setup"
grep -q 'An SSH public key is already installed' "$ROOT/scripts/devbox-setup"
grep -q "alias lzd='lazydocker'" "$ROOT/configs/shell/devbox-server"
grep -q "alias cls='clear'" "$ROOT/configs/shell/devbox-server"
# The literal fallback must initialize tmux with UTF-8 character handling.
# shellcheck disable=SC2016
grep -q 'export LANG="${LANG:-C.UTF-8}"' "$ROOT/configs/shell/devbox-server"
grep -q 'C.UTF-8' "$ROOT/migrations/20260731-set-utf8-locale.sh"
grep -q 'disable-password-auth' "$ROOT/scripts/devbox-setup"
grep -q 'sshd -t' "$ROOT/scripts/devbox-setup"
grep -q 'not Tailscale SSH' "$ROOT/scripts/devbox-setup"
grep -q -- '--with-adguard' "$ROOT/install.sh"
grep -q 'adguard/adguardhome' "$ROOT/scripts/install-adguard.sh"
grep -q '53:53' "$ROOT/scripts/install-adguard.sh"
# The AdGuard web admin must not be reachable from the network: only DNS
# (port 53, the component's purpose) stays published on all interfaces.
if grep -Eq '"(80|3000):(80|3000)' "$ROOT/scripts/install-adguard.sh"; then
  echo "AdGuard admin ports must be bound to 127.0.0.1" >&2
  exit 1
fi
grep -q '127.0.0.1:3000:3000' "$ROOT/scripts/install-adguard.sh"
grep -q '127.0.0.1:80:80' "$ROOT/scripts/install-adguard.sh"

grep -q 'sudo tailscale up' "$ROOT/scripts/devbox-setup"

# The Tailscale auth key must travel through the environment, never argv
# (argv is readable by any local user via ps and /proc/*/cmdline).
grep -q 'TS_AUTHKEY' "$ROOT/scripts/devbox-setup"
if grep -qF -- '--auth-key=$auth_key' "$ROOT/scripts/devbox-setup"; then
  echo "Tailscale auth key must not be passed as a command argument" >&2
  exit 1
fi
# Secret-bearing env vars must be unset once consumed.
grep -q 'DEVBOX_SETUP_GH_TOKEN DEVBOX_SETUP_TS_AUTH_KEY' "$ROOT/scripts/install-services.sh"
# Remote installers must fail on HTTP errors instead of piping error pages
# into sh, and follow redirects.
grep -q 'curl -fsSL https://mise.run' "$ROOT/scripts/install-terminal.sh"
grep -q 'curl -fsSL https://starship.rs/install.sh' "$ROOT/scripts/install-terminal.sh"
# The bootstrap refuses to run as root before touching the system.
grep -q 'EUID' "$ROOT/bootstrap.sh"
# bootstrap must refuse to clobber a non-empty directory that is not a
# devbox checkout instead of removing it.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/target"
  touch "$work/target/keepme"
  if DEVBOX_DIR="$work/target" bash "$ROOT/bootstrap.sh" >/dev/null 2>&1; then
    echo "bootstrap must refuse a non-empty non-checkout DEVBOX_DIR" >&2
    exit 1
  fi
  [[ -e "$work/target/keepme" ]]
)

# Services installs the devbox CLI and devbox-db.
grep -q 'devbox-db' "$ROOT/scripts/install-services.sh"
grep -q 'install_devbox_cli' "$ROOT/scripts/install-services.sh"
grep -q 'DEVBOX_PATH' "$ROOT/scripts/install-services.sh"

# Editor configs: Neovim QoL plugins and lazygit config are managed files.
grep -q 'configs/nvim/plugins' "$ROOT/scripts/install-configs.sh"
grep -q 'configs/lazygit/config.yml' "$ROOT/scripts/install-configs.sh"
grep -q 'refresh_configs' "$ROOT/scripts/install-configs.sh"
grep -q 'refresh_managed_file' "$ROOT/scripts/install-configs.sh"
# Refresh shows the diff between the backup and the new config, omarchy-style.
grep -q 'diff -u' "$ROOT/scripts/install-configs.sh"
# Force-replacing configs must preserve a legacy user secret.
grep -q 'OP_SERVICE_ACCOUNT_TOKEN' "$ROOT/scripts/install-configs.sh"
# Replacing configs must preserve mise tools installed by install-ai.
grep -q 'mise_tools' "$ROOT/scripts/install-configs.sh"
# shellcheck disable=SC2016
grep -qF '\[tools\]' "$ROOT/scripts/install-configs.sh"
test -f "$ROOT/configs/nvim/plugins/colorscheme.lua"
test -f "$ROOT/configs/nvim/plugins/disable-news-alert.lua"
test -f "$ROOT/configs/nvim/plugins/snacks-animated-scrolling.lua"
test -f "$ROOT/configs/lazygit/config.yml"
grep -q '#7aa2f7' "$ROOT/configs/lazygit/config.yml"
grep -q 'showGraph' "$ROOT/configs/lazygit/config.yml"
grep -q 'lazygit' "$ROOT/migrations/20260805-install-editor-configs.sh"
grep -q 'colorscheme.lua' "$ROOT/migrations/20260805-install-editor-configs.sh"

# Dev databases: localhost-only containers for the full dev stack.
grep -q '127.0.0.1' "$ROOT/scripts/devbox-db"
grep -q 'postgres:18' "$ROOT/scripts/devbox-db"
grep -q 'mysql:8.4' "$ROOT/scripts/devbox-db"
grep -q 'redis:7' "$ROOT/scripts/devbox-db"
grep -q 'gum choose' "$ROOT/scripts/devbox-db"
grep -q 'devbox-db remove' "$ROOT/scripts/devbox-db"
# Menu labels must map explicitly to installable keys: lowercasing produced
# "postgresql" and "mongodb", which db_name does not recognize, so selecting
# PostgreSQL or MongoDB in the menu silently did nothing.
grep -q 'PostgreSQL) db="postgres"' "$ROOT/scripts/devbox-db"
grep -q 'MongoDB) db="mongo"' "$ROOT/scripts/devbox-db"
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/bin"
  cat > "$work/bin/gum" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == "choose" ]] && printf '%s\n' "PostgreSQL" "MongoDB"
STUB
  cat > "$work/bin/docker" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "ps" ]]; then exit 0; fi
printf '%s\n' "$*" >>"$DEVBOX_DB_DOCKER_LOG"
STUB
  chmod +x "$work/bin/gum" "$work/bin/docker"
  sudo() { "$@"; }
  export -f sudo
  export DEVBOX_DB_DOCKER_LOG="$work/docker.log"
  PATH="$work/bin:$PATH" bash "$ROOT/scripts/devbox-db" >/dev/null
  grep -q -- '--name postgres18' "$work/docker.log"
  grep -q -- '--name mongodb' "$work/docker.log"
)

# The devbox CLI menu and subs.
grep -q 'DEVBOX_PATH' "$ROOT/bin/devbox"
grep -q 'devbox-sub' "$ROOT/bin/devbox"
grep -q 'gum choose' "$ROOT/bin/devbox-sub/menu.sh"
grep -q -- '--only adguard' "$ROOT/bin/devbox-sub/install.sh"
grep -q 'tailscaled' "$ROOT/bin/devbox-sub/remove.sh"
grep -q 'bootstrap.sh' "$ROOT/bin/devbox-sub/update.sh"

# Windows VM: dockurr/windows compose file, KVM check, localhost-only ports,
# env-var overrides for unattended installs, and the SSH tunnel hint.
grep -q 'dockurr/windows' "$ROOT/scripts/devbox-windows-vm"
grep -q '/dev/kvm' "$ROOT/scripts/devbox-windows-vm"
grep -q '127.0.0.1:3389' "$ROOT/scripts/devbox-windows-vm"
grep -q '127.0.0.1:8006' "$ROOT/scripts/devbox-windows-vm"
grep -q 'DEVBOX_VM_RAM' "$ROOT/scripts/devbox-windows-vm"
grep -q 'DEVBOX_VM_VERSION' "$ROOT/scripts/devbox-windows-vm"
grep -q 'ssh -L 3389' "$ROOT/scripts/devbox-windows-vm"
grep -q 'windows started successfully' "$ROOT/scripts/devbox-windows-vm"
grep -q 'docker compose' "$ROOT/scripts/devbox-windows-vm"
grep -q 'windows-vm' "$ROOT/bin/devbox-sub/menu.sh"
test -x "$ROOT/scripts/devbox-windows-vm"
# Bare `devbox vm` is an interactive session (install or manage), not help text.
grep -q 'interactive_vm' "$ROOT/scripts/devbox-windows-vm"
grep -q '"") interactive_vm ;;' "$ROOT/scripts/devbox-windows-vm"
grep -q 'Windows VM is configured' "$ROOT/scripts/devbox-windows-vm"
grep -q 'Reinstall' "$ROOT/scripts/devbox-windows-vm"
# The menu must survive failing subs and return to the loop, and cancels
# must not be errors.
grep -q 'if run_sub "$sub"; then' "$ROOT/bin/devbox-sub/menu.sh"
grep -q 'exited with an error (code' "$ROOT/bin/devbox-sub/menu.sh"
grep -q "\[\[ \"\$sub\" == \"help\" \]\] && exit 0" "$ROOT/bin/devbox-sub/menu.sh"
grep -q 'clear' "$ROOT/bin/devbox-sub/menu.sh"
grep -q 'header.sh' "$ROOT/bin/devbox-sub/menu.sh"
grep -q 'press Enter to return to the menu' "$ROOT/bin/devbox-sub/menu.sh"
grep -q 'cancel()' "$ROOT/scripts/devbox-windows-vm"
grep -q "tr ' ' '\\\\n'" "$ROOT/scripts/devbox-windows-vm"
# The compose file holds the Windows password: user-only permissions and
# values that cannot inject YAML lines.
grep -q 'umask 077' "$ROOT/scripts/devbox-windows-vm"
grep -q 'chmod 600 "$COMPOSE_FILE"' "$ROOT/scripts/devbox-windows-vm"
grep -q 'yaml_quote' "$ROOT/scripts/devbox-windows-vm"
# Every value in the compose file, including the timezone, must pass
# through yaml_quote.
grep -q 'TZ: $(yaml_quote' "$ROOT/scripts/devbox-windows-vm"
# Reading USERNAME back must reverse yaml_quote's escaping so usernames
# containing quotes or backslashes display as entered.
grep -qF 's/\\\\/\x01/g' "$ROOT/scripts/devbox-windows-vm"
(
  unquote() { sed 's/^[^"]*"\(.*\)"$/\1/; s/\\\\/\x01/g; s/\\"/"/g; s/\x01/\\/g'; }
  [[ "$(printf '      USERNAME: "dev\\"box"\n' | unquote)" == 'dev"box' ]]
  [[ "$(printf '      USERNAME: "a\\\\b"\n' | unquote)" == 'a\b' ]]
  [[ "$(printf '      USERNAME: "devbox"\n' | unquote)" == 'devbox' ]]
)
# The password must not be printed to the terminal.
if grep -q 'password \$win_pass' "$ROOT/scripts/devbox-windows-vm"; then
  echo "devbox vm must not print the Windows password" >&2
  exit 1
fi
# The install log captures command output; it must stay user-readable only.
grep -q 'umask 077' "$ROOT/scripts/lib.sh"
# Failures must record the failing command in the install log.
grep -q 'Failed command' "$ROOT/scripts/lib.sh"
grep -q 'install_fail_log "\$status" "\$BASH_COMMAND"' "$ROOT/install.sh"
# Update detection trusts the marker alone; a foreign dotfiles file must
# never flip a first install into update mode.
if grep -q 'devbox-server".*DEVBOX_UPDATE\|DEVBOX_UPDATE.*devbox-server' "$ROOT/install.sh"; then
  echo "Update detection must rely on the installed marker only" >&2
  exit 1
fi
grep -q '|| return 0' "$ROOT/scripts/devbox-db"
# An unknown --only component must be rejected before anything runs, so a
# typo cannot mark a fresh machine as installed and flip it to update mode.
(
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  if HOME="$work" bash "$ROOT/install.sh" --only servieces >/dev/null 2>&1; then
    echo "--only must reject unknown components" >&2
    exit 1
  fi
  [[ ! -e "$work/.local/state/devbox/installed" ]]
)
grep -q 'gum_choose DEVBOX_VM_RAM' "$ROOT/scripts/devbox-windows-vm"

# Test OS detection independently of the host running the test.
# ROOT is computed at runtime, so ShellCheck cannot resolve this source path.
# shellcheck disable=SC1091
source "$ROOT/scripts/lib.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
OS_ARCHITECTURE=amd64

cat > "$tmp/ubuntu" <<'OS'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
PRETTY_NAME="Ubuntu 24.04 LTS"
OS
OS_RELEASE_FILE="$tmp/ubuntu" detect_supported_os
[[ "$OS_ID" == ubuntu && "$OS_CODENAME" == noble ]]

cat > "$tmp/debian12" <<'OS'
ID=debian
VERSION_ID="12"
VERSION_CODENAME=bookworm
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
OS
OS_RELEASE_FILE="$tmp/debian12" detect_supported_os
[[ "$OS_ID" == debian && "$OS_CODENAME" == bookworm ]]

cat > "$tmp/debian13" <<'OS'
ID=debian
VERSION_ID="13"
VERSION_CODENAME=trixie
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
OS
OS_RELEASE_FILE="$tmp/debian13" detect_supported_os
[[ "$OS_ID" == debian && "$OS_CODENAME" == trixie ]]

OS_ARCHITECTURE=i386
if OS_RELEASE_FILE="$tmp/debian13" detect_supported_os 2>/dev/null; then
  echo "Unsupported architecture test failed" >&2
  exit 1
fi
# Reset for later suites; consumed by detect_supported_os, not this file.
# shellcheck disable=SC2034
OS_ARCHITECTURE=amd64

cat > "$tmp/old-debian" <<'OS'
ID=debian
VERSION_ID="11"
VERSION_CODENAME=bullseye
PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
OS
if OS_RELEASE_FILE="$tmp/old-debian" detect_supported_os 2>/dev/null; then
  echo "Old Debian version test failed" >&2
  exit 1
fi

cat > "$tmp/unsupported" <<'OS'
ID=opensuse-leap
VERSION_ID="15.6"
VERSION_CODENAME=leap
OS
if OS_RELEASE_FILE="$tmp/unsupported" detect_supported_os 2>/dev/null; then
  echo "Unsupported OS detection test failed" >&2
  exit 1
fi

# Debian 13 does not provide software-properties-common. Keep Ubuntu-only
# packages out of the shared Debian base package list.
# shellcheck disable=SC1091
source "$ROOT/scripts/install-base.sh"
base_packages=()
log() { :; }
run() { :; }
install_apt_packages() { base_packages=("$@"); }
OS_ID=debian
install_base
if [[ " ${base_packages[*]} " == *" software-properties-common "* ]]; then
  echo "Debian base packages include unavailable software-properties-common" >&2
  exit 1
fi

echo "All tests passed"
