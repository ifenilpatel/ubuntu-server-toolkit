#!/usr/bin/env bash
# Install Redis and require a password.
# A second run keeps the existing password when none is typed.
# Run allow-ip.sh to let a client IP connect. This script does not close that access.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y redis-server

conf=/etc/redis/redis.conf
if [[ ! -f "${conf}" ]]; then
  echo "Redis config not found at ${conf}." >&2
  exit 1
fi

has_pass=0
if grep -qE '^requirepass[[:space:]]+[^[:space:]]+' "${conf}"; then
  has_pass=1
fi

if [[ -z "${REDIS_PASSWORD:-}" && "${has_pass}" -eq 1 ]]; then
  echo "Redis is already protected. Existing password kept."
else
  if [[ -z "${REDIS_PASSWORD:-}" ]]; then
    read -rsp "Redis password: " REDIS_PASSWORD
    echo
  fi
  if [[ -z "${REDIS_PASSWORD}" ]]; then
    echo "Redis password is required." >&2
    exit 1
  fi
  if [[ "${REDIS_PASSWORD}" == *$'\n'* || "${REDIS_PASSWORD}" == *' '* || "${REDIS_PASSWORD}" == *'"'* ]]; then
    echo "Redis password must be one line, with no spaces or quotes." >&2
    exit 1
  fi
  sed -i -E '/^requirepass[[:space:]]/d' "${conf}"
  printf 'requirepass %s\n' "${REDIS_PASSWORD}" >> "${conf}"
fi

if grep -qE '^bind[[:space:]]+\*' "${conf}"; then
  echo "Redis is already open for allowed client IPs."
elif grep -qE '^bind[[:space:]]' "${conf}"; then
  sed -i -E 's/^bind[[:space:]].*/bind 127.0.0.1 -::1/' "${conf}"
else
  printf 'bind 127.0.0.1 -::1\n' >> "${conf}"
fi

systemctl enable --now redis-server
systemctl restart redis-server
systemctl is-active redis-server

if [[ -n "${REDIS_PASSWORD:-}" ]]; then
  redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning ping
fi
echo "Redis setup complete. Set the same value as REDIS_PASSWORD on the Node server."
