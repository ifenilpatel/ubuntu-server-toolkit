# Ubuntu Server Toolkit

Bash scripts for a fresh Ubuntu server. Each script does one job and must be run as root.

## Get the scripts

On the server, install Git if it is missing, then clone the public repo. Each block below is one copyable command.

```bash
sudo apt-get update && sudo apt-get install -y git
```

```bash
git clone https://github.com/ifenilpatel/ubuntu-server-toolkit.git
```

```bash
cd ubuntu-server-toolkit
```

Replace the placeholder values, then run the scripts from that folder. Setting the variables skips the prompts.

## Commands

Clock, packages, 2G swap, UFW (22, 80, 443), fail2ban, unattended upgrades.

```bash
sudo bash server-setup/setup.sh
```

Key-only SSH on port 22. Existing `authorized_keys` lines stay, including the PEM key. Add this PC's public key as an extra argument (`ssh-ed25519 ...` or `ssh-rsa ...`).

```bash
sudo SSH_USER=ubuntu bash ssh/setup.sh 'ssh-ed25519 AAAA... comment'
```

From the PC that owns that key. On Linux or macOS:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

On Windows PowerShell:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

Git and an SSH key for the app user. A second run prints the existing public key.

```bash
sudo GIT_USER=ubuntu GIT_EMAIL=you@example.com bash git/setup.sh
```

nvm, Node.js, and PM2. Does not copy an app or start PM2.

```bash
sudo NVM_USER=ubuntu NODE_VERSION=24 bash nodejs/setup.sh
```

Nginx.

```bash
sudo bash nginx/setup.sh
```

Static frontend. Removes the default site. Does not build or copy the app.

```bash
sudo DOMAIN=example.com WEB_ROOT=/var/www/example.com bash hosting/frontend.sh
```

API proxy. Does not start PM2.

```bash
sudo API_DOMAIN=api.example.com NODE_UPSTREAM=127.0.0.1:3000 bash hosting/backend.sh
```

Certbot. Nginx must already be running. This does not request a certificate.

```bash
sudo bash certbot/setup.sh
```

Certificate after DNS points at this server.

```bash
sudo DOMAIN=example.com EMAIL=you@example.com bash certbot/add-domain.sh
```

PostgreSQL. Does not create an application database.

```bash
sudo bash database/setup.sh
```

Application role and database. The password is not stored in a file.

```bash
sudo DB_NAME=app DB_USER=app DB_PASSWORD='change-me' bash database/create-database.sh
```

One client IPv4 on port 5432. Run again for another address.

```bash
sudo DB_CLIENT_IP=203.0.113.10 bash database/allow-ip.sh
```

Redis with `requirepass`. A second run keeps the existing password when `REDIS_PASSWORD` is unset.

```bash
sudo REDIS_PASSWORD='change-me' bash redis/setup.sh
```

One client IPv4 on port 6379. On the Node server set `REDIS_HOST` to this machine's private IP and set `REDIS_PASSWORD`.

```bash
sudo REDIS_CLIENT_IP=203.0.113.10 bash redis/allow-ip.sh
```

## Scripts

| Path | What it does |
| --- | --- |
| `server-setup/setup.sh` | Sets the timezone to UTC, installs curl, ca-certificates, acl, UFW, fail2ban, and unattended-upgrades. Creates a 2G swap file with swappiness 10. UFW allows 22, 80, and 443. fail2ban watches SSH. Does not install Nginx, PostgreSQL, Redis, or change the SSH port. |
| `ssh/setup.sh` | Installs OpenSSH on port 22. Password login and root login are off. Existing `authorized_keys` lines stay. Pass public keys as arguments, or type them when asked. The Linux user defaults to `ubuntu`. |
| `git/setup.sh` | Installs Git and creates `~/.ssh/id_ed25519` for the Linux user. A second run prints the existing public key and does not replace it. |
| `nodejs/setup.sh` | Installs nvm v0.40.3, Node.js (default 24), and PM2 for the Linux user. Does not copy an app or start PM2. |
| `nginx/setup.sh` | Installs and enables Nginx. |
| `hosting/frontend.sh` | Writes an Nginx site for a static frontend. `DOMAIN` is required. Web root defaults to `/var/www/<domain>`. Does not build or copy the app. Removes the default site. |
| `hosting/backend.sh` | Writes an Nginx site that proxies `API_DOMAIN` to `NODE_UPSTREAM` (`host:port`). Does not start PM2. |
| `certbot/setup.sh` | Installs Certbot and the Nginx plugin, and enables `certbot.timer`. Nginx must already be running. Does not request a certificate. |
| `certbot/add-domain.sh` | Requests a certificate for `DOMAIN`, using `EMAIL`, and redirects HTTP to HTTPS. DNS must already point at this server. |
| `database/setup.sh` | Installs and starts PostgreSQL. Does not create an application database. |
| `database/create-database.sh` | Creates a role and database from `DB_NAME`, `DB_USER`, and `DB_PASSWORD`. The password is not stored in a file. Does not change `listen_addresses` or `pg_hba.conf`. |
| `database/allow-ip.sh` | Lets one IPv4 address reach PostgreSQL on port 5432. Run it again to allow another address. Other addresses stay blocked by UFW. |
| `redis/setup.sh` | Installs Redis and sets `requirepass`. A second run keeps the existing password when none is typed. Binds to localhost unless an IP was already opened. |
| `redis/allow-ip.sh` | Lets one IPv4 address reach Redis on port 6379. Requires a password from `redis/setup.sh`. On the Node server, set `REDIS_HOST` to this machine’s private IP and set `REDIS_PASSWORD`. |

## Notes

- Target is Ubuntu with `apt` and `systemd`.
- Run SSH setup only after a key you can use is already in `authorized_keys`. Password login is turned off.
- Database and Redis stay closed to the network until you run the matching `allow-ip.sh`.
- `nodejs/setup.sh` downloads nvm from GitHub. The server needs outbound HTTPS for that step and for Certbot.
