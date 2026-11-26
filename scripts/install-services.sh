#!/usr/bin/env bash

install_services() {
  log "Installing DevBox CLI and service onboarding"

  local target_dir="$HOME/.local/bin"
  run mkdir -p "$target_dir"
  run install -m 0755 "$REPO_ROOT/scripts/devbox-setup" "$target_dir/devbox-setup"

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ write the devbox CLI wrapper and install devbox-setup"
    return
  fi

  {
    printf '#!/usr/bin/env bash\n'
    printf 'export DEVBOX_PATH=%q\n' "$REPO_ROOT"
    printf 'exec "$DEVBOX_PATH/bin/devbox" "$@"\n'
  } >"$target_dir/devbox"
  chmod 0755 "$target_dir/devbox"
  log "Installed the devbox CLI. Run 'devbox' to manage onboarding and updates."

  # Onboarding is first-install work. Updates refresh this helper without
  # replaying credentials or changing service enrollment.
  if (( ${DEVBOX_UPDATE:-0} == 0 )) && [[ -n ${DEVBOX_SETUP_GIT_NAME:-} || -n ${DEVBOX_SETUP_GIT_EMAIL:-} ]]; then
    if [[ -n ${DEVBOX_SETUP_GIT_NAME:-} && -n ${DEVBOX_SETUP_GIT_EMAIL:-} ]]; then
      "$target_dir/devbox-setup" git \
        --name "$DEVBOX_SETUP_GIT_NAME" --email "$DEVBOX_SETUP_GIT_EMAIL"
    else
      warn "Set both DEVBOX_SETUP_GIT_NAME and DEVBOX_SETUP_GIT_EMAIL; Git setup skipped."
    fi
  fi

  if (( ${DEVBOX_UPDATE:-0} == 0 )) && [[ -n ${DEVBOX_SETUP_GH_TOKEN:-} ]]; then
    printf '%s\n' "$DEVBOX_SETUP_GH_TOKEN" |
      "$target_dir/devbox-setup" github --with-token
  fi

  if (( ${DEVBOX_UPDATE:-0} == 0 )) && [[ -n ${DEVBOX_SETUP_TS_AUTH_KEY:-} ]]; then
    printf '%s\n' "$DEVBOX_SETUP_TS_AUTH_KEY" |
      "$target_dir/devbox-setup" tailscale \
        --hostname "${DEVBOX_SETUP_TS_HOST:-$(hostname -s)}" \
        --auth-key-stdin
  fi

  if (( ${DEVBOX_UPDATE:-0} == 0 )) && [[ -n ${DEVBOX_SETUP_SSH_KEY:-} ]]; then
    "$target_dir/devbox-setup" ssh --key "$DEVBOX_SETUP_SSH_KEY"
  fi

  # Secrets must not linger in the installer's environment, where every
  # child process (apt, curl, docker) could inherit them.
  unset DEVBOX_SETUP_GIT_NAME DEVBOX_SETUP_GIT_EMAIL \
    DEVBOX_SETUP_GH_TOKEN DEVBOX_SETUP_TS_AUTH_KEY DEVBOX_SETUP_TS_HOST \
    DEVBOX_SETUP_SSH_KEY

  log "Run 'devbox-setup' from a terminal to connect GitHub, Tailscale, and SSH."
  warn "Password SSH remains enabled unless you explicitly run: devbox-setup ssh --key 'PUBLIC_KEY' --disable-password-auth"
}
