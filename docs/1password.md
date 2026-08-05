# 1Password support

DevBox installs the 1Password CLI (`op`) so you can authenticate everything
from one place and seed the whole DevBox setup from a single 1Password item.

## What DevBox does

- Installs `op` from the official 1Password apt repository (amd64 and arm64).
- `devbox-setup 1password` authenticates the CLI with either a **service
  account token** or your **full account details**.
- `devbox-setup --op ITEM` reads setup values from a 1Password item and
  applies Git, GitHub, Tailscale, and SSH setup without further prompts.

## What is needed from you

### Service account token (recommended for servers)

A service account is scoped and revocable. Create one at
1Password.com → Developer → Service Accounts. You get a token that looks
like `ops_eyJ...`.

```bash
devbox-setup 1password --service-token ops_eyJ...
```

or run `devbox-setup 1password` and paste it when prompted. DevBox validates
the token with `op whoami` and asks whether to persist it in
`~/.config/shell/envs` (loaded by your shell on every login) so future
sessions can use it without re-entering it. Persisting stores the token in
plain text in your home directory — DevBox only does this after asking you.

### Full account

If you do not want a service account, sign in with your own credentials:

```bash
devbox-setup 1password --account yourname.1password.com you@example.com YOUR-SECRET-KEY
```

You are then prompted for the account password. The account is stored in
`~/.config/op`, and future `op` invocations work after a normal sign-in.

## Seeding all setup from one item

Create a 1Password item (for example named `DevBox Setup`) with these
**top-level fields**, then run:

```bash
devbox-setup --op "DevBox Setup"
```

| Field       | Applies to                                              |
|-------------|---------------------------------------------------------|
| `git-name`  | `devbox-setup git --name ...`                           |
| `git-email` | `devbox-setup git --email ...`                          |
| `gh-token`  | `devbox-setup github --with-token` (token via stdin)    |
| `ts-token`  | `devbox-setup tailscale --auth-key ...`                 |
| `ts-host`   | Optional Tailscale hostname (defaults to the hostname)  |
| `ssh-key`   | `devbox-setup ssh --key ...`                            |

You can also pass an `op://VAULT/ITEM` reference. Explicit command-line
values and `DEVBOX_SETUP_*` environment variables win over item fields.
Fields are applied only when the item defines them; an item with no
recognized fields is an error.

Unattended installs can seed everything through environment variables:

```bash
DEVBOX_SETUP_OP_TOKEN="ops_eyJ..." DEVBOX_SETUP_OP="DevBox Setup" bash bootstrap.sh
```

## Security notes

- DevBox does not read, store, or log your tokens; the installer itself
  stores nothing (see the README Security section).
- `devbox-setup --op` reads the item only while the command runs.
- The service token is persisted only when you explicitly confirm.
- Use a scoped service account or a scoped token, not a personal account,
  for unattended setups.

## Checking the result

```bash
op whoami   # prints your account or service account identity
```

If authentication is broken, run `devbox-setup 1password` again. Removing the
CLI and its repository is `devbox remove 1password` (or `devbox` → Remove).
