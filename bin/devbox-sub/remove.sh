#!/usr/bin/env bash
set -Eeuo pipefail

app="${1:-}"

if [[ -z "$app" ]]; then
  choice="$(gum choose \
    "AdGuard Home   Stop and remove the ad blocker containers" \
    "Tailscale      Remove Tailscale from this server" \
    "<< Back        " \
    --height 5 --header "Remove optional components")" || exit 0

  case "$choice" in
    ""|"<< Back"*) exit 0 ;;
    "AdGuard Home"*) app="adguard" ;;
    "Tailscale"*) app="tailscale" ;;
  esac
fi

case "$app" in
  adguard)
    compose_file="$HOME/adguard/docker-compose.yml"
    if [[ ! -f "$compose_file" ]]; then
      echo "AdGuard Home is not installed here."
      exit 0
    fi
    sudo docker compose --project-name devbox-adguard -f "$compose_file" down --remove-orphans
    echo "AdGuard Home stopped and removed. Its data stays in ~/adguard."
    ;;
  tailscale)
    echo "Removing Tailscale cuts this server off your tailnet."
    echo "If you are connected over Tailscale SSH, run this from the console or another network."
    gum confirm "Continue removing Tailscale?" || exit 0
    sudo tailscale down 2>/dev/null || true
    sudo systemctl disable tailscaled 2>/dev/null || true
    sudo apt-get purge -y tailscale
    echo "Tailscale removed."
    ;;
  *)
    echo "devbox remove: unknown component '$app'" >&2
    echo "Try: adguard, tailscale" >&2
    exit 2
    ;;
esac
