#!/usr/bin/env bash
install_adguard() {
  log "Installing AdGuard Home via Docker Compose"
  command -v docker >/dev/null 2>&1 || {
    warn "Docker is required. Install it first with: ./install.sh --only docker"
    return 1
  }

  local compose_dir="$HOME/adguard"
  local compose_file="$compose_dir/docker-compose.yml"
  local project="devbox-adguard"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write $compose_file"
    echo "+ docker compose -f $compose_file up -d"
    return
  fi

  run mkdir -p "$compose_dir"

  cat > "$compose_file" <<'COMPOSE'
services:
  adguardhome:
    image: adguard/adguardhome:latest
    container_name: adguardhome
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "3000:3000/tcp"
    volumes:
      - ./work:/opt/adguardhome/work
      - ./conf:/opt/adguardhome/conf
COMPOSE

  run docker compose --project-name "$project" -f "$compose_file" up -d

  log "AdGuard Home is running"
  echo "Web admin:   http://localhost:3000 (first run) then http://localhost"
  echo "DNS server:  this host on UDP/TCP port 53"
  echo "Manage:      docker compose --project-name $project -f $compose_file up/down/logs"
  echo "Point your router or devices at this host's IP to start blocking ads."
  warn "AdGuard Home binds port 53 and 80 on this host. Ensure no other service already uses them."
}
