#!/usr/bin/env bash
set -Eeuo pipefail

config="$HOME/.config/shell/devbox-server"
[[ -f $config ]] || exit 0

if ! grep -q "alias lta=" "$config"; then
  cat >>"$config" <<'EOF'

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi
EOF
fi

if ! grep -q "alias cd='zd'" "$config"; then
  cat >>"$config" <<'EOF'

if command -v zoxide >/dev/null 2>&1; then
  alias cd='zd'
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf '\U000F17A9 '
      pwd
    fi
  }
fi
EOF
fi

ensure_alias() {
  local name="$1" line="$2"
  grep -q "^alias ${name}=" "$config" || printf '%s\n' "$line" >>"$config"
}

ensure_alias mup "alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'"
ensure_alias agy "alias agy='agy --dangerously-skip-permissions'"
ensure_alias c "alias c='opencode --auto'"
ensure_alias cy "alias cy='codex --approve-for-me'"
