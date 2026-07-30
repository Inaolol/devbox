#!/usr/bin/env bash
install_docker() {
  log "Installing Docker Engine from Docker's official ${OS_ID} repository"
  run sudo install -m 0755 -d /etc/apt/keyrings

  local docker_base_url="https://download.docker.com/linux/${OS_ID}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ curl ${docker_base_url}/gpg to /etc/apt/keyrings/docker.asc"
  else
    curl -fsSL "${docker_base_url}/gpg" | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi

  local arch
  arch="$(dpkg --print-architecture)"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write Docker apt repository for ${OS_ID} ${arch} ${OS_CODENAME}"
  else
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] ${docker_base_url} ${OS_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  run sudo apt-get update
  install_apt_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run sudo systemctl enable --now docker
  if ! id -nG "$USER" | grep -qw docker; then run sudo usermod -aG docker "$USER"; fi
}
