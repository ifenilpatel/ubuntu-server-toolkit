#!/usr/bin/env bash
# Publish the API Nginx site. Proxies to the Node server. Does not start PM2.
#
#   sudo bash backend.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [[ -z "${API_DOMAIN:-}" ]]; then
  read -rp "API domain: " API_DOMAIN
fi
if [[ -z "${NODE_UPSTREAM:-}" ]]; then
  read -rp "Node upstream host:port: " NODE_UPSTREAM
fi
if [[ -z "${API_DOMAIN}" || -z "${NODE_UPSTREAM}" ]]; then
  echo "API domain and node upstream are required." >&2
  exit 1
fi

if [[ ! "${API_DOMAIN}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "API_DOMAIN must be a hostname." >&2
  exit 1
fi

if [[ ! "${NODE_UPSTREAM}" =~ ^[A-Za-z0-9.-]+:[0-9]+$ ]]; then
  echo "NODE_UPSTREAM must look like host:port." >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx is not installed. Run nginx/setup.sh first." >&2
  exit 1
fi

available="/etc/nginx/sites-available/${API_DOMAIN}"
enabled="/etc/nginx/sites-enabled/${API_DOMAIN}"

install -d -m 755 /etc/nginx/sites-available /etc/nginx/sites-enabled

backup=""
if [[ -f "${available}" ]]; then
  backup=$(mktemp)
  cp "${available}" "${backup}"
fi

cat > "${available}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${API_DOMAIN};

    location / {
        proxy_pass http://${NODE_UPSTREAM};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 20m;
    }

    access_log /var/log/nginx/${API_DOMAIN}.access.log;
    error_log  /var/log/nginx/${API_DOMAIN}.error.log;
}
EOF

ln -sfn "${available}" "${enabled}"

if ! nginx -t; then
  if [[ -n "${backup}" ]]; then
    mv "${backup}" "${available}"
  else
    rm -f "${available}" "${enabled}"
  fi
  echo "nginx config test failed. The site was not reloaded." >&2
  exit 1
fi
[[ -n "${backup}" ]] && rm -f "${backup}"
systemctl reload nginx
echo "Backend site ready for ${API_DOMAIN} -> ${NODE_UPSTREAM}."
