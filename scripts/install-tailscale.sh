#!/usr/bin/env bash
setup_tailscale_apt_repo() {
  local base_url="https://pkgs.tailscale.com/stable/${OS_ID}"
  ensure_apt_keyring \
    "Adding Tailscale APT keyring" \
    "${base_url}/${OS_CODENAME}.noarmor.gpg" \
    /usr/share/keyrings/tailscale-archive-keyring.gpg
  ensure_apt_source \
    "Adding Tailscale APT repository" \
    /etc/apt/sources.list.d/tailscale.list \
    "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] ${base_url} ${OS_CODENAME} main"
}

install_tailscale() {
  log "Installing Tailscale"
  if (( ${APT_REPOS_PREPARED:-0} == 0 )); then
    setup_tailscale_apt_repo
  fi
  install_apt_packages tailscale
  if (( ${DRY_RUN:-0} == 0 )) && ! tailscale ip -4 >/dev/null 2>&1; then
    warn "Run 'sudo tailscale up' after installation to authenticate this server."
  fi
}
