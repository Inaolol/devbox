#!/usr/bin/env bash
set -Eeuo pipefail

command -v devbox-setup >/dev/null 2>&1 || {
  echo "devbox-setup is not installed. Run the full DevBox installer first." >&2
  exit 1
}

echo "DevBox service onboarding — connects Git, GitHub, Tailscale, SSH, and 1Password."
echo "Each step is optional; press Ctrl+C or answer no to skip the rest."
echo
devbox-setup
