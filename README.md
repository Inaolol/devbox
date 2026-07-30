# DevBox

A repeatable Ubuntu Server and Debian setup that installs the terminal and development tools used in an Omarchy-style workflow directly on the host.

## Supported systems

The installer detects the distribution and release codename automatically from `/etc/os-release`.

- Ubuntu Server 24.04 LTS or newer
- Debian 12 (Bookworm)
- Debian 13 (Trixie)

Run it as a normal sudo-enabled user, not as root.

## Installs

Docker Engine and Compose, Tailscale, OpenSSH, the official Omadots shell configuration used by Omaterm, Omaterm-compatible tmux hotkeys, LazyVim, Starship, fzf, ripgrep, fd, zoxide, mise, GitHub CLI, lazygit, lazydocker, Codex, Claude Code, Gemini CLI, and OpenCode.

## Safe installation

```bash
git clone https://github.com/Inaolol/devbox.git
cd devbox
./tests/test.sh
./install.sh
```

After reviewing the repository, the one-command installer is:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/main/bootstrap.sh | bash
```

Pass installer options after `bash -s --`, for example:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/main/bootstrap.sh | bash -s -- --without-ai
```

## Options

```bash
./install.sh --dry-run
./install.sh --without-ai
./install.sh --without-tailscale
./install.sh --only docker
./install.sh --only configs
```

## Distribution handling

Ubuntu and Debian use the same installation flow. Docker's repository is selected automatically:

- Ubuntu: `https://download.docker.com/linux/ubuntu`
- Debian: `https://download.docker.com/linux/debian`

The detected release codename is used in the repository entry, such as `noble`, `bookworm`, or `trixie`.

## After installation

```bash
sudo tailscale up
gh auth login
codex
claude
gemini
opencode
```

Sign out and back in once so Docker group membership takes effect.

## Storage recommendation

Install the operating system, Docker, databases, and active projects on the SSD. Mount the HDD at `/data` for backups, media, archives, and large persistent volumes.

## Security

The installer never stores tokens or API keys. Existing managed configuration files are backed up before replacement. It does not modify SSH authentication policy or open public firewall ports.

## Omaterm compatibility

This project installs the same `omacom-io/omadots` configuration that Omaterm uses, but directly on Ubuntu Server or Debian. That preserves the official shell behavior, LazyVim setup, and tmux bindings without running the terminal environment inside Docker.

Important tmux keys:

- `Ctrl+Space` primary prefix, `Ctrl+B` secondary prefix
- `Alt+Enter` split vertically
- `Alt+Shift+Enter` split horizontally
- `Alt+Escape` kill pane
- `Ctrl+Alt+Arrow` move between panes
- `Alt+Left/Right` move between windows
- `Alt+1` through `Alt+9` select a window
- `Prefix + ?` show all tmux bindings

The exact upstream configuration remains available in `omacom-io/omadots`; this repository pins a reviewed compatible copy for predictable installation.
