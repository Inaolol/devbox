#!/usr/bin/env bash
install_tailscale() {
  log "Installing Tailscale"
  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale is already installed"
    return
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ curl Tailscale installer and execute it"
  else
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  warn "Run 'sudo tailscale up' after installation to authenticate this server."
}
