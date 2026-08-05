#!/usr/bin/env bash
set -Eeuo pipefail

if (($# > 0)); then
  "$DEVBOX_PATH/scripts/devbox-db" "$@"
else
  "$DEVBOX_PATH/scripts/devbox-db"
fi
