#!/usr/bin/env bash
set -Eeuo pipefail

config="$HOME/.config/shell/devbox-server"
[[ -f $config ]] || exit 0

if grep -q "^alias v=" "$config"; then
  sed -i '/^alias v=/d' "$config"
fi

if ! grep -q '^n()' "$config"; then
  cat >>"$config" <<'EOF'

n() {
  if (( $# == 0 )); then
    command nvim .
  else
    command nvim "$@"
  fi
}
EOF
fi
