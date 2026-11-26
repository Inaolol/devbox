#!/usr/bin/env bash
setup_docker_apt_repo() {
  local docker_base_url="https://download.docker.com/linux/${OS_ID}"
  ensure_apt_keyring \
    "Adding Docker APT keyring" \
    "${docker_base_url}/gpg" \
    /etc/apt/keyrings/docker.asc
  ensure_apt_source \
    "Adding Docker APT repository" \
    /etc/apt/sources.list.d/docker.list \
    "deb [arch=${OS_ARCHITECTURE} signed-by=/etc/apt/keyrings/docker.asc] ${docker_base_url} ${OS_CODENAME} stable"
}

configure_docker_daemon() {
  local daemon_json="/etc/docker/daemon.json"
  [[ -e $daemon_json ]] && return 0

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ write $daemon_json (log rotation: 10m x 5)"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  register_temp_dir "$tmp"
  cat >"$tmp" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
EOF
  [[ -d /etc/docker ]] || run_step "Creating Docker config directory" sudo install -d -m 0755 /etc/docker
  run_step "Configuring Docker log rotation" sudo install -o root -g root -m 0644 "$tmp" "$daemon_json"
  rm -f "$tmp"
}

install_docker() {
  log "Installing Docker Engine from Docker's official ${OS_ID} repository"
  remove_conflicting_docker_packages
  if (( ${APT_REPOS_PREPARED:-0} == 0 )); then
    setup_docker_apt_repo
  fi

  install_apt_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  configure_docker_daemon
  run_step "Enabling Docker service" sudo systemctl enable --now docker
  if ! id -nG "$USER" | grep -qw docker; then
    run_step "Adding $USER to docker group" sudo usermod -aG docker "$USER"
  fi
  warn "Docker-published ports bypass UFW rules. Restrict them with firewall rules in the DOCKER-USER chain."
}

remove_conflicting_docker_packages() {
  local package
  local -a installed_conflicts=()
  local -a conflicts=(docker.io docker-compose docker-doc podman-docker containerd runc)

  for package in "${conflicts[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii '; then
      installed_conflicts+=("$package")
    fi
  done

  if (( ${#installed_conflicts[@]} > 0 )); then
    log "Removing packages that conflict with Docker CE: ${installed_conflicts[*]}"
    run_step "Removing conflicting Docker packages" sudo apt-get remove -y "${installed_conflicts[@]}"
  fi
}
