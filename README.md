# DevBox: native Omaterm for Debian and Ubuntu

A host-native translation of
[Omaterm](https://learn.omacom.io/4/the-omaterm-manual) for Ubuntu Server and
Debian. It provides the familiar headless development environment used by
Omaterm and inspired by [Omarchy](https://github.com/basecamp/omarchy), without
requiring Arch Linux, a desktop environment, or a development container.

The package and service layer is translated to Debian/Ubuntu. The shell,
LazyVim, tmux, and shared configuration come from the same
[`omacom-io/omadots`](https://github.com/omacom-io/omadots) source used by
Omaterm.

## Supported systems

The installer detects the distribution and release codename automatically from `/etc/os-release`.

- Ubuntu Server 24.04 LTS or newer
- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- amd64 or arm64 architecture

Run it as a normal sudo-enabled user, not as root. Minimal Debian installations
must have `sudo` installed and configured before running the bootstrap command.

## Installs

- Shell environment: Omadots, Starship, eza, fzf, zoxide, bat, fd, ripgrep
- Terminal workflow: tmux, Neovim with LazyVim, Vim, lazygit, lazydocker
- Development: mise, Node, compiler/build tools, Docker Engine, Compose, buildx
- Agents and CLIs: OpenCode, Claude Code, Codex, Gemini, Pi, Hunk, Basecamp CLI
- Services: OpenSSH, GitHub CLI, Tailscale

The tool lists track Omaterm's current `arch.packages` and `mise.packages`,
translated to packages and release assets that work on Debian and Ubuntu.

## Safe installation

```bash
git clone https://github.com/Inaolol/devbox.git
cd devbox
./tests/test.sh
./install.sh
```

After reviewing the repository, the one-command installer is:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

Pass installer options after `bash -s --`, for example:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash -s -- --without-ai
```

## Options

```bash
./install.sh --dry-run
./install.sh --without-ai
./install.sh --without-tailscale
./install.sh --only docker
./install.sh --only configs
./install.sh --only services
```

## Distribution handling

Ubuntu and Debian use the same installation flow. Docker's repository is selected automatically:

- Ubuntu: `https://download.docker.com/linux/ubuntu`
- Debian: `https://download.docker.com/linux/debian`

The detected release codename is used in the repository entry, such as `noble`, `bookworm`, or `trixie`.

## After installation

Open a new login session. Interactive terminal sessions automatically attach
to the shared `Work` tmux session, matching Omaterm. Disable that behavior for
a session with:

```bash
DEVBOX_NO_TMUX=1 bash
```

Run the optional Omaterm-style onboarding:

```bash
devbox-setup
```

It can configure Git identity, GitHub authentication, Tailscale with Tailscale
SSH, and an SSH public key. Individual steps are also available:

```bash
devbox-setup git
devbox-setup github
devbox-setup tailscale
devbox-setup ssh --key 'ssh-ed25519 AAAA...'
```

Password SSH authentication is never disabled automatically. To explicitly
switch to key-only SSH after installing and validating a public key:

```bash
devbox-setup ssh --key 'ssh-ed25519 AAAA...' --disable-password-auth
```

Sign out and back in once so Docker group membership takes effect.

## Storage recommendation

Install the operating system, Docker, databases, and active projects on the SSD. Mount the HDD at `/data` for backups, media, archives, and large persistent volumes.

## Security

The installer never stores tokens or API keys. Existing managed configuration files are backed up before replacement. It does not modify SSH authentication policy or open public firewall ports.

Docker-published container ports bypass UFW rules. Restrict published ports
with rules in Docker's `DOCKER-USER` chain; do not rely on UFW alone for them.

## Omaterm compatibility

This project follows Omaterm's setup order:

1. Install native system and development packages.
2. Install the official Omadots configuration.
3. Install Omaterm's mise-managed tools.
4. Offer Git, GitHub, Tailscale, and SSH onboarding.
5. Enter tmux for interactive terminal work.

Important tmux keys:

- `Ctrl+Space` primary prefix, `Ctrl+B` secondary prefix
- `Alt+Enter` split vertically
- `Alt+Shift+Enter` split horizontally
- `Alt+Escape` kill pane
- `Ctrl+Alt+Arrow` move between panes
- `Alt+Left/Right` move between windows
- `Alt+1` through `Alt+9` select a window
- `Prefix + ?` show all tmux bindings

The checked-in tmux file mirrors current Omadots, while installation uses the
fresh upstream Omadots configuration as the authoritative source.
