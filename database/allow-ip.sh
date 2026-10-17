#!/usr/bin/env bash
# Allow one client IP to reach PostgreSQL on port 5432.
# Run again with another IP to allow that address too. Existing IPs stay allowed.
#
#   sudo bash allow-ip.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not installed. Run database/setup.sh first." >&2
  exit 1
fi

if [[ -z "${DB_CLIENT_IP:-}" ]]; then
  read -rp "Client IP: " DB_CLIENT_IP
fi
if [[ -z "${DB_CLIENT_IP}" ]]; then
  echo "Client IP is required." >&2
  exit 1
fi

ipv4='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'
if [[ ! "${DB_CLIENT_IP}" =~ ${ipv4} ]]; then
  echo "Client IP must be an IPv4 address." >&2
  exit 1
fi
for octet in "${BASH_REMATCH[@]:1}"; do
  if ((10#${octet} > 255)); then
    echo "Client IP must be an IPv4 address." >&2
    exit 1
  fi
done

conf=$(find /etc/postgresql -type f -name postgresql.conf | head -n 1)
hba=$(find /etc/postgresql -type f -name pg_hba.conf | head -n 1)
if [[ -z "${conf}" || -z "${hba}" ]]; then
  echo "PostgreSQL config was not found. Run database/setup.sh first." >&2
  exit 1
fi

sed -i -E '/^[[:space:]]*#?[[:space:]]*listen_addresses[[:space:]]*=/d' "${conf}"
printf "\nlisten_addresses = '*'\n" >> "${conf}"

rule="host all all ${DB_CLIENT_IP}/32 scram-sha-256"
if grep -qxF "${rule}" "${hba}"; then
  echo "IP ${DB_CLIENT_IP} is already allowed."
else
  printf '%s\n' "${rule}" >> "${hba}"
  echo "Allowed ${DB_CLIENT_IP}."
fi

if ! ufw status | grep -F "${DB_CLIENT_IP}" | grep -q '5432'; then
  ufw allow from "${DB_CLIENT_IP}" to any port 5432 proto tcp
fi

systemctl restart postgresql
systemctl is-active postgresql
echo "Client ${DB_CLIENT_IP} can connect on port 5432. Port 5432 stays closed to everyone else."
