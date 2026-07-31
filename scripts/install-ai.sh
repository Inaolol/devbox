#!/usr/bin/env bash
install_ai() {
  log "Installing Omaterm development and AI tools through mise"
  install_agent_skill_directories

  local mise_bin="$HOME/.local/bin/mise"
  [[ -x "$mise_bin" ]] || mise_bin="$(command -v mise || true)"
  if [[ -z "$mise_bin" && "${DRY_RUN:-0}" -eq 1 ]]; then
    mise_bin="$HOME/.local/bin/mise"
  fi
  if [[ -z "$mise_bin" ]]; then
    warn "mise was not found. Skipping mise-managed tools."
    return
  fi

  # Follow Omaterm's general-purpose tool set while leaving out
  # Basecamp/37signals-specific product tooling. Using mise registry names also
  # lets mise select each tool's supported release artifact.
  run "$mise_bin" use --global --yes \
    node pi opencode claude-code codex antigravity-cli \
    aqua:modem-dev/hunk

  warn "Authenticate each AI tool separately. No API keys are stored by this repository."
}

install_agent_skill_directories() {
  log "Creating shared agent skill directories"
  run mkdir -p \
    "$HOME/.agents/skills" \
    "$HOME/.claude/skills" \
    "$HOME/.codex/skills" \
    "$HOME/.pi/agent/skills"
}
