#!/usr/bin/env bash
set -Eeuo pipefail

exec "$DEVBOX_PATH/scripts/devbox-db" "$@"
