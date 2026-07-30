#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY=""
WITHOUT_AI=0
WITHOUT_TAILSCALE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --only COMPONENT       Install one component: base, docker, tailscale, terminal, ai, configs
  --without-ai           Skip AI command line tools
  --without-tailscale    Skip Tailscale
  --dry-run              Print commands without executing them
  -h, --help             Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --without-ai) WITHOUT_AI=1; shift ;;
    --without-tailscale) WITHOUT_TAILSCALE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

export REPO_ROOT DRY_RUN
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
source "$REPO_ROOT/scripts/install-configs.sh"

run_component base install_base
run_component docker install_docker
if [[ "$WITHOUT_TAILSCALE" -eq 0 ]]; then run_component tailscale install_tailscale; fi
run_component terminal install_terminal
if [[ "$WITHOUT_AI" -eq 0 ]]; then run_component ai install_ai; fi
run_component configs install_configs

log "Installation complete. Sign out and back in if Docker group access was added."
