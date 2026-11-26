#!/usr/bin/env bash
set -Eeuo pipefail

cat <<'HELP'
DevBox help

Run `devbox` to open the interactive menu, or call a command directly:

  devbox setup [args]     Run onboarding (interactive or subcommands)
  devbox install [app]    Install tailscale or all
  devbox remove [app]     Remove tailscale
  devbox update           Fetch the latest DevBox and update everything
  devbox help             This page

------------------------------------------------------------------
Setup (devbox-setup)

Onboarding runs each service and asks what it needs from you:

  git        Needs your name and email. Keeps them in ~/.gitconfig.

  github     Interactive mode opens a browser login via `gh auth login --web`.
             For headless/token auth, pipe a token on stdin:
               devbox-setup github --with-token

  tailscale  Needs nothing from you if run interactively: prints a login
             URL to sign in and enables Tailscale SSH. Unattended setups
             accept an auth key via stdin or flag:
               printf '%s\n' "$TS_KEY" | devbox-setup tailscale --auth-key-stdin [--hostname NAME]
               devbox-setup tailscale --auth-key tskey-... [--hostname NAME]
             If Tailscale is installed but not connected, run:
               sudo tailscale up

  ssh        Needs your SSH public key (ssh-ed25519 AAAA...). It is
             appended to ~/.ssh/authorized_keys for regular OpenSSH
             logins. Add --disable-password-auth to switch to key-only
             authentication once the key is confirmed working.

  startup    Optional SSH/login auto-attach (off by default). Choose
             between plain shell, herdr, or tmux:
               devbox setup startup [herdr|tmux|off|status]

------------------------------------------------------------------
Install and remove (devbox install / devbox remove)

  tailscale  Mesh VPN / private tailnet.
  all        Re-runs every default installer (also: devbox update).

Removing Tailscale cuts this server off your tailnet — if you are
connected over Tailscale SSH, run that removal from the console or
another network.

------------------------------------------------------------------
Update (devbox update)

Fetches the current DevBox release, runs one-time migrations, and
updates every managed package. Existing configuration and onboarding
state (Git identity, GitHub auth, Tailscale enrollment, SSH keys) are
preserved. Run it directly with: devbox update
HELP
