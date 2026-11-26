#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }

step_header() {
  local current="$1" total="$2" title="$3"
  printf '\n\033[1;34m[%d/%d]\033[0m \033[1m%s\033[0m\n' "$current" "$total" "$title"
}

DEVBOX_TEMP_DIRS=()
APT_UPDATED=0
APT_REPOS_DIRTY=0

register_temp_dir() {
  DEVBOX_TEMP_DIRS+=("$1")
}

cleanup_temp_dirs() {
  local path
  for path in "${DEVBOX_TEMP_DIRS[@]}"; do
    [[ -n $path ]] && rm -rf "$path"
  done
  DEVBOX_TEMP_DIRS=()
}

run_step() {
  local label="$1"
  shift

  if (( ${DRY_RUN:-0} == 1 )); then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  if [[ -z $log_file ]]; then
    "$@"
    return $?
  fi

  if [[ $1 == "sudo" ]]; then
    # sudo's password prompt must stay on the terminal: everything after this
    # point is redirected into the install log, where a prompt would hang unseen.
    sudo -v
  fi

  if [[ ! -f $log_file ]]; then
    mkdir -p "$(dirname "$log_file")"
    # The log captures command output that may be sensitive; keep it
    # readable by the owning user only.
    ( umask 077; : >"$log_file" )
  fi
  chmod 600 "$log_file"

  local cmd_line=""
  printf -v cmd_line '%q ' "$@"
  cmd_line="${cmd_line% }"

  local log_start status spinner_pid="" start_secs elapsed stream
  local old_int_trap old_term_trap
  log_start=$(( $(wc -l <"$log_file") + 1 ))
  start_secs=$SECONDS
  printf '\n$ %s\n' "$cmd_line" >>"$log_file"

  if [[ -t 2 ]]; then
    spinner "$label" &
    spinner_pid=$!
    old_int_trap="$(trap -p INT || true)"
    old_term_trap="$(trap -p TERM || true)"
    trap 'kill "$spinner_pid" 2>/dev/null || true; wait "$spinner_pid" 2>/dev/null || true; printf "\r\033[2K" >&2; exit 130' INT
    trap 'kill "$spinner_pid" 2>/dev/null || true; wait "$spinner_pid" 2>/dev/null || true; printf "\r\033[2K" >&2; exit 143' TERM
  fi

  if "$@" >>"$log_file" 2>&1; then
    status=0
  else
    status=$?
  fi

  if [[ -n $spinner_pid ]]; then
    kill "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
    printf '\r\033[2K' >&2
    if [[ -n $old_int_trap ]]; then eval "$old_int_trap"; else trap - INT; fi
    if [[ -n $old_term_trap ]]; then eval "$old_term_trap"; else trap - TERM; fi
  fi

  elapsed=$((SECONDS - start_secs))
  stream=1
  [[ -t 2 ]] && stream=2
  if (( status == 0 )); then
    printf '\033[1;32m  ✓\033[0m %s \033[90m(%ss)\033[0m\n' "$label" "$elapsed" >&"$stream"
  else
    printf '\033[1;31m  ✗\033[0m %s \033[90m(%ss)\033[0m\n' "$label" "$elapsed" >&"$stream"
    printf '\033[1;31m  Last output:\033[0m\n' >&"$stream"
    tail -n +"$log_start" "$log_file" | tail -n 20 | sed 's/^/  /' >&"$stream"
  fi

  return "$status"
}

run() {
  run_step "$*" "$@"
}

spinner() {
  local label="$1"
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while :; do
    printf '\r\033[90m%s\033[0m %s' "${frames[i % 10]}" "$label" >&2
    i=$((i + 1))
    sleep 0.1
  done
}

install_start_log() {
  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  [[ -n $log_file ]] || return 0
  mkdir -p "$(dirname "$log_file")"
  ( umask 077; : >>"$log_file" )
  chmod 600 "$log_file"
  export DEVBOX_START_TIME
  DEVBOX_START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  export DEVBOX_START_EPOCH
  DEVBOX_START_EPOCH="$(date +%s)"
  printf '\n=== Devbox install started: %s ===\n' "$DEVBOX_START_TIME" >>"$log_file"
}

