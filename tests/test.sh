#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  bash -n "$file"
done
bash -n "$ROOT/scripts/devbox-setup" "$ROOT/configs/shell/devbox-server"
bash -n "$ROOT/bin/devbox" "$ROOT/scripts/devbox-db"

if command -v shellcheck >/dev/null 2>&1; then
  find "$ROOT" -type f -name '*.sh' -print0 | xargs -0 shellcheck
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
# The literal release URL placeholders must appear in the installer.
# shellcheck disable=SC2016
grep -q 'lazygit_${version}_linux_${arch}.tar.gz' "$ROOT/scripts/install-terminal.sh"
grep -q 'aqua:modem-dev/hunk' "$ROOT/scripts/install-ai.sh"
grep -q 'antigravity-cli' "$ROOT/scripts/install-ai.sh"
if grep -q 'gemini' "$ROOT/scripts/install-ai.sh"; then
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
  test -d "$HOME/.pi/agent/skills"
  test -e "$HOME/.agents/skills/user-skill"
  rm -rf "$HOME"
)
grep -q 'set -g prefix C-Space' "$ROOT/configs/tmux.conf"
grep -q 'prefix2 C-b' "$ROOT/configs/tmux.conf"
grep -q 'omacom-io/omadots' "$ROOT/scripts/install-configs.sh"
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

grep -q 'sudo tailscale up' "$ROOT/scripts/devbox-setup"

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
grep -q '^\[tools\]' "$ROOT/scripts/install-configs.sh"
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
grep -q '|| return 0' "$ROOT/scripts/devbox-db"
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
