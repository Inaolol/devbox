#!/usr/bin/env bash
install_configs() {
  log "Installing Omaterm-compatible shell, tmux, and LazyVim configuration"
  install_omadots
}

# Updates refresh only the config files that are safe to replace wholesale:
# tmux and starship, both sourced from fresh upstream Omadots. Everything else
# stays user-owned. Auth state lives outside these files (GitHub in
# ~/.config/gh, Tailscale in /var/lib/tailscale, SSH keys in ~/.ssh), and
# onboarding is never replayed, so authentication is
# never lost.
refresh_configs() {
  log "Refreshing managed tmux and starship configuration"
  local temp_dir

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ clone omadots and refresh only tmux.conf and starship.toml with timestamped backups"
    return
  fi

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  git clone --depth 1 https://github.com/omacom-io/omadots.git "$temp_dir/omadots"

  refresh_managed_file "$HOME/.config/tmux/tmux.conf" "$temp_dir/omadots/config/tmux/tmux.conf"
  refresh_managed_file "$HOME/.config/starship.toml" "$temp_dir/omadots/config/starship.toml"

  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"

  rm -rf "$temp_dir"
  trap - RETURN
}

refresh_managed_file() {
  local target="$1" source="$2" backup=""
  [[ -f "$source" ]] || return 0
  if [[ -e "$target" || -L "$target" ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    run mv "$target" "$backup"
    log "Backed up $target to $backup"
  fi
  mkdir -p "$(dirname "$target")"
  run install -m 0644 "$source" "$target"
  if [[ -n "$backup" ]] && ! cmp -s "$target" "$backup"; then
    log "Changes to $target:"
    diff -u "$backup" "$target" | sed 's/^/  /' || true
  fi
}

install_omadots() {
  local temp_dir git_name git_email op_token_line=""

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ clone https://github.com/omacom-io/omadots.git and install its authoritative shell, tmux, and LazyVim configs"
    echo "+ preserve existing configuration with timestamped backups"
    echo "+ install Debian/Ubuntu Omaterm aliases and safe interactive tmux startup"
    echo "+ install DevBox Neovim and lazygit tweaks"
    return
  fi

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  git clone --depth 1 https://github.com/omacom-io/omadots.git "$temp_dir/omadots"

  # Git may store global identity in ~/.config/git/config, which Omadots
  # replaces below. Keep the machine-specific identity across updates.
  git_name="$(git config --global --get user.name 2>/dev/null || true)"
  git_email="$(git config --global --get user.email 2>/dev/null || true)"

  # Preserve legacy user secrets when replacing the containing config file.
  if [[ -f "$HOME/.config/shell/envs" ]]; then
    op_token_line="$(grep '^export OP_SERVICE_ACCOUNT_TOKEN=' "$HOME/.config/shell/envs" || true)"
  fi

  if [[ -e "$HOME/.config/nvim" ]]; then
    backup_path "$HOME/.config/nvim"
  fi
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"

  local upstream_path target
  mkdir -p "$HOME/.config"
  for upstream_path in "$temp_dir"/omadots/config/*; do
    target="$HOME/.config/$(basename "$upstream_path")"
    # nvim was deliberately created from LazyVim/starter immediately above.
    if [[ "$(basename "$upstream_path")" != "nvim" && ( -e "$target" || -L "$target" ) ]]; then
      backup_path "$target"
    fi
    cp -rf "$upstream_path" "$HOME/.config/"
  done

  # Omadots stays authoritative. These only fill native-server gaps in the
  # Omaterm manual that are not currently present in shared Omadots aliases.
  install -m 0644 "$REPO_ROOT/configs/shell/devbox-server" \
    "$HOME/.config/shell/devbox-server"

  install_devbox_editor_configs

  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"

  backup_path "$HOME/.bashrc"
  backup_path "$HOME/.bash_profile"
  backup_path "$HOME/.inputrc"

  cat > "$HOME/.bashrc" <<'BASHRC'
# If not running interactively, do nothing.
[[ $- != *i* ]] && return

source ~/.config/shell/all
source ~/.config/shell/devbox-server

# Debian and Ubuntu package fzf shell integration lives in a different path
# from Arch's, which is the location checked by Omadots.
[[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash

# DevBox leaves the shell tmux-free. Start tmux yourself with the
# Omadots alias: t   (attach to Work or create it). Inside tmux, use tdl <ai>.
BASHRC
  echo '. ~/.bashrc' > "$HOME/.bash_profile"
  ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"

  if [[ -n "$git_name" ]]; then
    git config --file "$HOME/.gitconfig" user.name "$git_name"
  fi
  if [[ -n "$git_email" ]]; then
    git config --file "$HOME/.gitconfig" user.email "$git_email"
  fi

  if [[ -n "$op_token_line" ]]; then
    local envs_file="$HOME/.config/shell/envs"
    grep -q '^export OP_SERVICE_ACCOUNT_TOKEN=' "$envs_file" ||
      printf '%s\n' "$op_token_line" >>"$envs_file"
  fi

  rm -rf "$temp_dir"
  trap - RETURN
}

install_devbox_editor_configs() {
  local plugins_dir="$REPO_ROOT/configs/nvim/plugins"
  local plugin_file target

  mkdir -p "$HOME/.config/nvim/lua/plugins"
  for plugin_file in "$plugins_dir"/*.lua; do
    target="$HOME/.config/nvim/lua/plugins/$(basename "$plugin_file")"
    if [[ -e "$target" ]]; then
      backup_path "$target"
    fi
    install -m 0644 "$plugin_file" "$target"
  done

  target="$HOME/.config/lazygit/config.yml"
  if [[ -e "$target" ]]; then
    backup_path "$target"
  fi
  mkdir -p "$HOME/.config/lazygit"
  install -m 0644 "$REPO_ROOT/configs/lazygit/config.yml" "$target"
}
