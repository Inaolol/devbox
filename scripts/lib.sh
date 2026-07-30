#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }

run() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '+ '; printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

require_non_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo "Run this installer as your normal user, not root. It uses sudo when needed." >&2
    exit 1
  fi
}

detect_supported_os() {
  local os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$os_release_file" ]] || { echo "Cannot identify this operating system." >&2; return 1; }

  local ID="" VERSION_ID="" VERSION_CODENAME="" UBUNTU_CODENAME="" PRETTY_NAME=""
  # shellcheck disable=SC1090
  source "$os_release_file"

  case "${ID:-}" in
    ubuntu)
      OS_ID="ubuntu"
      OS_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
      ;;
    debian)
      OS_ID="debian"
      OS_CODENAME="${VERSION_CODENAME:-}"
      ;;
    *)
      echo "Supported systems are Ubuntu Server and Debian. Detected: ${ID:-unknown}" >&2
      return 1
      ;;
  esac

  if [[ -z "$OS_CODENAME" ]]; then
    echo "Could not determine the ${OS_ID} release codename." >&2
    return 1
  fi

  OS_VERSION_ID="${VERSION_ID:-unknown}"
  OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID $OS_VERSION_ID}"
  OS_ARCHITECTURE="${OS_ARCHITECTURE:-$(dpkg --print-architecture)}"

  local major_version="${OS_VERSION_ID%%.*}"
  if [[ "$major_version" =~ ^[0-9]+$ ]]; then
    if [[ "$OS_ID" == "ubuntu" && "$major_version" -lt 24 ]]; then
      echo "Ubuntu 24.04 or newer is required. Detected: $OS_PRETTY_NAME" >&2
      return 1
    fi
    if [[ "$OS_ID" == "debian" && "$major_version" -lt 12 ]]; then
      echo "Debian 12 or newer is required. Detected: $OS_PRETTY_NAME" >&2
      return 1
    fi
  fi

  case "$OS_ARCHITECTURE" in
    amd64|arm64) ;;
    *)
      echo "Supported architectures are amd64 and arm64. Detected: $OS_ARCHITECTURE" >&2
      return 1
      ;;
  esac

  export OS_ID OS_CODENAME OS_VERSION_ID OS_PRETTY_NAME OS_ARCHITECTURE
}

require_supported_os() {
  detect_supported_os
  log "Detected $OS_PRETTY_NAME ($OS_ID/$OS_CODENAME)"
}

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup
    backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
    run mv "$path" "$backup"
    log "Backed up $path to $backup"
  fi
}

install_apt_packages() {
  run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
