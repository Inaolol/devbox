#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY=""
WITHOUT_AI=0
WITHOUT_TAILSCALE=0
WITH_ADGUARD=0
DRY_RUN=0
STATE_DIR="$HOME/.local/state/devbox"
INSTALL_MARKER="$STATE_DIR/installed"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --only COMPONENT       Install one component: base, docker, tailscale, terminal, ai, 1password, configs, services, adguard
  --without-ai           Skip AI command line tools
  --without-tailscale    Skip Tailscale
  --with-adguard         Install AdGuard Home ad blocker (opt-in)
  --dry-run              Print commands without executing them
  -h, --help             Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --without-ai) WITHOUT_AI=1; shift ;;
    --without-tailscale) WITHOUT_TAILSCALE=1; shift ;;
    --with-adguard) WITH_ADGUARD=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -f "$INSTALL_MARKER" || -e "$HOME/.config/shell/devbox-server" ]]; then
  DEVBOX_UPDATE=1
else
  DEVBOX_UPDATE=0
fi

export REPO_ROOT DRY_RUN DEVBOX_UPDATE
source "$REPO_ROOT/scripts/lib.sh"
require_supported_os
require_non_root

run_component() {
  local name="$1"
  shift
  if [[ -z "$ONLY" || "$ONLY" == "$name" ]]; then
    "$@"
  fi
}

source "$REPO_ROOT/scripts/install-base.sh"
source "$REPO_ROOT/scripts/install-docker.sh"
source "$REPO_ROOT/scripts/install-tailscale.sh"
source "$REPO_ROOT/scripts/install-terminal.sh"
source "$REPO_ROOT/scripts/install-ai.sh"
source "$REPO_ROOT/scripts/install-1password.sh"
source "$REPO_ROOT/scripts/install-configs.sh"
source "$REPO_ROOT/scripts/install-services.sh"
source "$REPO_ROOT/scripts/install-adguard.sh"
source "$REPO_ROOT/scripts/migrations.sh"

if [[ "$DEVBOX_UPDATE" -eq 1 && -z "$ONLY" ]]; then
  run_migrations
fi

run_component base install_base
run_component docker install_docker
if [[ "$WITHOUT_TAILSCALE" -eq 0 ]]; then run_component tailscale install_tailscale; fi
run_component terminal install_terminal
if [[ "$WITHOUT_AI" -eq 0 ]]; then run_component ai install_ai; fi
run_component 1password install_1password
if [[ "$DEVBOX_UPDATE" -eq 0 || -n "$ONLY" ]]; then
  run_component configs install_configs
else
  run_component configs refresh_configs
fi
run_component services install_services

if [[ "$WITH_ADGUARD" -eq 1 || "$ONLY" == "adguard" ]]; then
  run_component adguard install_adguard
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$STATE_DIR"
  touch "$INSTALL_MARKER"
fi

log "Installation complete. Sign out and back in if Docker group access was added."
