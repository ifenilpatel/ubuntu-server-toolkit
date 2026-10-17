#!/usr/bin/env bash
# Install nvm, Node.js, and PM2 for the Linux user who will run the app.
# Does not copy the app or start PM2.
#
#   sudo bash setup.sh
#
# Asks for the Linux user and Node version. Press Enter to keep the default.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if [[ -z "${NVM_USER:-}" ]]; then
  read -rp "Linux user [ubuntu]: " NVM_USER
  NVM_USER="${NVM_USER:-ubuntu}"
fi
if [[ -z "${NODE_VERSION:-}" ]]; then
  read -rp "Node.js version [24]: " NODE_VERSION
  NODE_VERSION="${NODE_VERSION:-24}"
fi
NVM_VERSION="v0.40.3"

if ! id "${NVM_USER}" >/dev/null 2>&1; then
  echo "User ${NVM_USER} does not exist." >&2
  exit 1
fi

apt-get update
apt-get install -y curl ca-certificates

home=$(getent passwd "${NVM_USER}" | cut -d: -f6)
nvm_dir="${home}/.nvm"

if [[ ! -f "${nvm_dir}/nvm.sh" ]]; then
  sudo -u "${NVM_USER}" -H bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
fi

sudo -u "${NVM_USER}" -H env NODE_VERSION="${NODE_VERSION}" bash -s <<'EOS'
set -euo pipefail
export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1091
. "${NVM_DIR}/nvm.sh"
nvm install "${NODE_VERSION}"
nvm alias default "${NODE_VERSION}"
nvm use default
npm install -g pm2
echo "node $(node -v)"
echo "npm $(npm -v)"
echo "pm2 $(pm2 -v)"
EOS

bashrc="${home}/.bashrc"
touch "${bashrc}"
above_return=$(sed '/^case \$- in/,$d' "${bashrc}")
if grep -qF 'NVM_DIR="$HOME/.nvm"' <<<"${above_return}" && grep -qF 'nvm.sh' <<<"${above_return}"; then
  echo "nvm is already sourced from ${bashrc}."
else
  tmp=$(mktemp)
  inserted=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${inserted}" -eq 0 && "${line}" == 'case $- in'* ]]; then
      printf '%s\n' 'export NVM_DIR="$HOME/.nvm"' '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' '' >> "${tmp}"
      inserted=1
    fi
    printf '%s\n' "${line}" >> "${tmp}"
  done < "${bashrc}"
  if [[ "${inserted}" -eq 0 ]]; then
    tmp2=$(mktemp)
    printf '%s\n' 'export NVM_DIR="$HOME/.nvm"' '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' '' >> "${tmp2}"
    cat "${tmp}" >> "${tmp2}"
    mv "${tmp2}" "${tmp}"
  fi
  mv "${tmp}" "${bashrc}"
  echo "Sourced nvm from ${bashrc}."
fi
chown "${NVM_USER}:${NVM_USER}" "${bashrc}"
chmod 644 "${bashrc}"

sudo -u "${NVM_USER}" -H bash -ic 'node -v && npm -v'

echo "Node.js setup complete for ${NVM_USER}."
