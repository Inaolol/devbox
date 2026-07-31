#!/usr/bin/env bash
set -Eeuo pipefail

config="$HOME/.config/shell/devbox-server"
# shellcheck disable=SC2016
locale_line='export LANG="${LANG:-C.UTF-8}"'

[[ -f "$config" ]] || exit 0
grep -qxF "$locale_line" "$config" || printf '%s\n' "$locale_line" >>"$config"
