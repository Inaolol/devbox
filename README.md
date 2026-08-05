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
- **Secrets**: 1Password CLI with setup seeding from a 1Password item
- **Networking**: OpenSSH and Tailscale
- **Git**: Optional setup for user name/email and GitHub authentication
- **Ad blocking (opt-in)**: AdGuard Home via Docker Compose
- **Management**: the `devbox` CLI menu plus one-command development databases in Docker

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

This offers Git identity, GitHub authentication, Tailscale with Tailscale SSH, SSH public-key setup, and 1Password authentication. Run a section directly when needed:

```bash
devbox-setup git
devbox-setup github
devbox-setup tailscale
devbox-setup ssh --key "ssh-ed25519 AAAA..."
devbox-setup 1password --service-token "ops_eyJ..."
```

`devbox-setup` ends with a reminder to run `sudo tailscale up` when Tailscale
is installed but not yet connected.

Seed every setup section from one 1Password item (fields `git-name`,
`git-email`, `gh-token`, `ts-token`, `ts-host`, `ssh-key`):

```bash
devbox-setup --op "DevBox Setup"
```

See [docs/1password.md](docs/1password.md) for what 1Password setup does and
what it needs from you.

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
--only 1password
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

## DevBox CLI

After install, `devbox` opens an interactive menu (Setup, Databases, Windows VM,
Install, Remove, Update, Help) and also works directly:

```bash
devbox setup                  # interactive onboarding (same as devbox-setup)
devbox db postgres redis      # development databases in Docker
devbox db                     # choose databases interactively
devbox vm                     # interactive: install, or manage the VM
devbox vm install             # Windows VM in Docker (dockurr/windows)
devbox vm launch              # start the VM and print connection details
devbox install adguard        # optional components: adguard, tailscale, 1password, all
devbox remove tailscale       # remove optional components
devbox update                 # fetch the latest DevBox and update everything
devbox help                   # what each command does and what it needs from you
```

`devbox help` documents each command, what it does, and what is needed from
you before running it.

## Development databases

One command gives you any of the common development databases as Docker
containers bound to `127.0.0.1` only — nothing is reachable from the network:

```bash
devbox db mysql postgres mariadb redis mongo mssql
devbox db remove postgres     # stop and remove a database
devbox db list                # show installed databases
```

| Database  | Container   | Port  | Credentials                               |
|-----------|-------------|-------|-------------------------------------------|
| MySQL 8.4 | `mysql8`    | 3306  | root, empty password                      |
| PostgreSQL 18 | `postgres18` | 5432 | trust auth, superuser `postgres`       |
| MariaDB 11.8 | `mariadb11` | 3306 | root, empty password                    |
| Redis 7   | `redis`     | 6379  | no password                               |
| MongoDB   | `mongodb`   | 27017 | admin / admin123                          |
| MSSQL 2022 | `mssql`    | 1433  | sa / @dmin123 (amd64 only)                |

These are development credentials for local work. Containers restart
automatically (`unless-stopped`) and keep their data across restarts.

## Windows VM

Run a full Windows install in Docker (via [dockurr/windows]) without
touching your server OS. Needs KVM (`/dev/kvm`) and about 10GB of free
space on top of the chosen disk size:

```bash
devbox vm                     # interactive: install, or manage the VM
devbox vm install             # pick RAM, cores, disk, version, credentials
devbox vm launch              # start the VM and wait for Windows to boot
devbox vm stop                # stop the VM
devbox vm status              # show VM status
devbox vm remove              # stop and delete the VM and its data
```

Windows is downloaded and installed on first start (10-15 minutes);
watch progress at `http://127.0.0.1:8006`. Unattended installs work
too via `DEVBOX_VM_RAM`, `DEVBOX_VM_CORES`, `DEVBOX_VM_DISK`,
`DEVBOX_VM_USER`, `DEVBOX_VM_PASS`, and `DEVBOX_VM_VERSION`.

[dockurr/windows]: https://github.com/dockurr/windows

## Updating

Run the installer again. The bootstrap fetches the current `master` branch and
updates installed packages and DevBox-managed programs:

```bash
curl -fsSL https://raw.githubusercontent.com/Inaolol/devbox/master/bootstrap.sh | bash
```

Updates preserve existing shell/editor configuration and onboarding state such
as Git identity, GitHub authentication, Tailscale enrollment, SSH keys, and
1Password. An update refreshes only the tmux and starship configuration from
fresh Omadots (with timestamped backups of your current files); everything
else stays as you left it. An explicit `--only configs` run replaces the full
managed configuration and creates timestamped backups, and carries over a
persisted 1Password service token. DevBox records one-time update migrations
under `~/.local/state/devbox/migrations`, so new releases can change only the
files or settings that actually need changing.

## Omaterm compatibility

DevBox follows the same setup order as Omaterm:

1. Install the native system and development packages.
2. Install the official Omadots configuration.
3. Install Omaterm's mise-managed tools.
4. Configure Git, GitHub, Tailscale, SSH, and 1Password.
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

The installer does not store API keys or tokens. Unattended setup values are read only when explicitly supplied through `DEVBOX_SETUP_*` environment variables. `devbox-setup 1password` validates a service account token and persists it in `~/.config/shell/envs` only after you confirm; `devbox-setup --op` reads a 1Password item while the command runs and stores nothing.

DevBox creates empty skill roots at `~/.agents/skills`, `~/.claude/skills`,
`~/.codex/skills`, and `~/.pi/agent/skills`. It does not install skills into
them, and updates preserve anything the user adds there.

Docker-published container ports bypass UFW rules. Restrict them through Docker's `DOCKER-USER` chain rather than relying on UFW alone.

DevBox is inspired by [Omarchy](https://github.com/basecamp/omarchy) and
[Omaterm](https://learn.omacom.io/4/the-omaterm-manual); see their GitHub
readmes for attribution and the workflows this project builds on.
