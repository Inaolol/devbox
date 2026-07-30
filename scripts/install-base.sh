#!/usr/bin/env bash
install_base() {
  log "Installing base packages"
  run sudo apt-get update
  install_apt_packages ca-certificates curl git gnupg unzip build-essential jq software-properties-common openssh-server ufw
  run sudo systemctl enable --now ssh
}
