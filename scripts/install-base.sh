#!/usr/bin/env bash
configure_ssh_keepalive() {
  local conf="/etc/ssh/ssh_config.d/20-devbox-keepalive.conf"
  [[ -e $conf ]] && return 0

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ write $conf"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  register_temp_dir "$tmp"
  cat >"$tmp" <<'EOF'
Host *
  ServerAliveInterval 15
  ServerAliveCountMax 3
  ConnectTimeout 10
EOF
  [[ -d /etc/ssh/ssh_config.d ]] || run_step "Creating SSH config directory" sudo install -d -m 0755 /etc/ssh/ssh_config.d
  run_step "Configuring SSH keepalive defaults" sudo install -o root -g root -m 0644 "$tmp" "$conf"
  rm -f "$tmp"
}

configure_ssh_command_path() {
  local pam_env="/etc/security/pam_env.conf"
  [[ -f $pam_env ]] || return 0
  if grep -qE '^PATH[[:space:]]' "$pam_env"; then
    return 0
  fi

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ configure PATH in $pam_env"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  register_temp_dir "$tmp"
  cat "$pam_env" >"$tmp"
  cat >>"$tmp" <<'EOF'

# DevBox: expose mise shims and ~/.local/bin to non-interactive SSH commands
PATH DEFAULT=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:@{HOME}/.local/share/mise/shims:@{HOME}/.local/bin
EOF
  run_step "Configuring PAM PATH for non-interactive SSH" sudo install -o root -g root -m 0644 "$tmp" "$pam_env"
  rm -f "$tmp"
}

install_base() {
  log "Installing base packages"
  install_apt_packages ca-certificates curl git gnupg unzip xz-utils rsync build-essential jq openssh-server
  run_step "Enabling OpenSSH service" sudo systemctl enable --now ssh
  configure_ssh_keepalive
  configure_ssh_command_path
}
