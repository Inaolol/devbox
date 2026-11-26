#!/usr/bin/env bash
# Pinned upstream revisions. Omadots shell files are sourced by every login
# shell, so upstream changes must land deliberately: bump the SHA, review the
# diff, commit. Get the current HEAD with:
#   git ls-remote https://github.com/omacom-io/omadots.git HEAD
OMADOTS_REF="556354683664f4143776296d76df75c0fa29059a"
LAZYVIM_STARTER_REF="803bc181d7c0d6d5eeba9274d9be49b287294d99"

clone_pinned() {
  local repo="$1" ref="$2" target="$3"
  mkdir -p "$target"
  git -C "$target" init -q
  git -C "$target" remote add origin "$repo"
  git -C "$target" fetch --depth 1 --quiet origin "$ref"
  git -C "$target" checkout --quiet --force FETCH_HEAD
  if [[ $(git -C "$target" rev-parse HEAD) != "$ref" ]]; then
    echo "Pinned checkout mismatch for $repo: expected $ref, got $(git -C "$target" rev-parse HEAD)" >&2
    return 1
  fi
}

# Updates refresh only the config files that are safe to replace wholesale:
# tmux from pinned upstream Omadots, plus DevBox's Omarchy-style starship and
# herdr configs. Everything else stays user-owned. Auth state lives outside
# these files (GitHub in ~/.config/gh, Tailscale in /var/lib/tailscale, SSH
# keys in ~/.ssh), and onboarding is never replayed, so auth is never lost.
refresh_configs() {
  log "Refreshing managed herdr, tmux, and starship configuration"
  local temp_dir base_url

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ refresh tmux.conf, starship.toml, and herdr/config.toml with timestamped backups"
    return
  fi

  temp_dir="$(mktemp -d)"
  register_temp_dir "$temp_dir"
  base_url="https://raw.githubusercontent.com/omacom-io/omadots/${OMADOTS_REF}/config"

  run_step "Downloading pinned tmux.conf" \
    curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --max-time 30 \
    "${base_url}/tmux/tmux.conf" -o "$temp_dir/tmux.conf"

  refresh_managed_file "$HOME/.config/tmux/tmux.conf" "$temp_dir/tmux.conf"
  refresh_managed_file "$HOME/.config/starship.toml" "$REPO_ROOT/configs/starship.toml"
  refresh_managed_file "$HOME/.config/herdr/config.toml" "$REPO_ROOT/configs/herdr/config.toml"

  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
  rm -rf "$temp_dir"
}

