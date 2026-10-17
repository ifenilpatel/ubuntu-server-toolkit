#!/usr/bin/env bash
# Install Git and an SSH key for the Linux user.
# A second run prints the existing public key and does not replace it.
#
#   sudo bash setup.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if [[ -z "${GIT_USER:-}" ]]; then
  read -rp "Linux user [ubuntu]: " GIT_USER
  GIT_USER="${GIT_USER:-ubuntu}"
fi
if ! id "${GIT_USER}" >/dev/null 2>&1; then
  echo "User ${GIT_USER} does not exist." >&2
  exit 1
fi

apt-get update
apt-get install -y git

home=$(getent passwd "${GIT_USER}" | cut -d: -f6)
ssh_dir="${home}/.ssh"
key_file="${ssh_dir}/id_ed25519"
pub_file="${key_file}.pub"

install -d -m 700 -o "${GIT_USER}" -g "${GIT_USER}" "${ssh_dir}"

if [[ -f "${pub_file}" ]]; then
  echo "Git key already exists. Public key:"
  cat "${pub_file}"
  exit 0
fi

if [[ -z "${GIT_EMAIL:-}" ]]; then
  read -rp "Email for the key comment: " GIT_EMAIL
fi
if [[ -z "${GIT_EMAIL}" ]]; then
  echo "Email is required to create a new key." >&2
  exit 1
fi

sudo -u "${GIT_USER}" -H ssh-keygen -t ed25519 -N "" -f "${key_file}" -C "${GIT_EMAIL}"
chown "${GIT_USER}:${GIT_USER}" "${key_file}" "${pub_file}"
chmod 600 "${key_file}"
chmod 644 "${pub_file}"

echo "New Git public key:"
cat "${pub_file}"
