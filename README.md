# DevBox

DevBox turns a fresh Debian or Ubuntu server into a ready-to-use terminal workspace. One command installs your shell, Herdr, tmux, Neovim, Docker with `lazydocker`, monitoring tools, AI CLIs, and Tailscale.

## Install

Run this as a normal sudo-enabled user, not as root:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

Supported systems:

- Ubuntu Server 24.04 LTS or newer
- Debian 12 (Bookworm) or Debian 13 (Trixie)
- `amd64` and `arm64`

Minimal Debian installs need `curl` and `sudo` first, with your user in the `sudo` group. An SSH key skips the SSH password prompt, not `sudo`. The installer checks `sudo` once at the start, so accounts without a password need one set via `passwd` or passwordless sudo enabled beforehand.

Open a new login session when it finishes.

## What gets installed

**Multiplexer and shell.** DevBox installs [Herdr](https://herdr.dev) with `ctrl+space` tmux-style keybindings, `tmux` as a fallback, Bash configured from pinned [Omadots](https://github.com/omacom-io/omadots), a Starship prompt that shows `@hostname` over SSH, and JetBrainsMono Nerd Font (`v3.5.1`). You also get `fzf`, `eza`, `zoxide`, `bat`, `ripgrep`, and `fd`.

**Docker.** The installer sets up Docker Engine, Compose, `buildx`, and `lazydocker`. If `/etc/docker/daemon.json` does not exist yet, it writes a `10m` x `5` JSON log rotation policy so container logs do not fill the disk.

**Editors and Git.** Neovim comes with pinned LazyVim starter and `tokyonight`, alongside plain Vim for raw TTY sessions, `lazygit`, and `delta` configured as the default Git pager.

**Server tools and SSH.** You get `btop` for live resource monitoring, `ncdu` for hunting down disk usage, `jq`, and `rsync`. The installer adds SSH client keepalives in `/etc/ssh/ssh_config.d/20-devbox-keepalive.conf` and appends `~/.local/share/mise/shims` and `~/.local/bin` to `/etc/security/pam_env.conf` so non-interactive SSH commands like `herdr --remote` find `mise`-managed tools.

**AI CLIs and networking.** `mise` installs Node, OpenCode, Claude Code, Codex, Antigravity CLI, Pi, and Hunk. Tailscale installs from its official APT repository.

> Over SSH, your local terminal emulator draws the font, not the server. DevBox puts JetBrainsMono Nerd Font in `~/.local/share/fonts/JetBrainsMonoNerdFont` for local tools, and setting your own terminal to JetBrainsMono Nerd Font makes the Starship and Herdr icons render properly.

## SSH login startup (Herdr or tmux)

By default, SSH opens a plain Bash shell. DevBox does not hijack your login unless you ask it to. You can still launch Herdr anytime with `h`, tmux with `t`, or connect directly from your laptop with `herdr --remote user@your-server`.

Turn automatic attachment on or off anytime:

```bash
devbox setup startup          # interactive picker (off, herdr, or tmux)
devbox setup startup herdr    # auto-attach Herdr on SSH/login
devbox setup startup tmux     # auto-attach tmux on SSH/login
devbox setup startup off      # back to a plain shell
devbox setup startup status   # print the current setting
```

To skip auto-attach for a single shell when it is turned on, set `DEVBOX_NO_MULTIPLEXER=1` (or `DEVBOX_NO_HERDR=1` / `DEVBOX_NO_TMUX=1`).

## First-time setup

Run the onboarding helper to connect your accounts and keys:

```bash
devbox setup
```

It walks through Git identity, GitHub auth, Tailscale with Tailscale SSH, SSH public keys, and the optional login startup toggle. You can also run any step directly:

```bash
devbox setup git
devbox setup github
devbox setup tailscale
devbox setup ssh --key "ssh-ed25519 AAAA..."
devbox setup startup herdr
```

The same command is on `PATH` as `devbox-setup`.

Password SSH stays enabled by default. Once you confirm key login works, disable password auth explicitly:

```bash
devbox setup ssh \
  --key "ssh-ed25519 AAAA..." \
  --disable-password-auth
```

The helper validates both the public key and the resulting `sshd` config before reloading SSH.

## Installer options

Pass flags after `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh |
  bash -s -- --without-ai
```

Available flags:

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

## DevBox CLI

Run `devbox` with no arguments for the interactive menu, or call a subcommand directly:

```bash
devbox setup                  # onboarding or subcommands (git, github, tailscale, ssh, startup)
devbox install tailscale      # install Tailscale, or pass 'all' to re-run all defaults
devbox remove tailscale       # remove Tailscale
devbox update                 # pull the latest DevBox and update managed packages
devbox help                   # show command reference
```

Useful shell aliases:

```text
h          launch or attach to Herdr
t          attach to tmux
n          open Neovim
v          open Vim
d / dc     run Docker / Docker Compose
lzd        open lazydocker
c / cx     open OpenCode / Claude Code
cy / agy   open Codex / Antigravity CLI
ic         open Herdr/tmux dev layout with OpenCode
mup        update all mise tools immediately
g          run git
ff         fuzzy-find files with bat preview
ls / lta   list files / git-aware directory tree (eza)
cd         smart directory jump (zoxide), plus .. / ... / ....
cls        clear terminal
```

## Updating

Run `devbox update` or re-run the bootstrap command. Updates pull the latest `master` branch, run any pending one-time migrations in `~/.local/state/devbox/migrations`, and update managed packages.

Updates leave your Git identity, GitHub login, Tailscale state, SSH keys, startup toggle, and custom configs alone. Only `~/.config/herdr/config.toml`, `~/.config/tmux/tmux.conf`, and `~/.config/starship.toml` get refreshed, always with timestamped backups and a diff of what changed. Pass `--only configs` if you want to reset all managed configs instead.

## Security

- Docker, Tailscale, GitHub CLI, `gum`, and `mise` come from signed APT repositories. No component script pipes `curl` into `sh`.
- CLI tools and AI agents install through `mise` with checksum verification, JetBrainsMono Nerd Font checks against a pinned SHA-256 hash, and Omadots plus LazyVim starter are pinned to 40-character commit SHAs.
- The installer never stores API keys or tokens. Unattended runs read `DEVBOX_SETUP_*` variables, unset them right after use, and pass Tailscale auth keys over stdin and environment instead of command arguments.
- Install logs live at `~/.local/state/devbox/install.log` with `0600` permissions.
- DevBox creates empty user-owned skill directories at `~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.gemini/antigravity-cli/skills`, and `~/.pi/agent/skills`.
- Docker-published container ports bypass UFW rules. Restrict exposed ports in Docker's `DOCKER-USER` chain instead of relying on UFW.

DevBox builds on ideas and configs from [Omaterm](https://learn.omacom.io/4/the-omaterm-manual).
