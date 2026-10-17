#!/usr/bin/env bash
# Allow one client IP to reach Redis on port 6379.
# Requires the Redis password from setup.sh. Run again to allow another IP.
#
#   sudo bash allow-ip.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

conf=/etc/redis/redis.conf
if [[ ! -f "${conf}" ]]; then
  echo "Redis config not found. Run redis/setup.sh first." >&2
  exit 1
fi

if ! grep -qE '^requirepass[[:space:]]+[^[:space:]]+' "${conf}"; then
  echo "Redis has no password. Run redis/setup.sh first." >&2
  exit 1
fi

if [[ -z "${REDIS_CLIENT_IP:-}" ]]; then
  read -rp "Client IP: " REDIS_CLIENT_IP
fi
if [[ -z "${REDIS_CLIENT_IP}" ]]; then
  echo "Client IP is required." >&2
  exit 1
fi

ipv4='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'
if [[ ! "${REDIS_CLIENT_IP}" =~ ${ipv4} ]]; then
  echo "Client IP must be an IPv4 address." >&2
  exit 1
fi
for octet in "${BASH_REMATCH[@]:1}"; do
  if ((10#${octet} > 255)); then
    echo "Client IP must be an IPv4 address." >&2
    exit 1
  fi
done

sed -i -E '/^bind[[:space:]]/d' "${conf}"
printf 'bind * -::*\n' >> "${conf}"

if grep -qE '^protected-mode[[:space:]]' "${conf}"; then
  sed -i -E 's/^protected-mode[[:space:]].*/protected-mode yes/' "${conf}"
else
  printf 'protected-mode yes\n' >> "${conf}"
fi

if ! ufw status | grep -F "${REDIS_CLIENT_IP}" | grep -q '6379'; then
  ufw allow from "${REDIS_CLIENT_IP}" to any port 6379 proto tcp
fi

systemctl restart redis-server
systemctl is-active redis-server
echo "Allowed ${REDIS_CLIENT_IP}."
echo "Client ${REDIS_CLIENT_IP} can connect on port 6379. Port 6379 stays closed to everyone else."
echo "On the Node server set REDIS_HOST to this machine private IP and set REDIS_PASSWORD."
