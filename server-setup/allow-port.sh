#!/usr/bin/env bash
# Open one TCP port in UFW and label it with a name.
# Run again with another port to open that port too. An open port is left as it is.
#
#   sudo bash allow-port.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw is not installed. Run server-setup/setup.sh first." >&2
  exit 1
fi

if [[ -z "${ALLOW_PORT:-}" ]]; then
  read -rp "Port: " ALLOW_PORT
fi
if [[ -z "${ALLOW_NAME:-}" ]]; then
  read -rp "Name: " ALLOW_NAME
fi
if [[ -z "${ALLOW_PORT}" || -z "${ALLOW_NAME}" ]]; then
  echo "Port and name are required." >&2
  exit 1
fi

if [[ ! "${ALLOW_PORT}" =~ ^[0-9]+$ ]] || ((10#${ALLOW_PORT} < 1 || 10#${ALLOW_PORT} > 65535)); then
  echo "Port must be a number from 1 to 65535." >&2
  exit 1
fi
ALLOW_PORT=$((10#${ALLOW_PORT}))

if [[ "${ALLOW_NAME}" == *$'\n'* ]]; then
  echo "Name must be a single line." >&2
  exit 1
fi
name_re='^[A-Za-z0-9][A-Za-z0-9 ._-]*$'
if [[ ! "${ALLOW_NAME}" =~ ${name_re} ]]; then
  echo "Name may contain only letters, digits, spaces, dots, underscores, and hyphens." >&2
  exit 1
fi

if ufw status | grep -qE "(^|[[:space:]])${ALLOW_PORT}/tcp([[:space:]]|$)"; then
  echo "Port ${ALLOW_PORT}/tcp is already allowed."
else
  ufw allow "${ALLOW_PORT}/tcp" comment "${ALLOW_NAME}"
  echo "Allowed ${ALLOW_PORT}/tcp (${ALLOW_NAME})."
fi

ufw status verbose
echo "Port ${ALLOW_PORT}/tcp is labeled ${ALLOW_NAME}."
