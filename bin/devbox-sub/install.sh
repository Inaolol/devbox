#!/usr/bin/env bash
set -Eeuo pipefail

app="${1:-}"

if [[ -z $app ]]; then
  choice="$(gum choose \
    "Tailscale      Mesh VPN / private tailnet" \
    "> All          Re-run every default installer" \
    "<< Back        " \
    --height 6 --header "Install components")" || exit 0

  case "$choice" in
    ""|"<< Back"*) exit 0 ;;
    "> All"*) app="all" ;;
    "Tailscale"*) app="tailscale" ;;
  esac
fi

case "$app" in
  tailscale)
    "$DEVBOX_PATH/install.sh" --only tailscale
    ;;
  all)
    "$DEVBOX_PATH/install.sh"
    ;;
  *)
    echo "devbox install: unknown component '$app'" >&2
    echo "Try: tailscale, all" >&2
    exit 2
    ;;
esac
