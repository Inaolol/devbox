#!/usr/bin/env bash
repair_1password_apt_key() {
  [[ -f /etc/apt/sources.list.d/1password.list ]] || return 0

  log "Refreshing 1Password apt signing key"
  run sudo mkdir -p -m 755 /etc/apt/keyrings
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ refresh 1Password apt key"
  else
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo tee /etc/apt/keyrings/1password.asc >/dev/null
    sudo chmod a+r /etc/apt/keyrings/1password.asc
  fi
}

install_1password() {
  log "Installing 1Password CLI"
  command -v op >/dev/null 2>&1 && {
    log "1Password CLI is already installed"
    return
  }

  run sudo mkdir -p -m 755 /etc/apt/keyrings
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ add 1Password apt key and repository"
  else
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --dearmor --yes -o /etc/apt/keyrings/1password.asc
    sudo chmod a+r /etc/apt/keyrings/1password.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password.asc] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
      sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  fi

  run sudo apt-get update
  install_apt_packages 1password-cli
  warn "Authenticate with: devbox-setup 1password (see docs/1password.md)"
}
