# Installer compatibility audit: Debian 13 and Ubuntu Server 24.04

**Audit date:** 2026-07-31  
**Scope:** `bootstrap.sh`, `install.sh`, and every external package, repository,
download, or tool referenced by `scripts/*.sh`.  
**Targets:** Debian 13 “Trixie” and Ubuntu Server 24.04 LTS “Noble”.

## Executive summary

The normal `amd64` and `arm64` paths use valid, current upstream repositories
and download names. Docker, Tailscale, GitHub CLI, Starship, zoxide, mise,
Neovim, lazygit, and lazydocker all still publish the endpoints used by the
installer. The Debian/Ubuntu package names used by the base and terminal
components are available on both target releases.

There are nevertheless two clean-install correctness problems and several
upgrade, architecture, and integration gaps:

1. An already-installed Neovim 0.10.x is incorrectly accepted, although the
   current LazyVim configuration requires Neovim 0.11.2 or newer.
2. The imported Omadots `ff` alias always invokes `bat`, but the installer does
   not install it (and Debian/Ubuntu package it as the `batcat` executable).
3. Docker is installed alongside UFW without warning that published container
   ports bypass UFW rules.
4. Existing distribution Docker/containerd packages are not removed before
   installing Docker CE, contrary to Docker's prerequisite steps.
5. The project claims Debian/Ubuntu generally, but several binary installers
   only work on `amd64`/`arm64`; 32-bit ARM and other supported distro
   architectures fail part-way through.

## Prioritized findings

### P1 — Existing Neovim 0.10.x leaves LazyVim unsupported