refresh_managed_file() {
  local target="$1" source="$2" backup=""
  [[ -f $source ]] || return 0
  if [[ -e $target || -L $target ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    run mv "$target" "$backup"
    log "Backed up $target to $backup"
  fi
  mkdir -p "$(dirname "$target")"
  run install -m 0644 "$source" "$target"
  if [[ -n $backup ]] && ! cmp -s "$target" "$backup"; then
    log "Changes to $target:"
    diff -u "$backup" "$target" | sed 's/^/  /' || true
  fi
}

install_configs() {
  log "Installing Omarchy-style shell, herdr, tmux, and LazyVim configuration"
  local temp_dir git_name git_email

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ clone https://github.com/omacom-io/omadots.git and install its authoritative shell, tmux, and LazyVim configs"
    echo "+ install Omarchy-matched herdr/config.toml, starship.toml, and delta git pager"
    echo "+ preserve existing configuration with timestamped backups"
    echo "+ install Debian/Ubuntu Omaterm aliases and safe interactive herdr/tmux startup"
    echo "+ install DevBox Neovim and lazygit tweaks"
    return
  fi

  temp_dir="$(mktemp -d)"
  register_temp_dir "$temp_dir"
  run_step "Fetching pinned Omadots configuration" \
    clone_pinned https://github.com/omacom-io/omadots.git "$OMADOTS_REF" "$temp_dir/omadots"

  # Git may store global identity in ~/.config/git/config, which Omadots
  # replaces below. Keep the machine-specific identity across updates.
  git_name="$(git config --global --get user.name 2>/dev/null || true)"
  git_email="$(git config --global --get user.email 2>/dev/null || true)"

  if [[ -e $HOME/.config/nvim ]]; then
    backup_path "$HOME/.config/nvim"
  fi
  run_step "Fetching pinned LazyVim starter" \
    clone_pinned https://github.com/LazyVim/starter.git "$LAZYVIM_STARTER_REF" "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"

  local upstream_path target
  # install-terminal and install-ai write [tools] into ~/.config/mise/config.toml.
  # Omadots' copy would drop that section, so carry it over into the fresh config.toml.
  local mise_tools=""
  if [[ -f $HOME/.config/mise/config.toml ]]; then
    mise_tools="$(awk '
      /^\[tools\]/ { p=1 }
      /^\[/ && $0 != "[tools]" && p { exit }
      p
    ' "$HOME/.config/mise/config.toml")"
  fi

  mkdir -p "$HOME/.config"
  for upstream_path in "$temp_dir"/omadots/config/*; do
    target="$HOME/.config/$(basename "$upstream_path")"
    # nvim was deliberately created from LazyVim/starter immediately above.
    if [[ $(basename "$upstream_path") != "nvim" && ( -e $target || -L $target ) ]]; then
      backup_path "$target"
    fi
    cp -rf "$upstream_path" "$HOME/.config/"
  done

  # Omadots stays authoritative for shell init; DevBox overrides Starship and
  # Herdr to match Omarchy's prompt and tmux-keybound workspace defaults.
  install -m 0644 "$REPO_ROOT/configs/starship.toml" "$HOME/.config/starship.toml"
  mkdir -p "$HOME/.config/herdr"
  if [[ -e $HOME/.config/herdr/config.toml ]]; then
    backup_path "$HOME/.config/herdr/config.toml"
  fi
  install -m 0644 "$REPO_ROOT/configs/herdr/config.toml" "$HOME/.config/herdr/config.toml"

  install -m 0644 "$REPO_ROOT/configs/shell/devbox-server" \
    "$HOME/.config/shell/devbox-server"

  install_devbox_editor_configs

  if [[ -n $mise_tools ]]; then
    mkdir -p "$HOME/.config/mise"
    if [[ ! -f $HOME/.config/mise/config.toml ]] || ! grep -q '^\[tools\]' "$HOME/.config/mise/config.toml"; then
      printf '\n%s\n' "$mise_tools" >>"$HOME/.config/mise/config.toml"
    fi
  fi

  ln -snf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"

  backup_path "$HOME/.bashrc"
  backup_path "$HOME/.bash_profile"
  backup_path "$HOME/.inputrc"

  cat >"$HOME/.bashrc" <<'BASHRC'
# If not running interactively, do nothing.
[[ $- != *i* ]] && return

source ~/.config/shell/all
source ~/.config/shell/devbox-server

# Debian and Ubuntu package fzf shell integration lives in a different path
# from Arch's, which is the location checked by Omadots.
[[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash

if [[ -z ${HERDR_ENV:-} && -z ${TMUX:-} && -z ${DEVBOX_NO_MULTIPLEXER:-} &&
      -z ${DEVBOX_NO_TMUX:-} && ${TERM:-dumb} != "dumb" && -t 0 && -t 1 &&
      -r $HOME/.config/devbox/startup ]]; then
  IFS= read -r _devbox_startup <"$HOME/.config/devbox/startup" || true
  case "$_devbox_startup" in
    herdr)
      [[ -z ${DEVBOX_NO_HERDR:-} ]] && command -v herdr >/dev/null 2>&1 && herdr
      ;;
    tmux)
      command -v tmux >/dev/null 2>&1 && { tmux attach 2>/dev/null || tmux new-session -s Work; }
      ;;
  esac
  unset _devbox_startup
fi
BASHRC
  echo '. ~/.bashrc' >"$HOME/.bash_profile"
  ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"

  if [[ -n $git_name ]]; then
    git config --file "$HOME/.gitconfig" user.name "$git_name"
  fi
  if [[ -n $git_email ]]; then
    git config --file "$HOME/.gitconfig" user.email "$git_email"
  fi

  if [[ -z $(git config --file "$HOME/.gitconfig" --get core.pager 2>/dev/null || true) ]]; then
    git config --file "$HOME/.gitconfig" core.pager delta
    git config --file "$HOME/.gitconfig" interactive.diffFilter "delta --color-only"
    git config --file "$HOME/.gitconfig" delta.navigate true
    git config --file "$HOME/.gitconfig" merge.conflictStyle zdiff3
  fi

  rm -rf "$temp_dir"
}

install_devbox_editor_configs() {
  local plugins_dir="$REPO_ROOT/configs/nvim/plugins"
  local plugin_file target

  mkdir -p "$HOME/.config/nvim/lua/plugins"
  for plugin_file in "$plugins_dir"/*.lua; do
    target="$HOME/.config/nvim/lua/plugins/$(basename "$plugin_file")"
    if [[ -e $target ]]; then
      backup_path "$target"
    fi
    install -m 0644 "$plugin_file" "$target"
  done

  target="$HOME/.config/lazygit/config.yml"
  if [[ -e $target ]]; then
    backup_path "$target"
  fi
  mkdir -p "$HOME/.config/lazygit"
  install -m 0644 "$REPO_ROOT/configs/lazygit/config.yml" "$target"
}
