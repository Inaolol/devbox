#!/usr/bin/env bash
install_ai() {
  log "Preparing AI command line tools through mise"
  local mise_bin="$HOME/.local/bin/mise"
  [[ -x "$mise_bin" ]] || mise_bin="$(command -v mise || true)"
  if [[ -z "$mise_bin" ]]; then
    warn "mise was not found. Skipping AI tools."
    return
  fi
  run "$mise_bin" use --global node@lts
  run "$mise_bin" exec node@lts -- npm install -g @openai/codex @anthropic-ai/claude-code @google/gemini-cli opencode-ai
  warn "Authenticate each AI tool separately. No API keys are stored by this repository."
}
