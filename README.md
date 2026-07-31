# DevBox

An Omakase terminal setup for Debian and Ubuntu. Think of it as a host-native [Omaterm](https://learn.omacom.io/4/the-omaterm-manual), bringing the familiar headless [Omarchy](https://github.com/basecamp/omarchy) experience to machines that are not running Arch.

## What it sets up

- **Shell**: Bash with the official [Omadots](https://github.com/omacom-io/omadots), Starship, fzf, eza, zoxide, bat, and tmux
- **Editors**: Neovim with LazyVim, plus Vim for plain TTY sessions
- **Agents**: OpenCode, Claude Code, Codex, Gemini, and Pi
- **Dev tools**: mise, Node, Docker, Compose, buildx, GitHub CLI (`gh`), lazygit, lazydocker, and Hunk
- **Networking**: OpenSSH and Tailscale
- **Git**: Optional setup for user name/email and GitHub authentication

System packages are installed through Debian or Ubuntu repositories wherever possible. Current release binaries are used where the distribution packages do not match Omaterm's requirements. The development and AI tools follow Omaterm's general-purpose tool set while leaving out Basecamp/37signals-specific product tooling.

## Install

Run this as a normal sudo-enabled user, not as root:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

This supports:

- Ubuntu Server 24.04 LTS or newer
- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- amd64 and arm64

Minimal Debian installations must have `curl` and `sudo` installed first, with
the user configured for sudo access.

Open a new login session after installation. DevBox will attach interactive terminals to the shared `Work` tmux session, just like Omaterm.

## Setup

Run the first-time service setup:

```bash
devbox-setup
```

This offers Git identity, GitHub authentication, Tailscale with Tailscale SSH, and SSH public-key setup. Run a section directly when needed:

```bash
devbox-setup git
devbox-setup github
devbox-setup tailscale
devbox-setup ssh --key "ssh-ed25519 AAAA..."
```

Password SSH remains enabled by default. Switch to key-only SSH explicitly after confirming the key works:

```bash
devbox-setup ssh \
  --key "ssh-ed25519 AAAA..." \
  --disable-password-auth
```

The helper validates the key and the resulting OpenSSH configuration before reloading SSH.

## Options

Pass installer options after `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh |
  bash -s -- --without-ai
```

Available options:

```text
--without-ai
--without-tailscale
--only base
--only docker
--only tailscale
--only terminal
--only ai
--only configs
--only services
--dry-run
```

Set `DEVBOX_NO_TMUX=1` before starting Bash to skip automatic tmux attachment:

```bash
DEVBOX_NO_TMUX=1 bash
```

## Updating

Run the installer again. The bootstrap fetches the current `master` branch and reapplies the setup:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

Existing managed configuration is moved to timestamped backups before replacement.

## Omaterm compatibility

DevBox follows the same setup order as Omaterm:

1. Install the native system and development packages.
2. Install the official Omadots configuration.
3. Install Omaterm's mise-managed tools.
4. Configure Git, GitHub, Tailscale, and SSH.
5. Enter tmux for interactive terminal work.

The checked-in tmux configuration mirrors current Omadots. Installation uses fresh upstream Omadots as the authoritative source.

Useful aliases include:

```text
t    attach to tmux
n    open Neovim
v    open Vim
d    run Docker
lzd  open lazydocker
c    open OpenCode
cx   open Claude Code
```

## Security

The installer does not store API keys or tokens. Unattended setup values are read only when explicitly supplied through `DEVBOX_SETUP_*` environment variables.

Docker-published container ports bypass UFW rules. Restrict them through Docker's `DOCKER-USER` chain rather than relying on UFW alone.
