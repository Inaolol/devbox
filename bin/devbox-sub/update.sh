#!/usr/bin/env bash
set -Eeuo pipefail

gum confirm "Fetch the latest DevBox from GitHub and update all managed packages?" || exit 0
exec "$DEVBOX_PATH/bootstrap.sh"
