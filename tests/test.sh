#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  bash -n "$file"
done
bash -n "$ROOT/scripts/devbox-setup" "$ROOT/configs/shell/devbox-server"

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
grep -q 'set -g prefix C-Space' "$ROOT/configs/tmux.conf"
grep -q 'prefix2 C-b' "$ROOT/configs/tmux.conf"
grep -q 'omacom-io/omadots' "$ROOT/scripts/install-configs.sh"
# The literal HOME expression must appear in the installer.
# shellcheck disable=SC2016
grep -q 'backup_path "$HOME/.bashrc"' "$ROOT/scripts/install-configs.sh"
grep -q 'tmux-free' "$ROOT/scripts/install-configs.sh"
grep -q "alias lzd='lazydocker'" "$ROOT/configs/shell/devbox-server"
grep -q 'disable-password-auth' "$ROOT/scripts/devbox-setup"
grep -q 'sshd -t' "$ROOT/scripts/devbox-setup"
grep -q 'not Tailscale SSH' "$ROOT/scripts/devbox-setup"
grep -q -- '--with-adguard' "$ROOT/install.sh"
grep -q 'adguard/adguardhome' "$ROOT/scripts/install-adguard.sh"
grep -q '53:53' "$ROOT/scripts/install-adguard.sh"

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
