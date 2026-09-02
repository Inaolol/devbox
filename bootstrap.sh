#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="${DEVBOX_REPOSITORY:-https://github.com/Inaolol/devbox.git}"
REF="${DEVBOX_REF:-master}"
TARGET="${DEVBOX_DIR:-$HOME/.local/share/devbox}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this installer as your normal user, not root. It uses sudo when needed." >&2
  exit 1
fi

# DEVBOX_DIR names where the checkout lives; refuse obviously unsafe values.
if [[ -z "$TARGET" || "$TARGET" == "/" ]]; then
  echo "Refusing to use unsafe install directory: '$TARGET' (check DEVBOX_DIR)" >&2
  exit 1
fi

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
elif [[ -d "$TARGET" && -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  # Updates must never destroy user state: a non-empty directory that is
  # not the devbox checkout belongs to something else.
  echo "Refusing to replace '$TARGET': it exists and is not a devbox checkout." >&2
  echo "Remove it or point DEVBOX_DIR elsewhere, then rerun." >&2
  exit 1
else
  git clone --depth 1 --branch "$REF" "$REPOSITORY" "$TARGET"
fi

exec "$TARGET/install.sh" "$@"