`install_neovim` returns without upgrading when the installed version is
`>= 0.10.0`. It then installs the current, unpinned `LazyVim/starter`. Current
LazyVim requires **Neovim >= 0.11.2**, built with LuaJIT, as stated in the
[official LazyVim repository requirements](https://github.com/LazyVim/LazyVim#%EF%B8%8F-requirements).

This is a concrete failure on either target OS when a user already has Neovim
0.10.x in `PATH`: the installer skips its current Neovim tarball but deploys a
configuration that no longer supports that binary. Raise the acceptance floor
to LazyVim's current minimum, or pin the LazyVim starter/configuration to a
compatible release.

### P1 — Omadots file preview depends on an executable that is never installed

The installer copies current `omacom-io/omadots` shell configuration. Its `ff`
alias invokes `bat --style=numbers --color=always`, but no installer component
installs `bat`. Debian documents that its `bat` package deliberately exposes
the binary as `batcat` because of a name collision
([Debian package README](https://salsa.debian.org/rust-team/debcargo-conf/-/blob/master/src/bat/debian/README.Debian));
Ubuntu Noble's package likewise installs `/usr/bin/batcat`
([Ubuntu Noble file list](https://packages.ubuntu.com/noble/amd64/bat/filelist)).

Therefore `ff` opens `fzf`, but preview commands fail with `bat: command not
found` on clean installs of both targets. Install `bat` and create a
user-visible `bat -> batcat` compatibility symlink, or make the imported alias
select whichever executable exists.

### P1 security/operations — Docker-published ports bypass UFW

The base component installs UFW and the Docker component installs Docker
Engine, which creates its own firewall rules. Docker's current Debian
documentation explicitly warns that when UFW or firewalld is used, exposed
container ports bypass those firewall rules; it also says Docker supports
`iptables-nft` and `iptables-legacy`, not rules created directly with `nft`
([Docker Debian firewall limitations](https://docs.docker.com/engine/install/debian/#firewall-limitations)).

This does not necessarily abort installation, but it defeats the firewall
expectation implied by installing UFW on a server. The installer should either
configure/document a `DOCKER-USER` policy or clearly warn before treating UFW
as protection for published container ports.

### P1 upgrade/interoperability — Docker package conflicts are not removed

Docker requires distribution packages such as `docker.io`, `docker-compose`,
`podman-docker`, `containerd`, and `runc` to be removed before installing the
official `docker-ce`/`containerd.io` packages. The official prerequisite and
removal command are listed for both
[Debian](https://docs.docker.com/engine/install/debian/#uninstall-old-versions)
and
[Ubuntu](https://docs.docker.com/engine/install/ubuntu/#uninstall-old-versions).

`install-docker.sh` adds Docker's repository and installs Docker CE without
checking for those conflicts. A clean minimal target is unaffected, but a
server with distro Docker/containerd already installed can fail dependency
resolution or be left with a conflicting transition. Detect and remove only
the documented conflicting packages before installing Docker CE.

### P2 — Advertised architecture support is broader than the implementation

OS detection restricts distro/version but not architecture, so all Debian and
Ubuntu architectures appear supported. Actual binary coverage differs:

- Neovim explicitly rejects everything except `x86_64`/`amd64` and
  `aarch64`/`arm64`. Current upstream release assets are likewise Linux
  x86-64 and arm64 only
  ([official Neovim releases](https://github.com/neovim/neovim/releases/latest)).
- lazygit and lazydocker convert only Debian `amd64` to upstream `x86_64`.
  Debian `arm64` happens to match, but `armhf`, `i386`, `ppc64el`, `riscv64`,
  and `s390x` are inserted literally into URLs for assets that do not exist.
  The exact current asset sets are published in the official
  [lazygit release](https://github.com/jesseduffield/lazygit/releases/latest)
  and
  [lazydocker release](https://github.com/jesseduffield/lazydocker/releases/latest).
- `opencode-ai` currently declares only `x64` and `arm64` CPU support in its
  [official npm registry metadata](https://registry.npmjs.org/opencode-ai/latest).
  Because all four AI packages are installed in one `npm install` transaction,
  an unsupported-CPU error can prevent the otherwise portable tools from being
  installed too.
- Docker itself supports more architectures than this installer completes:
  Debian supports amd64, armhf, arm64, and ppc64el
  ([Docker Debian OS requirements](https://docs.docker.com/engine/install/debian/#os-requirements));
  Ubuntu also publishes broader architecture support
  ([Docker platform matrix](https://docs.docker.com/engine/install/#supported-platforms)).

For the stated target releases, document and enforce `amd64`/`arm64` at startup,
or add explicit per-tool mappings/skips. Failing early is preferable to a
partially configured machine.

### P2 — Debian/Ubuntu FZF shell integration paths are wrong

Imported Omadots checks `/usr/share/fzf/completion.bash` and
`/usr/share/fzf/key-bindings.bash`. Debian Trixie installs these under
`/usr/share/doc/fzf/examples/`, not `/usr/share/fzf/`
([Debian Trixie `fzf` file list](https://packages.debian.org/trixie/amd64/fzf/filelist)).
Ubuntu Noble uses the same examples directory
([Ubuntu Noble `fzf` file list](https://packages.ubuntu.com/noble/amd64/fzf/filelist)).

The guards avoid shell errors, but completion and key bindings are silently not
enabled on either audited OS. Use the distro paths, or source the integration
reported by the installed package.

### P2 — Minimal Debian bootstrap assumes `sudo` already exists

`bootstrap.sh` uses `sudo apt-get ...` to install Git, and the main installer
requires a non-root user and uses `sudo` for every system change. Debian's
installer does not invariably install/configure `sudo`; it is a separate
package in Trixie
([Debian Trixie `sudo` package](https://packages.debian.org/trixie/sudo)).

On a minimal Debian server created with only a root account/password, the
documented one-line bootstrap cannot install its first prerequisite. This is
not normally a problem on an Ubuntu Server account created by the standard
installer. Document the required sudo-capable user or provide a deliberate,
separate root bootstrap step.

### P3 — Current remote content is unpinned and changes installer behavior

The installer executes live scripts from Tailscale, Starship, zoxide, and mise;
downloads `releases/latest` for Neovim/lazygit/lazydocker; installs npm
`latest`; and clones the tips of Omadots and LazyVim Starter. The endpoints are
current and vendor-documented:

- [Tailscale Linux installer](https://tailscale.com/docs/install/linux)
- [Starship Linux installer](https://starship.rs/guide/#%F0%9F%9A%80-installation)
- [zoxide official installation](https://github.com/ajeetdsouza/zoxide#installation)
- [mise installer](https://mise.jdx.dev/installing-mise.html#https-mise-run)

This is a reproducibility and future-compatibility concern rather than a
current Trixie/Noble failure: a rerun on the same OS can receive a different
installer, binary, npm major version, or shell configuration. Record tested
versions/checksums or pin releases where deterministic provisioning matters.

## Components verified current

| Component | Audit result |
| --- | --- |
| Base APT packages | `ca-certificates`, `curl`, `git`, `gnupg`, `unzip`, `build-essential`, `jq`, `openssh-server`, and `ufw` are present in Debian Trixie and Ubuntu Noble. See the official [Debian package search](https://packages.debian.org/search?keywords=openssh-server&searchon=names&suite=trixie&section=all) and [Ubuntu package search](https://packages.ubuntu.com/search?keywords=openssh-server&searchon=names&suite=noble&section=all); the same indexes were checked for every listed name. |
| Terminal APT packages | `tmux`, `ripgrep`, `fd-find`, `fzf`, and `bash-completion` are present on both targets. Debian/Ubuntu intentionally expose `fd-find` as `fdfind`, and the installer's `fd` symlink handles that. See [Debian `fd-find`](https://packages.debian.org/trixie/fd-find) and [Ubuntu Noble `fd-find`](https://packages.ubuntu.com/noble/fd-find). |
| Docker repository | `https://download.docker.com/linux/{debian,ubuntu}` and the five installed package names match current official instructions. Debian 13 Trixie and Ubuntu 24.04 Noble are explicitly supported: [Debian instructions](https://docs.docker.com/engine/install/debian/) and [Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/). The one-line `deb` source format remains accepted even though current docs demonstrate deb822 `.sources`. |
| Tailscale | `curl -fsSL https://tailscale.com/install.sh \| sh` remains the official mainstream Linux method, and the stable repository publishes explicit [Debian Trixie](https://pkgs.tailscale.com/stable/#debian-trixie) and [Ubuntu Noble](https://pkgs.tailscale.com/stable/#ubuntu-noble) configurations. |
| GitHub CLI | The key URL, keyring permissions, repository URL, architecture expression, and `gh` package match the [official GitHub CLI Debian/Ubuntu instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md). |
| Starship | The script URL and `-b` installation-directory option remain supported. See the [official guide](https://starship.rs/guide/#%F0%9F%9A%80-installation) and [official FAQ example](https://starship.rs/faq/#how-do-i-install-starship-s-latest-version-without-sudo). |
| zoxide | The exact raw GitHub installer command is still the recommended Linux method in the [official repository](https://github.com/ajeetdsouza/zoxide#installation). |
| mise / Node LTS | `curl https://mise.run \| sh`, default installation to `~/.local/bin`, `mise use --global node@lts`, and `mise exec` are current supported interfaces; see [mise Getting Started](https://mise.jdx.dev/getting-started). The latest AI package engine floors are compatible with the current Node LTS: [Codex](https://registry.npmjs.org/%40openai%2Fcodex/latest), [Claude Code](https://registry.npmjs.org/%40anthropic-ai%2Fclaude-code/latest), and [Gemini CLI](https://registry.npmjs.org/%40google%2Fgemini-cli/latest). |
| Neovim release URL | Current releases publish `nvim-linux-x86_64.tar.gz` and `nvim-linux-arm64.tar.gz`, matching the installer's names; see [official latest release assets](https://github.com/neovim/neovim/releases/latest). |
| lazygit/lazydocker (`amd64`, `arm64`) | The latest-release API and constructed Linux asset names exist for these two architectures in the official [lazygit](https://github.com/jesseduffield/lazygit/releases/latest) and [lazydocker](https://github.com/jesseduffield/lazydocker/releases/latest) releases. |
| Omadots / LazyVim Starter | Both Git repositories exist and their remote default branches resolve (`master` for Omadots, `main` for LazyVim Starter). Their use is unpinned; the compatibility findings above apply to current heads. |

## Recommended fix order

1. Raise Neovim's accepted minimum to LazyVim's minimum and add a regression
   test for preinstalled 0.10.x.
2. Install/wire `batcat` for the imported `ff` alias.
3. Address or prominently document Docker/UFW behavior and remove documented
   conflicting Docker packages.
4. Enforce `amd64`/`arm64` or make every binary installer architecture-aware.
5. Correct FZF integration paths and state the sudo-capable-user prerequisite.
6. Add version/checksum policy for remote scripts, release assets, npm tools,
   and cloned configuration.
