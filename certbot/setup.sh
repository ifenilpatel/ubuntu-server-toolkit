#!/usr/bin/env bash
# Install Certbot and the Nginx plugin. Does not request a certificate.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! systemctl is-active --quiet nginx; then
  echo "Nginx is not active. Run nginx/setup.sh first." >&2
  exit 1
fi

apt-get update
apt-get install -y certbot python3-certbot-nginx
systemctl enable --now certbot.timer

certbot --version
systemctl is-enabled certbot.timer
echo "Certbot setup complete. Run add-domain.sh when DNS is ready."
