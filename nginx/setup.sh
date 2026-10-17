#!/usr/bin/env bash
# Install and enable Nginx. The default site is enough until the React build
# and the /chatbot proxy are added.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y nginx
systemctl enable --now nginx

systemctl is-active nginx
nginx -v
curl -sI http://127.0.0.1 | head -n 1
echo "Nginx setup complete."
