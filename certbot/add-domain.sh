#!/usr/bin/env bash
# Request an Nginx certificate for one domain and redirect HTTP to HTTPS.
# Does not store the email. Requires certbot/setup.sh and DNS pointing here.
#
#   sudo bash add-domain.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if [[ -z "${DOMAIN:-}" ]]; then
  read -rp "Domain: " DOMAIN
fi
if [[ -z "${EMAIL:-}" ]]; then
  read -rp "Email: " EMAIL
fi
if [[ -z "${DOMAIN}" || -z "${EMAIL}" ]]; then
  echo "Domain and email are required." >&2
  exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
  echo "certbot is not installed. Run certbot/setup.sh first." >&2
  exit 1
fi

if ! systemctl is-active --quiet nginx; then
  echo "Nginx is not active. Run nginx/setup.sh first." >&2
  exit 1
fi

certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive \
  --agree-tos \
  -m "${EMAIL}" \
  --redirect \
  --keep-until-expiring

certbot certificates
echo "Certificate step complete for ${DOMAIN}."
