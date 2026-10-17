# Ubuntu Server Toolkit

Bash scripts for a fresh Ubuntu server. Each script does one job and must be run as root.

## Get the scripts

On the server, install Git if it is missing, then clone the public repo:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/ifenilpatel/ubuntu-server-toolkit.git
cd ubuntu-server-toolkit
```

Run each script from that folder, for example:

```bash
sudo bash server-setup/setup.sh
```

Scripts ask for missing values. Press Enter to keep a default. You can also set the same values as environment variables and skip the prompts.

## Order

1. `server-setup/setup.sh` — clock, packages, swap, firewall
2. `ssh/setup.sh` — key-only SSH on port 22
3. `git/setup.sh` — Git and an SSH key for the app user
4. `nodejs/setup.sh` — nvm, Node.js, and PM2
5. `nginx/setup.sh` — Nginx
6. `hosting/frontend.sh` and `hosting/backend.sh` — site configs
7. `certbot/setup.sh` then `certbot/add-domain.sh` — HTTPS after DNS points here
8. `database/setup.sh`, `database/create-database.sh`, and optionally `database/allow-ip.sh`
9. `redis/setup.sh` and optionally `redis/allow-ip.sh`

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
