#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY=""
WITHOUT_AI=0
WITHOUT_TAILSCALE=0
DRY_RUN=0
STATE_DIR="$HOME/.local/state/devbox"
INSTALL_MARKER="$STATE_DIR/installed"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --only COMPONENT       Install one component: base, docker, tailscale, terminal, ai, configs, services
  --without-ai           Skip AI command line tools
  --without-tailscale    Skip Tailscale
  --dry-run              Print commands without executing them
  -h, --help             Show help
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --only)
      if (( $# < 2 )) || [[ $2 == -* ]]; then
        echo "Option --only requires a component name." >&2
        usage >&2
        exit 2
      fi
      ONLY="$2"
      shift 2
      ;;
    --without-ai) WITHOUT_AI=1; shift ;;
    --without-tailscale) WITHOUT_TAILSCALE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

DEVBOX_COMPONENTS=(base docker tailscale terminal ai configs services)

known_component() {
  local name
  for name in "${DEVBOX_COMPONENTS[@]}"; do
    [[ $1 == "$name" ]] && return 0
  done
  return 1
}

if [[ -n $ONLY ]] && ! known_component "$ONLY"; then
  echo "Unknown component: $ONLY (expected: ${DEVBOX_COMPONENTS[*]})" >&2
  usage >&2
  exit 2
fi

if [[ -f $INSTALL_MARKER ]]; then
  DEVBOX_UPDATE=1
else
  DEVBOX_UPDATE=0
fi

export REPO_ROOT DRY_RUN DEVBOX_UPDATE
# shellcheck source=scripts/lib.sh
source "$REPO_ROOT/scripts/lib.sh"
detect_supported_os
require_non_root
require_sudo

export DEVBOX_INSTALL_LOG_FILE="${DEVBOX_INSTALL_LOG_FILE:-$STATE_DIR/install.log}"
if (( DRY_RUN == 0 )); then
  install_start_log
fi
trap cleanup_temp_dirs EXIT
trap 'status=$?; (( DRY_RUN == 0 )) && install_fail_log "$status" "$BASH_COMMAND"; exit "$status"' ERR

# shellcheck source=scripts/install-base.sh
source "$REPO_ROOT/scripts/install-base.sh"
# shellcheck source=scripts/install-docker.sh
source "$REPO_ROOT/scripts/install-docker.sh"
# shellcheck source=scripts/install-tailscale.sh
source "$REPO_ROOT/scripts/install-tailscale.sh"
# shellcheck source=scripts/install-terminal.sh
source "$REPO_ROOT/scripts/install-terminal.sh"
# shellcheck source=scripts/install-ai.sh
source "$REPO_ROOT/scripts/install-ai.sh"
# shellcheck source=scripts/install-configs.sh
source "$REPO_ROOT/scripts/install-configs.sh"
# shellcheck source=scripts/install-services.sh
source "$REPO_ROOT/scripts/install-services.sh"
# shellcheck source=scripts/migrations.sh
source "$REPO_ROOT/scripts/migrations.sh"

component_enabled() {
  local name="$1"
  if [[ -n $ONLY ]]; then
    [[ $ONLY == "$name" ]]
    return $?
  fi
  case "$name" in
    tailscale) (( WITHOUT_TAILSCALE == 0 )) ;;
    ai) (( WITHOUT_AI == 0 )) ;;
    *) return 0 ;;
  esac
}

component_label() {
  case "$1" in
    base) printf 'Base system packages, OpenSSH, and SSH keepalives' ;;
    docker) printf 'Docker Engine, Compose, and log rotation' ;;
    tailscale) printf 'Tailscale VPN' ;;
    terminal) printf 'Terminal tools, Herdr, Neovim, Nerd Font, and mise' ;;
    ai) printf 'AI CLI tools via mise' ;;
    configs)
      if (( DEVBOX_UPDATE == 1 )) && [[ -z $ONLY ]]; then
        printf 'Refresh managed herdr, tmux, and starship configs'
      else
        printf 'Shell, herdr, tmux, and LazyVim configs'
      fi
      ;;
    services) printf 'DevBox CLI and onboarding helpers' ;;
  esac
}

active_steps=()
skipped_steps=()
for name in "${DEVBOX_COMPONENTS[@]}"; do
  if component_enabled "$name"; then
    active_steps+=("$name")
  elif [[ -z $ONLY ]]; then
    skipped_steps+=("$name")
  fi
done

mode_label="Fresh install"
(( DEVBOX_UPDATE == 1 )) && mode_label="Update"
(( DRY_RUN == 1 )) && mode_label="$mode_label (dry-run)"

log "DevBox — $mode_label"
printf '  System:     %s (%s)\n' "$OS_PRETTY_NAME" "$OS_ARCHITECTURE"
printf '  Components: %s\n' "${active_steps[*]}"
if (( ${#skipped_steps[@]} > 0 )); then
  printf '  Skipped:    %s\n' "${skipped_steps[*]}"
fi

APT_REPOS_PREPARED=0
if [[ -z $ONLY ]] && command -v curl >/dev/null 2>&1; then
  log "Preparing APT repositories"
  setup_docker_apt_repo
  if (( WITHOUT_TAILSCALE == 0 )); then
    setup_tailscale_apt_repo
  fi
  setup_terminal_apt_repos
  APT_REPOS_PREPARED=1
fi

if (( DEVBOX_UPDATE == 1 )) && [[ -z $ONLY ]]; then
  run_migrations
fi

step_index=0
total_steps="${#active_steps[@]}"
for name in "${active_steps[@]}"; do
  step_index=$((step_index + 1))
  step_header "$step_index" "$total_steps" "$(component_label "$name")"
  case "$name" in
    base) install_base ;;
    docker) install_docker ;;
    tailscale) install_tailscale ;;
    terminal) install_terminal ;;
    ai) install_ai ;;
    configs)
      if (( DEVBOX_UPDATE == 0 )) || [[ -n $ONLY ]]; then
        install_configs
      else
        refresh_configs
      fi
      ;;
    services) install_services ;;
  esac
done

if (( DRY_RUN == 0 )); then
  mkdir -p "$STATE_DIR"
  touch "$INSTALL_MARKER"
  install_end_log
fi
log "DevBox installation complete!"
if (( DEVBOX_UPDATE == 0 )); then
  printf '  Next steps:\n'
  printf '    1. Open a new login shell (loads PATH, Starship prompt, and Docker group)\n'
  printf '    2. Run \033[1mdevbox setup\033[0m to connect Git, GitHub, Tailscale, and SSH\n'
  printf '    3. Optional: run \033[1mdevbox setup startup herdr\033[0m (or \033[1mtmux\033[0m) to auto-attach on SSH login (off by default)\n'
  printf '    4. Run \033[1mherdr --remote user@this-server\033[0m from your laptop, or \033[1mdevbox\033[0m for the menu\n'
  printf '    Note: Over SSH, set your local terminal font to JetBrainsMono Nerd Font for prompt icons.\n'
else
  printf '  Open a new login shell if any updated tools or Docker settings changed.\n'
fi
