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

confirm_action "Fetch the latest DevBox from GitHub and update all managed packages?" || exit 0
exec "$DEVBOX_PATH/bootstrap.sh"
