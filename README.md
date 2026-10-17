# Ubuntu Server Toolkit

Bash scripts for a fresh Ubuntu server. Each script does one job and must be run as root.

Run the sections in order. Skip a section you do not need. Each fenced block is one command: copy it, replace the placeholders, then paste it on the server. Setting the variables skips the prompts.

## 1. Get the scripts

Install Git if it is missing, clone the public repo, and enter the folder.

```bash
sudo apt-get update && sudo apt-get install -y git
```

```bash
git clone https://github.com/ifenilpatel/ubuntu-server-toolkit.git
```

```bash
cd ubuntu-server-toolkit
```

## 2. Server

### Base setup

Sets the timezone to UTC. Installs curl, ca-certificates, acl, UFW, fail2ban, and unattended-upgrades. Creates a 2G swap file with swappiness 10. UFW allows 22, 80, and 443. fail2ban watches SSH. Does not install Nginx, PostgreSQL, Redis, or change the SSH port.

```bash
sudo bash server-setup/setup.sh
```

### Open a port

Opens one TCP port in UFW. The name is the label in `ufw status`. A second run for the same port does not add another rule.

```bash
sudo ALLOW_PORT=8080 ALLOW_NAME='app' bash server-setup/allow-port.sh
```

## 3. SSH

### Key-only login

Installs OpenSSH on port 22. Password login and root login are off. Existing `authorized_keys` lines stay, including the PEM key. Pass a public key (`ssh-ed25519` or `ssh-rsa`) to add another PC. Run this only while a key you can use is already in `authorized_keys`.

```bash
sudo SSH_USER=ubuntu bash ssh/setup.sh 'ssh-ed25519 AAAA... comment'
```

### Connect from another PC

On Linux or macOS:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

On Windows PowerShell:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

## 4. Git

Installs Git and creates `~/.ssh/id_ed25519` for the Linux user. A second run prints the existing public key and does not replace it.

```bash
sudo GIT_USER=ubuntu GIT_EMAIL=you@example.com bash git/setup.sh
```

## 5. Node.js

Installs nvm v0.40.3, Node.js (default 24), and PM2 for the Linux user. Does not copy an app or start PM2. The server needs outbound HTTPS for the nvm download.

```bash
sudo NVM_USER=ubuntu NODE_VERSION=24 bash nodejs/setup.sh
```

## 6. Nginx

### Install

Installs and enables Nginx.

```bash
sudo bash nginx/setup.sh
```

### Frontend site

Writes an Nginx site for a static frontend. Removes the default site. Web root defaults to `/var/www/<domain>`. Does not build or copy the app. Put the built files in that folder yourself.

```bash
sudo DOMAIN=example.com WEB_ROOT=/var/www/example.com bash hosting/frontend.sh
```

### Backend site

Writes an Nginx site that proxies `API_DOMAIN` to `NODE_UPSTREAM` (`host:port`). Does not start PM2. Start the app with PM2 yourself.

```bash
sudo API_DOMAIN=api.example.com NODE_UPSTREAM=127.0.0.1:3000 bash hosting/backend.sh
```

## 7. HTTPS

Point DNS at this server before requesting a certificate. The server needs outbound HTTPS.

### Install Certbot

Installs Certbot and the Nginx plugin, and enables `certbot.timer`. Nginx must already be running. Does not request a certificate.

```bash
sudo bash certbot/setup.sh
```

### Request a certificate

Requests a certificate for `DOMAIN`, using `EMAIL`, and redirects HTTP to HTTPS.

```bash
sudo DOMAIN=example.com EMAIL=you@example.com bash certbot/add-domain.sh
```

## 8. PostgreSQL

PostgreSQL stays closed to the network until you run the allow-IP script.

### Install

Installs and starts PostgreSQL. Does not create an application database.

```bash
sudo bash database/setup.sh
```

### Create a database

Creates a role and database. The password is not stored in a file. Does not change `listen_addresses` or `pg_hba.conf`. Use a real password.

```bash
sudo DB_NAME=app DB_USER=app DB_PASSWORD='change-me' bash database/create-database.sh
```

### Allow a client IP

Lets one IPv4 address reach PostgreSQL on port 5432. Run it again to allow another address. Other addresses stay blocked by UFW.

```bash
sudo DB_CLIENT_IP=203.0.113.10 bash database/allow-ip.sh
```

## 9. Redis

Redis stays closed to the network until you run the allow-IP script.

### Install

Installs Redis and sets `requirepass`. A second run keeps the existing password when `REDIS_PASSWORD` is unset. Binds to localhost unless an IP was already opened.

```bash
sudo REDIS_PASSWORD='change-me' bash redis/setup.sh
```

### Allow a client IP

Lets one IPv4 address reach Redis on port 6379. Requires a password from the Redis install. On the Node server, set `REDIS_HOST` to this machine's private IP and set `REDIS_PASSWORD`.

```bash
sudo REDIS_CLIENT_IP=203.0.113.10 bash redis/allow-ip.sh
```

## Notes

- Target is Ubuntu with `apt` and `systemd`.
- A typical Node site is sections 1 through 7. Add section 8 or 9 only when this machine should run PostgreSQL or Redis.
- Confirm a second SSH login still works before you close the session that ran `ssh/setup.sh`.
