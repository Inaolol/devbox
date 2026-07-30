#!/usr/bin/env bash
install_ai() {
  log "Installing Omaterm development and AI tools through mise"
  local mise_bin="$HOME/.local/bin/mise"
  [[ -x "$mise_bin" ]] || mise_bin="$(command -v mise || true)"
  if [[ -z "$mise_bin" && "${DRY_RUN:-0}" -eq 1 ]]; then
    mise_bin="$HOME/.local/bin/mise"
  fi
  if [[ -z "$mise_bin" ]]; then
    warn "mise was not found. Skipping mise-managed tools."
    return
  fi

  # Keep this list aligned with omacom-io/omaterm/mise.packages. Using mise
  # registry names also lets mise select each tool's supported release artifact
  # instead of coupling all agents to npm.
  run "$mise_bin" use --global --yes \
    node pi opencode claude-code codex gemini \
    aqua:modem-dev/hunk \
    github:basecamp/basecamp-cli

  warn "Authenticate each AI tool separately. No API keys are stored by this repository."
}
