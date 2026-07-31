#!/usr/bin/env bash

install_services() {
  log "Installing Omaterm-style service onboarding"
  install_apt_packages gh

  local target_dir="$HOME/.local/bin"
  run mkdir -p "$target_dir"
  run install -m 0755 "$REPO_ROOT/scripts/devbox-setup" "$target_dir/devbox-setup"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ install the devbox-setup onboarding helper"
    return
  fi

  # Onboarding is first-install work. Updates refresh this helper without
  # replaying credentials or changing service enrollment.
  if [[ "${DEVBOX_UPDATE:-0}" -eq 0 && ( -n "${DEVBOX_SETUP_GIT_NAME:-}" || -n "${DEVBOX_SETUP_GIT_EMAIL:-}" ) ]]; then
    if [[ -n "${DEVBOX_SETUP_GIT_NAME:-}" && -n "${DEVBOX_SETUP_GIT_EMAIL:-}" ]]; then
      "$target_dir/devbox-setup" git \
        --name "$DEVBOX_SETUP_GIT_NAME" --email "$DEVBOX_SETUP_GIT_EMAIL"
    else
      warn "Set both DEVBOX_SETUP_GIT_NAME and DEVBOX_SETUP_GIT_EMAIL; Git setup skipped."
    fi
  fi

  if [[ "${DEVBOX_UPDATE:-0}" -eq 0 && -n "${DEVBOX_SETUP_GH_TOKEN:-}" ]]; then
    printf '%s' "$DEVBOX_SETUP_GH_TOKEN" |
      "$target_dir/devbox-setup" github --with-token
  fi

  if [[ "${DEVBOX_UPDATE:-0}" -eq 0 && -n "${DEVBOX_SETUP_TS_AUTH_KEY:-}" ]]; then
    "$target_dir/devbox-setup" tailscale \
      --hostname "${DEVBOX_SETUP_TS_HOST:-$(hostname -s)}" \
      --auth-key "$DEVBOX_SETUP_TS_AUTH_KEY"
  fi

  if [[ "${DEVBOX_UPDATE:-0}" -eq 0 && -n "${DEVBOX_SETUP_SSH_KEY:-}" ]]; then
    "$target_dir/devbox-setup" ssh --key "$DEVBOX_SETUP_SSH_KEY"
  fi

  log "Run 'devbox-setup' from a terminal to connect GitHub, Tailscale, and SSH."
  warn "Password SSH remains enabled unless you explicitly run: devbox-setup ssh --key 'PUBLIC_KEY' --disable-password-auth"
}
