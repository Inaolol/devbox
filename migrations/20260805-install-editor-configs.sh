#!/usr/bin/env bash
set -Eeuo pipefail

# Bring the Neovim QoL plugins and lazygit config to installs that predate
# them. Configs are only installed on first setup, so an update would
# otherwise never deliver these. Never overwrites user files.
plugins_dir="$REPO_ROOT/configs/nvim/plugins"
lazygit_config="$REPO_ROOT/configs/lazygit/config.yml"

mkdir -p "$HOME/.config/nvim/lua/plugins"
for file in colorscheme.lua disable-news-alert.lua snacks-animated-scrolling.lua; do
  [[ -e "$HOME/.config/nvim/lua/plugins/$file" ]] || cp "$plugins_dir/$file" "$HOME/.config/nvim/lua/plugins/$file"
done

if [[ ! -e "$HOME/.config/lazygit/config.yml" ]]; then
  mkdir -p "$HOME/.config/lazygit"
  cp "$lazygit_config" "$HOME/.config/lazygit/config.yml"
fi
