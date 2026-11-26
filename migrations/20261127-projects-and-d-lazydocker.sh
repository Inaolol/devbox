#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p "$HOME/projects"

config="$HOME/.config/shell/devbox-server"
[[ -f $config ]] || exit 0
grep -q "^alias d=" "$config" || printf "alias d='lazydocker'\n" >>"$config"
