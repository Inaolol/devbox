#!/usr/bin/env bash
set -Eeuo pipefail

cat <<'HELP'
DevBox help

Run `devbox` to open the interactive menu, or call a command directly:

  devbox setup            Run the interactive onboarding
  devbox db [db...]       Install or remove development databases
  devbox vm [cmd]         Manage the Windows VM (interactive by default)
  devbox install [app]    Install adguard, tailscale, 1password, or all
  devbox remove [app]     Remove adguard, tailscale, or 1password
  devbox update           Fetch the latest DevBox and update everything
  devbox help             This page

------------------------------------------------------------------
Setup (devbox-setup)

Onboarding runs each service and asks what it needs from you:

  git        Needs your name and email. Keeps them in ~/.gitconfig.

  github     Needs a GitHub personal access token with repo, read:org,
             and gist scopes. It is piped into `gh auth login`, never
             stored by DevBox. Or run: devbox-setup github --with-token
             with the token on stdin.

  tailscale  Needs nothing from you if run interactively: the browser
             opens and asks you to sign in. Unattended setups use an
             auth key:
               devbox-setup tailscale --auth-key tskey-... [--hostname NAME]
             If Tailscale is installed but not connected, run:
               sudo tailscale up

  ssh        Needs your SSH public key (ssh-ed25519 AAAA...). It is
             appended to ~/.ssh/authorized_keys for regular OpenSSH
             logins. Add --disable-password-auth to switch to key-only
             authentication once the key is confirmed working.

  1password  Needs either a 1Password service account token (ops_...,
             created at 1Password.com under Developer → Service
             Accounts) or your account details (sign-in address, email,
             secret key, password). DevBox validates the token and can
             persist it in ~/.config/shell/envs on request. See
             docs/1password.md.

Seed everything from one 1Password item:

  devbox-setup --op "DevBox Setup"

  Reads the item (by name, or op://VAULT/ITEM) and applies Git, GitHub,
  Tailscale, and SSH setup from its fields:
    git-name, git-email, gh-token, ts-token, ts-host, ssh-key
  Explicit devbox-setup flags and DEVBOX_SETUP_* variables win over
  item fields.

------------------------------------------------------------------
Databases (devbox db)

Installs development databases as Docker containers bound to
127.0.0.1 only, so nothing is reachable from the network:

  mysql     MySQL 8.4      port 3306  user root, empty password
  postgres  PostgreSQL 18  port 5432  trust auth, superuser postgres
  mariadb   MariaDB 11.8   port 3306  user root, empty password
  redis     Redis 7        port 6379  no password
  mongo     MongoDB        port 27017 user admin, password admin123
  mssql     MSSQL 2022     port 1433  user sa, password @dmin123 (amd64)

These are development credentials for local work. Remove a database
with: devbox db remove <db>; list with: devbox db list.

------------------------------------------------------------------
Windows VM (devbox vm)

Runs Windows (11 by default) in Docker via dockurr/windows. Needs
KVM (/dev/kvm) and about 10GB free on top of the chosen disk size.

Run `devbox vm` for an interactive session: it walks you through
installing the VM, or asks what to do with an existing one. The full
command reference is at `devbox vm --help`:

  devbox vm install       Create the VM; asks for RAM, cores, disk,
                          version, and credentials (all overridable
                          with DEVBOX_VM_RAM/CORES/DISK/USER/PASS/
                          VERSION for unattended installs)
  devbox vm launch        Start the VM and wait for Windows to boot
  devbox vm stop          Stop the VM
  devbox vm status        Show VM status
  devbox vm remove        Stop and delete the VM and its data

Windows is downloaded and installed on first start (10-15 minutes);
monitor progress at http://127.0.0.1:8006. Ports are bound to
127.0.0.1 only, so from another machine tunnel first:

  ssh -L 3389:127.0.0.1:3389 -L 8006:127.0.0.1:8006 user@server

then connect an RDP client to localhost:3389 with the credentials
set during install. The username/password live in plain text in
~/.config/windows/docker-compose.yml.

------------------------------------------------------------------
Install and remove (devbox install / devbox remove)

  adguard    AdGuard Home DNS ad blocker in Docker. Needs ports 53 and
             80 free. Finish the first-run wizard at http://<host>:3000.
  tailscale  Mesh VPN / private tailnet.
  1password  1Password CLI. Enables devbox-setup 1password and --op.
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
