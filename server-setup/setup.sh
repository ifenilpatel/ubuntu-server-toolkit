#!/usr/bin/env bash
# Host setup: clock, base packages, swap, firewall, fail2ban, unattended upgrades.
# UTC, base packages, 2G swap, UFW, fail2ban, unattended-upgrades.
# Does not install Nginx, PostgreSQL, Redis, or change sshd ports.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "=== Timezone UTC ==="
timedatectl set-timezone UTC

echo "=== Packages ==="
apt-get update
apt-get install -y \
  curl \
  ca-certificates \
  acl \
  ufw \
  fail2ban \
  unattended-upgrades

echo "=== Swap (2G, swappiness 10) ==="
if [[ ! -f /swapfile ]]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi
if ! swapon --show | awk '{print $1}' | grep -qx '/swapfile'; then
  swapon /swapfile
fi
if ! grep -qE '^/swapfile[[:space:]]' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
printf 'vm.swappiness=10\n' > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

echo "=== UFW ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force delete allow 2222/tcp >/dev/null 2>&1 || true
ufw --force enable

echo "=== fail2ban ==="
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = 22
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "=== unattended-upgrades ==="
systemctl enable unattended-upgrades
systemctl enable apt-daily-upgrade.timer
systemctl start apt-daily-upgrade.timer

echo "=== Checks ==="
systemctl is-active fail2ban
systemctl is-enabled unattended-upgrades
fail2ban-client status sshd
swapon --show
ufw status verbose
timedatectl
echo "Server setup complete."
