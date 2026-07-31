#!/usr/bin/env bash

run_migrations() {
  local migration name
  local migration_dir="$REPO_ROOT/migrations"
  local state_dir="$HOME/.local/state/devbox/migrations"
  local -a migrations=()

  [[ -d "$migration_dir" ]] || return
  mkdir -p "$state_dir"

  shopt -s nullglob
  migrations=("$migration_dir"/*.sh)
  shopt -u nullglob

  for migration in "${migrations[@]}"; do
    name="$(basename "$migration")"
    [[ -e "$state_dir/$name" ]] && continue
    log "Running migration ${name%.sh}"
    bash "$migration"
    touch "$state_dir/$name"
  done
}
