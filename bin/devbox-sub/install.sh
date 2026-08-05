#!/usr/bin/env bash
set -Eeuo pipefail

app="${1:-}"

if [[ -z "$app" ]]; then
  choice="$(gum choose \
    "AdGuard Home   DNS ad blocker in Docker" \
    "Tailscale      Mesh VPN / private tailnet" \
    "1Password CLI  Secret storage and setup seeding" \
    "> All          Re-run every default installer" \
    "<< Back        " \
    --height 8 --header "Install optional components")" || exit 0

  case "$choice" in
    ""|"<< Back"*) exit 0 ;;
    "> All"*) app="all" ;;
    "AdGuard Home"*) app="adguard" ;;
    "Tailscale"*) app="tailscale" ;;
    "1Password CLI"*) app="1password" ;;
  esac
fi

case "$app" in
  adguard)
    "$DEVBOX_PATH/install.sh" --only adguard
    ;;
  tailscale)
    "$DEVBOX_PATH/install.sh" --only tailscale
    ;;
  1password|1password-cli|op)
    "$DEVBOX_PATH/install.sh" --only 1password
    ;;
  all)
    "$DEVBOX_PATH/install.sh"
    ;;
  *)
    echo "devbox install: unknown component '$app'" >&2
    echo "Try: adguard, tailscale, 1password, all" >&2
    exit 2
    ;;
esac
