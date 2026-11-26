#!/usr/bin/env bash
NERD_FONT_VERSION="v3.5.1"
JETBRAINS_MONO_SHA256="04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"

setup_terminal_apt_repos() {
  ensure_apt_keyring \
    "Adding GitHub CLI APT keyring" \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    /etc/apt/keyrings/githubcli-archive-keyring.gpg
  ensure_apt_source \
    "Adding GitHub CLI APT repository" \
    /etc/apt/sources.list.d/github-cli.list \
    "deb [arch=${OS_ARCHITECTURE} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

  ensure_apt_keyring \
    "Adding Charm APT keyring" \
    https://repo.charm.sh/apt/gpg.key \
    /etc/apt/keyrings/charm.asc
  ensure_apt_source \
    "Adding Charm APT repository" \
    /etc/apt/sources.list.d/charm.list \
    "deb [signed-by=/etc/apt/keyrings/charm.asc] https://repo.charm.sh/apt/ * *"

  ensure_apt_keyring \
    "Adding mise APT keyring" \
    https://mise.jdx.dev/gpg-key.pub \
    /etc/apt/keyrings/mise-archive-keyring.asc
  ensure_apt_source \
    "Adding mise APT repository" \
    /etc/apt/sources.list.d/mise.list \
    "deb [arch=${OS_ARCHITECTURE} signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main"
}

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  compgen -G "$font_dir/*.ttf" >/dev/null 2>&1 && return 0

  if (( ${DRY_RUN:-0} == 1 )); then
    echo "+ download and verify JetBrainsMono Nerd Font ${NERD_FONT_VERSION} into $font_dir"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  register_temp_dir "$tmp"

  run_step "Downloading JetBrainsMono Nerd Font" \
    curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --max-time 60 \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.tar.xz" \
    -o "$tmp/JetBrainsMono.tar.xz"
  run_step "Verifying JetBrainsMono Nerd Font checksum" \
    verify_sha256 "$JETBRAINS_MONO_SHA256" "$tmp/JetBrainsMono.tar.xz"

  mkdir -p "$font_dir"
  run_step "Extracting JetBrainsMono Nerd Font" \
    tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir" --wildcards '*.ttf'
  rm -rf "$tmp"

  if command -v fc-cache >/dev/null 2>&1; then
    run_step "Refreshing font cache" fc-cache -f "$font_dir"
  fi
}

install_terminal() {
  log "Installing terminal and development tools"
  if (( ${APT_REPOS_PREPARED:-0} == 0 )); then
    setup_terminal_apt_repos
  fi

  install_apt_packages \
    tmux ripgrep fd-find fzf bash-completion bat btop ncdu \
    less vim kitty-terminfo gh gum mise

  mkdir -p "$HOME/.local/bin"
  # -L guards against a stale symlink left behind by a failed earlier run.
  if [[ ! -e $HOME/.local/bin/fd && ! -L $HOME/.local/bin/fd ]] && command -v fdfind >/dev/null 2>&1; then
    run ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
  if [[ ! -e $HOME/.local/bin/bat && ! -L $HOME/.local/bin/bat ]] && command -v batcat >/dev/null 2>&1; then
    run ln -s "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  local mise_bin
  mise_bin="$(find_mise)"
  if [[ -z $mise_bin ]] && (( ${DRY_RUN:-0} == 1 )); then
    mise_bin="/usr/bin/mise"
  fi
  if [[ -z $mise_bin ]]; then
    warn "mise was not found. Skipping mise-managed CLI tools."
    return 1
  fi

  run_step "Installing Neovim, Herdr, Starship, zoxide, eza, delta, lazygit, and lazydocker via mise" \
    "$mise_bin" use --global --yes \
    neovim herdr starship zoxide eza delta lazygit lazydocker

  install_nerd_font
}
