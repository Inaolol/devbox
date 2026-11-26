#!/usr/bin/env bash
set -Eeuo pipefail

confirm_action() {
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$1"
  else
    local answer
    printf '%s [y/N] ' "$1"
    IFS= read -r answer
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
  fi
}

app="${1:-}"

if [[ -z $app ]]; then
  choice="$(gum choose \
    "Tailscale      Remove Tailscale from this server" \
    "<< Back        " \
    --height 4 --header "Remove optional components")" || exit 0

  case "$choice" in
    ""|"<< Back"*) exit 0 ;;
    "Tailscale"*) app="tailscale" ;;
  esac
fi

case "$app" in
  tailscale)
    echo "Removing Tailscale cuts this server off your tailnet."
    echo "If you are connected over Tailscale SSH, run this from the console or another network."
    confirm_action "Continue removing Tailscale?" || exit 0
    sudo tailscale down 2>/dev/null || true
    sudo systemctl disable tailscaled 2>/dev/null || true
    sudo apt-get purge -y tailscale
    echo "Tailscale removed."
    ;;
  *)
    echo "devbox remove: unknown component '$app'" >&2
    echo "Try: tailscale" >&2
    exit 2
    ;;
esac
