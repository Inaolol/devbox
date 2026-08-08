#!/usr/bin/env bash
set -Eeuo pipefail

app="${1:-}"

if [[ -z "$app" ]]; then
  choice="$(gum choose \
    "AdGuard Home   DNS ad blocker in Docker" \
    "Tailscale      Mesh VPN / private tailnet" \
    "> All          Re-run every default installer" \
    "<< Back        " \
    --height 7 --header "Install optional components")" || exit 0

  case "$choice" in
    ""|"<< Back"*) exit 0 ;;
    "> All"*) app="all" ;;
    "AdGuard Home"*) app="adguard" ;;
    "Tailscale"*) app="tailscale" ;;
  esac
fi

case "$app" in
  adguard)
    "$DEVBOX_PATH/install.sh" --only adguard
    ;;
  tailscale)
    "$DEVBOX_PATH/install.sh" --only tailscale
    ;;
  all)
    "$DEVBOX_PATH/install.sh"
    ;;
  *)
    echo "devbox install: unknown component '$app'" >&2
    echo "Try: adguard, tailscale, all" >&2
    exit 2
    ;;
esac
