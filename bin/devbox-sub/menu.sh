#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  devbox                  Open the interactive menu
  devbox setup [args]     Run onboarding (devbox-setup)
  devbox install [app]    Install tailscale or all
  devbox remove [app]     Remove tailscale
  devbox update           Fetch the latest DevBox and update everything
  devbox help             Explain what each command does and needs from you
USAGE
}

run_sub() {
  local sub="$1" rc
  shift

  case "$sub" in
    setup|install|remove|update|help|-h|--help) ;;
    *) echo "devbox: unknown command '$sub'" >&2; usage >&2; exit 2 ;;
  esac

  [[ $sub == "-h" || $sub == "--help" ]] && sub="help"
  if "$DEVBOX_PATH/bin/devbox-sub/$sub.sh" "$@"; then
    rc=0
  else
    rc=$?
  fi
  if (( rc != 0 )); then
    echo "devbox: '$sub' exited with an error (code $rc)" >&2
  fi
  return "$rc"
}

if (( $# > 0 )); then
  run_sub "$1" "${@:2}"
  exit $?
fi

command -v gum >/dev/null 2>&1 || {
  echo "The devbox menu needs gum. Use a direct command instead: devbox help" >&2
  exit 1
}

while :; do
  clear
  # shellcheck source=bin/devbox-sub/header.sh
  source "$DEVBOX_PATH/bin/devbox-sub/header.sh"
  choice="$(gum choose "Setup" "Install" "Remove" "Update" "Help" "Quit" \
    --height 8 --header "DevBox")" || exit 0
  [[ -n $choice ]] || exit 0
  sub="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"
  [[ $sub == "quit" ]] && exit 0
  if run_sub "$sub"; then
    rc=0
  else
    rc=$?
  fi
  [[ $sub == "help" ]] && exit 0
  if (( rc != 0 )); then
    echo
    echo "devbox: press Enter to return to the menu"
    read -r
  fi
done
