# DevBox

A terminal setup for your headless servers — a home box or a cloud VPS. It
installs the shell, editors, dev tools, and networking (Tailscale, SSH) you need
to get productive from the minute you log in, so you don't have to set up a
fresh Debian or Ubuntu server by hand.


## What it sets up

- **Shell**: Bash with [Omadots](https://github.com/omacom-io/omadots), Starship, fzf, eza, zoxide, bat, and tmux
- **Editors**: Neovim with LazyVim, plus Vim for plain TTY sessions
- **Agents**: OpenCode, Claude Code, Codex, Antigravity CLI, and Pi
- **Dev tools**: mise, Node, Docker, Compose, buildx, GitHub CLI (`gh`), lazygit, lazydocker, and Hunk
- **Networking**: OpenSSH and Tailscale
- **Git**: Optional setup for user name/email and GitHub authentication
- **Ad blocking (opt-in)**: AdGuard Home via Docker Compose

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

Open a new login session after installation. DevBox leaves the
shell tmux-free; start tmux yourself with `t` (attaches to or creates the
shared `Work` session), then use `tdl <ai>` for the dev layout.

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
--with-adguard
--only base
--only docker
--only tailscale
--only terminal
--only ai
--only configs
--only services
--only adguard
--dry-run
```

AdGuard Home is opt-in so a DevBox install stays a plain devbox unless asked
for it. `--with-adguard` deploys it during a full install, and `--only adguard`
installs just the ad blocker on an existing box:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh |
  bash -s -- --with-adguard
```

It runs as a Docker Compose service in `~/adguard/docker-compose.yml` (ports
53 for DNS and 80/3000 for the web admin). After install, finish the first-run
setup at `http://<host>:3000`, then point your router or devices at the host's
IP to block ads network-wide. Manage it with:

```bash
docker compose --project-name devbox-adguard -f ~/adguard/docker-compose.yml up -d
docker compose --project-name devbox-adguard -f ~/adguard/docker-compose.yml logs -f
```

Set `DEVBOX_NO_TMUX=1` before starting Bash to skip the auto-attach on hosts
that were set up before this change (or where you re-enable it):

```bash
DEVBOX_NO_TMUX=1 bash
```

## Updating

Run the installer again. The bootstrap fetches the current `master` branch and
updates installed packages and DevBox-managed programs:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

Updates preserve existing shell/editor configuration and onboarding state such
as Git identity, GitHub authentication, Tailscale enrollment, and SSH keys.
Configuration is installed only on first setup; an explicit `--only configs`
run replaces managed configuration and creates timestamped backups. DevBox
records one-time update migrations under `~/.local/state/devbox/migrations`, so
new releases can change only the files or settings that actually need changing.

## Omaterm compatibility

DevBox follows the same setup order as Omaterm:

1. Install the native system and development packages.
2. Install the official Omadots configuration.
3. Install Omaterm's mise-managed tools.
4. Configure Git, GitHub, Tailscale, and SSH.
5. Start tmux interactively with `t` (or `tdl`) when wanted.

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

DevBox creates empty skill roots at `~/.agents/skills`, `~/.claude/skills`,
`~/.codex/skills`, and `~/.pi/agent/skills`. It does not install skills into
them, and updates preserve anything the user adds there.

Docker-published container ports bypass UFW rules. Restrict them through Docker's `DOCKER-USER` chain rather than relying on UFW alone.

DevBox is inspired by [Omarchy](https://github.com/basecamp/omarchy) and
[Omaterm](https://learn.omacom.io/4/the-omaterm-manual); see their GitHub
readmes for attribution and the workflows this project builds on.
