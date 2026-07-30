#!/usr/bin/env bash
install_configs() {
  log "Installing Omaterm-compatible shell, tmux, and LazyVim configuration"
  mkdir -p "$HOME/.config/tmux"

  install_managed_file "$REPO_ROOT/configs/tmux.conf" "$HOME/.config/tmux/tmux.conf"
  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"

  install_omadots

  local marker_start='# >>> devbox >>>'
  if ! grep -Fq "$marker_start" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'BASHRC'

# >>> devbox >>>
export PATH="$HOME/.local/bin:$PATH"
alias dc='docker compose'
# <<< devbox <<<
BASHRC
  fi
}

install_omadots() {
  local temp_dir
  temp_dir="$(mktemp -d)"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ clone https://github.com/omacom-io/omadots.git and install its shell/LazyVim configs"
    return
  fi

  git clone --depth 1 https://github.com/omacom-io/omadots.git "$temp_dir/omadots"

  if [[ -e "$HOME/.config/nvim" ]]; then
    backup_path "$HOME/.config/nvim"
  fi
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"

  mkdir -p "$HOME/.config"
  cp -rf "$temp_dir/omadots/config/." "$HOME/.config/"

  # Keep this repository's reviewed tmux file authoritative while matching upstream.
  install -m 0644 "$REPO_ROOT/configs/tmux.conf" "$HOME/.config/tmux/tmux.conf"
  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"

  cat > "$HOME/.bashrc" <<'BASHRC'
# If not running interactively, do nothing.
[[ $- != *i* ]] && return

source ~/.config/shell/all

# DevBox additions
export PATH="$HOME/.local/bin:$PATH"
alias dc='docker compose'
BASHRC
  echo '. ~/.bashrc' > "$HOME/.bash_profile"
  ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"

  rm -rf "$temp_dir"
}

install_managed_file() {
  local source="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" ]] && ! cmp -s "$source" "$target"; then backup_path "$target"; fi
  run install -m 0644 "$source" "$target"
}
