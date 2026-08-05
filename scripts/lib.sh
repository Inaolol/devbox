#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }

run() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '+ '; printf '%q ' "$@"; printf '\n'
    return 0
  fi

  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  if [[ -z "$log_file" ]]; then
    "$@"
    return $?
  fi

  if [[ ! -f "$log_file" ]]; then
    mkdir -p "$(dirname "$log_file")"
    : >"$log_file"
  fi

  local cmd_display="$*"
  local cmd_line=""
  printf -v cmd_line '%q ' "$@"
  cmd_line="${cmd_line% }"

  local log_start status spinner_pid start_secs elapsed stream
  log_start=$(( $(wc -l <"$log_file") + 1 ))
  start_secs=$SECONDS
  printf '\n$ %s\n' "$cmd_line" >>"$log_file"

  if [[ -t 2 ]]; then
    spinner "$cmd_display" &
    spinner_pid=$!
  fi

  "$@" >>"$log_file" 2>&1
  status=$?

  if [[ -n "${spinner_pid:-}" ]]; then
    kill "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
    printf '\r\033[2K' >&2
  fi

  elapsed=$((SECONDS - start_secs))
  stream=1
  [[ -t 2 ]] && stream=2
  if (( status == 0 )); then
    printf '\033[1;32m  ✓\033[0m %s \033[90m(%ss)\033[0m\n' "$cmd_display" "$elapsed" >&"$stream"
  else
    printf '\033[1;31m  ✗\033[0m %s \033[90m(%ss)\033[0m\n' "$cmd_display" "$elapsed" >&"$stream"
    printf '\033[1;31m  Last output:\033[0m\n' >&"$stream"
    tail -n +"$log_start" "$log_file" | tail -n 20 | sed 's/^/  /' >&"$stream"
  fi

  return "$status"
}

spinner() {
  local label="$1"
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while :; do
    printf '\r\033[90m%s\033[0m %s' "${frames[i % 10]}" "$label"
    i=$((i + 1))
    sleep 0.1
  done
}

install_start_log() {
  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  [[ -n "$log_file" ]] || return 0
  mkdir -p "$(dirname "$log_file")"
  export DEVBOX_START_TIME
  DEVBOX_START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  export DEVBOX_START_EPOCH
  DEVBOX_START_EPOCH="$(date +%s)"
  printf '\n=== Devbox install started: %s ===\n' "$DEVBOX_START_TIME" >>"$log_file"
}

install_end_log() {
  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  [[ -n "$log_file" ]] || return 0
  local end_time end_epoch duration mins secs
  end_time="$(date '+%Y-%m-%d %H:%M:%S')"
  end_epoch="$(date +%s)"
  duration=$((end_epoch - ${DEVBOX_START_EPOCH:-end_epoch}))
  mins=$((duration / 60))
  secs=$((duration % 60))
  printf '=== Devbox install completed: %s (%dm %ss) ===\n' "$end_time" "$mins" "$secs" >>"$log_file"
  log "Full install log: $log_file"
}

install_fail_log() {
  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  [[ -n "$log_file" ]] || return 0
  printf '=== Devbox install FAILED at %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$log_file"
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
