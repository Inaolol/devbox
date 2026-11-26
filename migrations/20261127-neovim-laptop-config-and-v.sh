#!/usr/bin/env bash
set -Eeuo pipefail

config="$HOME/.config/shell/devbox-server"
if [[ -f $config ]]; then
  if grep -q "^alias v='vim'$" "$config"; then
    sed -i "s|^alias v='vim'$|alias v='nvim'|" "$config"
  elif ! grep -q "^alias v=" "$config"; then
    printf "alias v='nvim'\n" >>"$config"
  fi

  if grep -q "^alias d=" "$config"; then
    sed -i "s|^alias d=.*$|alias d='lazydocker'|" "$config"
  else
    printf "alias d='lazydocker'\n" >>"$config"
  fi
fi

install_with_backup() {
  local src="$1" dst="$2"
  [[ -f $src ]] || return 0
  mkdir -p "$(dirname "$dst")"
  if [[ -e $dst ]] && ! cmp -s "$src" "$dst"; then
    mv "$dst" "${dst}.backup.$(date +%Y%m%d%H%M%S)"
  fi
  install -m 0644 "$src" "$dst"
}

if [[ -d $HOME/.config/nvim ]]; then
  install_with_backup "$REPO_ROOT/configs/nvim/plugins/colorscheme.lua" "$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  install_with_backup "$REPO_ROOT/configs/nvim/plugins/lualine-transparent.lua" "$HOME/.config/nvim/lua/plugins/lualine-transparent.lua"
  install_with_backup "$REPO_ROOT/configs/nvim/config/options.lua" "$HOME/.config/nvim/lua/config/options.lua"
  install_with_backup "$REPO_ROOT/configs/nvim/config/remote_clipboard.lua" "$HOME/.config/nvim/lua/config/remote_clipboard.lua"
  install_with_backup "$REPO_ROOT/configs/nvim/plugin/after/transparency.lua" "$HOME/.config/nvim/plugin/after/transparency.lua"
fi
