#!/usr/bin/env bash
install_configs() {
  log "Installing Omaterm-compatible shell, tmux, and LazyVim configuration"
  install_omadots
}

install_omadots() {
  local temp_dir

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ clone https://github.com/omacom-io/omadots.git and install its authoritative shell, tmux, and LazyVim configs"
    echo "+ preserve existing configuration with timestamped backups"
    echo "+ install Debian/Ubuntu Omaterm aliases and safe interactive tmux startup"
    return
  fi

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  git clone --depth 1 https://github.com/omacom-io/omadots.git "$temp_dir/omadots"

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

# Omaterm starts tmux for terminal connections. These checks keep SSH commands,
# scp/sftp, cron, and nested tmux shells unaffected. Set DEVBOX_NO_TMUX=1 to opt out.
if [[ -z ${TMUX:-} && -z ${DEVBOX_NO_TMUX:-} &&
      ${TERM:-dumb} != dumb && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1; then
  tmux attach 2>/dev/null || tmux new-session -s Work
fi
BASHRC
  echo '. ~/.bashrc' > "$HOME/.bash_profile"
  ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"

  rm -rf "$temp_dir"
  trap - RETURN
}
