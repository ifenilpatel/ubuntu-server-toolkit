#!/usr/bin/env bash
# Publish the frontend Nginx site. Does not build or copy the React app.
#
#   sudo bash frontend.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [[ -z "${DOMAIN:-}" ]]; then
  read -rp "Domain: " DOMAIN
fi
if [[ -z "${DOMAIN}" ]]; then
  echo "Domain is required." >&2
  exit 1
fi

if [[ ! "${DOMAIN}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "DOMAIN must be a hostname." >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx is not installed. Run nginx/setup.sh first." >&2
  exit 1
fi

if [[ -z "${WEB_ROOT:-}" ]]; then
  read -rp "Web root [/var/www/${DOMAIN}]: " WEB_ROOT
fi
web_root="${WEB_ROOT:-/var/www/${DOMAIN}}"
available="/etc/nginx/sites-available/${DOMAIN}"
enabled="/etc/nginx/sites-enabled/${DOMAIN}"

install -d -m 755 "${web_root}"
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
    server_name ${DOMAIN} www.${DOMAIN};

    root ${web_root};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)\$ {
        expires 7d;
        add_header Cache-Control "public";
        try_files \$uri =404;
    }

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;
}
EOF

ln -sfn "${available}" "${enabled}"
rm -f /etc/nginx/sites-enabled/default

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
echo "Frontend site ready for ${DOMAIN}. Files belong in ${web_root}."
