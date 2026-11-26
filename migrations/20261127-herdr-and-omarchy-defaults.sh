#!/usr/bin/env bash
set -Eeuo pipefail

# Deliver Omarchy-style Herdr defaults and opt-in startup toggle to existing
# installs without overwriting user-owned configuration files.
if [[ ! -e $HOME/.config/herdr/config.toml && -f $REPO_ROOT/configs/herdr/config.toml ]]; then
  mkdir -p "$HOME/.config/herdr"
  install -m 0644 "$REPO_ROOT/configs/herdr/config.toml" "$HOME/.config/herdr/config.toml"
fi

devbox_server="$HOME/.config/shell/devbox-server"
if [[ -f $devbox_server ]] && ! grep -qxF "alias h='herdr'" "$devbox_server"; then
  printf "\nalias h='herdr'\n" >>"$devbox_server"
fi

bashrc="$HOME/.bashrc"
if [[ -f $bashrc ]] && ! grep -q 'HERDR_ENV' "$bashrc"; then
  new_block="$(cat <<'EOF'
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
EOF
)"

  if grep -q 'DEVBOX_NO_TMUX' "$bashrc"; then
    # Preserve previous tmux auto-attach behavior for upgraded users; they can
    # switch to herdr or off anytime via `devbox setup startup`.
    if [[ ! -e $HOME/.config/devbox/startup ]]; then
      mkdir -p "$HOME/.config/devbox"
      printf 'tmux\n' >"$HOME/.config/devbox/startup"
    fi
    tmp="$(mktemp)"
    awk -v block="$new_block" '
      /^if \[\[ -z \$\{TMUX:-\} && -z \$\{DEVBOX_NO_TMUX:-\}/ {
        print block
        skip=1
        next
      }
      skip && /^fi$/ {
        skip=0
        next
      }
      !skip { print }
    ' "$bashrc" >"$tmp"
    mv "$tmp" "$bashrc"
  else
    printf '\n%s\n' "$new_block" >>"$bashrc"
  fi
fi
