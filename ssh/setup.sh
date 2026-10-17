#!/usr/bin/env bash
# Install OpenSSH on port 22 only. Login is by public key. Password and root login are off.
# Existing authorized_keys lines are kept, including the PEM already on the server.
#
#   sudo bash setup.sh
#
# Asks for the Linux user and any public keys. Press Enter to keep the default or skip a key.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 'ssh-ed25519 AAAA... comment'" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if [[ -z "${SSH_USER:-}" ]]; then
  read -rp "Linux user [ubuntu]: " SSH_USER
  SSH_USER="${SSH_USER:-ubuntu}"
fi
if ! id "${SSH_USER}" >/dev/null 2>&1; then
  echo "User ${SSH_USER} does not exist." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  keys=()
  while true; do
    read -rp "Public key (empty to finish): " one_key
    [[ -z "${one_key}" ]] && break
    keys+=("${one_key}")
  done
  if ((${#keys[@]})); then
    set -- "${keys[@]}"
  fi
fi

key_re='^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$'
for key in "$@"; do
  if [[ "${key}" == *$'\n'* || ! "${key}" =~ ${key_re} ]]; then
    echo "Refusing a key that is not ssh-ed25519, ssh-rsa, or ecdsa-sha2-nistp256." >&2
    exit 1
  fi
done

apt-get update
apt-get install -y openssh-server
systemctl enable --now ssh

dropin=/etc/ssh/sshd_config.d/99-ports.conf
mkdir -p /etc/ssh/sshd_config.d
backup=""
if [[ -f "${dropin}" ]]; then
  backup=$(mktemp)
  cp "${dropin}" "${backup}"
fi

cat > "${dropin}" <<'EOF'
Port 22
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF

if ! sshd -t; then
  if [[ -n "${backup}" ]]; then
    mv "${backup}" "${dropin}"
  else
    rm -f "${dropin}"
  fi
  echo "sshd config test failed. SSH was not reloaded." >&2
  exit 1
fi
[[ -n "${backup}" ]] && rm -f "${backup}"
systemctl reload ssh

home=$(getent passwd "${SSH_USER}" | cut -d: -f6)
ssh_dir="${home}/.ssh"
auth_file="${ssh_dir}/authorized_keys"
install -d -m 700 -o "${SSH_USER}" -g "${SSH_USER}" "${ssh_dir}"
touch "${auth_file}"
chown "${SSH_USER}:${SSH_USER}" "${auth_file}"
chmod 600 "${auth_file}"

for key in "$@"; do
  blob=$(awk '{print $2}' <<<"${key}")
  if awk 'NF >= 2 {print $2}' "${auth_file}" | grep -qxF "${blob}"; then
    echo "Already present."
    continue
  fi
  printf '%s\n' "${key}" >> "${auth_file}"
  echo "Added key."
done

chown "${SSH_USER}:${SSH_USER}" "${auth_file}"
chmod 600 "${auth_file}"
systemctl is-active ssh
echo "SSH listens on port 22. Login is by public key only."
