#!/usr/bin/env bash
# Install PostgreSQL only. Does not create an application database.
# Run create-database.sh after this. Run allow-ip.sh to allow a client IP.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y postgresql postgresql-contrib
systemctl enable --now postgresql

systemctl is-active postgresql
sudo -u postgres psql -c '\l'
echo "PostgreSQL setup complete. No application database was created."