install_end_log() {
  local log_file="${DEVBOX_INSTALL_LOG_FILE:-}"
  [[ -n $log_file ]] || return 0
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
  [[ -n $log_file ]] || return 0
  local status="${1:-unknown}" command="${2:-}"
  printf '=== Devbox install FAILED (exit %s) at %s ===\n' "$status" "$(date '+%Y-%m-%d %H:%M:%S')" >>"$log_file"
  [[ -z $command ]] || printf 'Failed command: %s\n' "$command" >>"$log_file"
  printf '\n\033[1;31mERROR:\033[0m Installation failed (exit %s). See full install log: %s\n' "$status" "$log_file" >&2
}

require_non_root() {
  if (( EUID == 0 )); then
    echo "Run this installer as your normal user, not root. It uses sudo when needed." >&2
    exit 1
  fi
}

require_sudo() {
  (( ${DRY_RUN:-0} == 1 )) && return 0
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  cat >&2 <<MSG

DevBox needs sudo for system packages. An SSH key only skips the SSH login
password; sudo still needs this account's password, which you will be asked
for once now. If this account has no password, sudo can never succeed: set
one with 'passwd', or (as root) allow passwordless sudo with
'echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER && chmod 440 /etc/sudoers.d/$USER'.
MSG
  sudo -v || {
    echo "Could not authenticate with sudo. Fix sudo access as described above, then rerun." >&2
    return 1
  }
}

detect_supported_os() {
  local os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r $os_release_file ]] || { echo "Cannot identify this operating system." >&2; return 1; }

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

  if [[ -z $OS_CODENAME ]]; then
    echo "Could not determine the ${OS_ID} release codename." >&2
    return 1
  fi

  OS_VERSION_ID="${VERSION_ID:-unknown}"
  OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID $OS_VERSION_ID}"
  OS_ARCHITECTURE="${OS_ARCHITECTURE:-$(dpkg --print-architecture)}"

  local major_version="${OS_VERSION_ID%%.*}"
  if [[ $major_version =~ ^[0-9]+$ ]]; then
    if [[ $OS_ID == "ubuntu" ]] && (( major_version < 24 )); then
      echo "Ubuntu 24.04 or newer is required. Detected: $OS_PRETTY_NAME" >&2
      return 1
    fi
    if [[ $OS_ID == "debian" ]] && (( major_version < 12 )); then
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

backup_path() {
  local path="$1"
  if [[ -e $path || -L $path ]]; then
    local backup
    backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
    run mv "$path" "$backup"
    log "Backed up $path to $backup"
  fi
}

ensure_apt_updated() {
  if (( APT_UPDATED == 0 || APT_REPOS_DIRTY == 1 )); then
    run_step "Updating package lists" sudo apt-get update
    APT_UPDATED=1
    APT_REPOS_DIRTY=0
  fi
}

install_apt_packages() {
  ensure_apt_updated
  run_step "Installing APT packages ($#): $*" \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

ensure_apt_keyring() {
  local label="$1" url="$2" dest="$3"
  [[ -s $dest ]] && return 0

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ download $url to $dest"
    APT_REPOS_DIRTY=1
    return 0
  fi

  local dest_dir tmp
  dest_dir="$(dirname "$dest")"
  [[ -d $dest_dir ]] || sudo install -m 0755 -d "$dest_dir"

  tmp="$(mktemp)"
  register_temp_dir "$tmp"
  run_step "$label" curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --max-time 30 "$url" -o "$tmp"
  sudo install -o root -g root -m 0644 "$tmp" "$dest"
  rm -f "$tmp"
  APT_REPOS_DIRTY=1
}

ensure_apt_source() {
  local label="$1" dest="$2" line="$3"
  if [[ -f $dest ]] && printf '%s\n' "$line" | cmp -s - "$dest"; then
    return 0
  fi

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ write $dest"
    APT_REPOS_DIRTY=1
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  register_temp_dir "$tmp"
  printf '%s\n' "$line" >"$tmp"
  run_step "$label" sudo install -o root -g root -m 0644 "$tmp" "$dest"
  rm -f "$tmp"
  APT_REPOS_DIRTY=1
}

find_mise() {
  local candidate
  for candidate in /usr/bin/mise "$HOME/.local/bin/mise"; do
    if [[ -x $candidate ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  command -v mise || true
}

verify_sha256() {
  local expected="$1" file="$2"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
}
