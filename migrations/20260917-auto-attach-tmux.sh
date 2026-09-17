#!/usr/bin/env bash
set -Eeuo pipefail

bashrc="$HOME/.bashrc"
[[ -f "$bashrc" ]] || exit 0

if grep -q 'DevBox leaves the shell tmux-free' "$bashrc"; then
  sed -i '/DevBox leaves the shell tmux-free/d' "$bashrc"
  sed -i '/Omadots alias: t/d' "$bashrc"
fi

if ! grep -q 'DEVBOX_NO_TMUX' "$bashrc"; then
  cat >> "$bashrc" <<'EOF'

if [[ -z ${TMUX:-} && -z ${DEVBOX_NO_TMUX:-} &&
      ${TERM:-dumb} != "dumb" && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1; then
  tmux attach 2>/dev/null || tmux new-session -s Work
fi
EOF
fi
