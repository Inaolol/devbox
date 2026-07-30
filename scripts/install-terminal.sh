#!/usr/bin/env bash
install_terminal() {
  log "Installing terminal and development tools"
  install_apt_packages tmux ripgrep fd-find fzf bash-completion

  mkdir -p "$HOME/.local/bin"
  install_neovim

  if [[ ! -e "$HOME/.local/bin/fd" ]] && command -v fdfind >/dev/null 2>&1; then
    run ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  if ! command -v starship >/dev/null 2>&1; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then echo "+ install Starship"; else curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; fi
  fi

  if ! command -v zoxide >/dev/null 2>&1; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then echo "+ install zoxide"; else curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; fi
  fi

  if ! command -v mise >/dev/null 2>&1; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then echo "+ install mise"; else curl https://mise.run | sh; fi
  fi

  install_github_cli
  install_lazygit
  install_lazydocker
}


install_neovim() {
  local current_version=""
  if command -v nvim >/dev/null 2>&1; then
    current_version="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
    if printf '%s\n%s\n' "0.10.0" "$current_version" | sort -V -C; then
      return
    fi
  fi

  [[ "${DRY_RUN:-0}" -eq 1 ]] && { echo "+ install current Neovim release to ~/.local/opt/nvim"; return; }

  local machine asset tmp install_dir
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64) asset="nvim-linux-x86_64.tar.gz" ;;
    aarch64|arm64) asset="nvim-linux-arm64.tar.gz" ;;
    *) warn "Unsupported architecture for automatic Neovim installation: $machine"; return 1 ;;
  esac

  tmp="$(mktemp -d)"
  install_dir="$HOME/.local/opt/nvim"
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${asset}" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
  rm -rf "$install_dir"
  mkdir -p "$(dirname "$install_dir")"
  mv "$tmp/${asset%.tar.gz}" "$install_dir"
  ln -snf "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
  rm -rf "$tmp"
}

install_github_cli() {
  command -v gh >/dev/null 2>&1 && return
  run sudo mkdir -p -m 755 /etc/apt/keyrings
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ add GitHub CLI apt key and repository"
  else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  fi
  run sudo apt-get update
  install_apt_packages gh
}

latest_github_release_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name
}

install_lazygit() {
  command -v lazygit >/dev/null 2>&1 && return
  [[ "${DRY_RUN:-0}" -eq 1 ]] && { echo "+ install latest lazygit release"; return; }
  local version tmp arch
  version="$(latest_github_release_tag jesseduffield/lazygit)"; version="${version#v}"
  arch="$(dpkg --print-architecture)"; [[ "$arch" == amd64 ]] && arch=x86_64
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz" | tar -xz -C "$tmp" lazygit
  install -m 0755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
}

install_lazydocker() {
  command -v lazydocker >/dev/null 2>&1 && return
  [[ "${DRY_RUN:-0}" -eq 1 ]] && { echo "+ install latest lazydocker release"; return; }
  local version tmp arch
  version="$(latest_github_release_tag jesseduffield/lazydocker)"; version="${version#v}"
  arch="$(dpkg --print-architecture)"; [[ "$arch" == amd64 ]] && arch=x86_64
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${arch}.tar.gz" | tar -xz -C "$tmp" lazydocker
  install -m 0755 "$tmp/lazydocker" "$HOME/.local/bin/lazydocker"
  rm -rf "$tmp"
}
