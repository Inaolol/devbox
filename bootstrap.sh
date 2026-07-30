#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="${DEVBOX_REPOSITORY:-https://github.com/Inaolol/devbox.git}"
REF="${DEVBOX_REF:-master}"
TARGET="${DEVBOX_DIR:-$HOME/.local/share/devbox}"

command -v git >/dev/null 2>&1 || {
  command -v sudo >/dev/null 2>&1 || {
    echo "Git and sudo are required. Install sudo and grant this user sudo access, then rerun." >&2
    exit 1
  }
  sudo apt-get update
  sudo apt-get install -y git
}

if [[ -d "$TARGET/.git" ]]; then
  git -C "$TARGET" fetch --depth 1 origin "$REF"
  git -C "$TARGET" checkout --force FETCH_HEAD
else
  rm -rf "$TARGET"
  git clone --depth 1 --branch "$REF" "$REPOSITORY" "$TARGET"
fi

exec "$TARGET/install.sh" "$@"
