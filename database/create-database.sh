#!/usr/bin/env bash
# Create the application PostgreSQL role and database.
# Does not store the password. Does not change listen_addresses or pg_hba.conf.
#
#   sudo bash create-database.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [[ -z "${DB_NAME:-}" ]]; then
  read -rp "Database name: " DB_NAME
fi
if [[ -z "${DB_USER:-}" ]]; then
  read -rp "Database user: " DB_USER
fi
if [[ -z "${DB_NAME}" || -z "${DB_USER}" ]]; then
  echo "Database name and user are required." >&2
  exit 1
fi
if [[ -z "${DB_PASSWORD:-}" ]]; then
  read -rsp "Database password: " DB_PASSWORD
  echo
fi
if [[ -z "${DB_PASSWORD}" ]]; then
  echo "Database password is required." >&2
  exit 1
fi

if [[ "${DB_PASSWORD}" == *$'\n'* ]]; then
  echo "DB_PASSWORD must be a single line." >&2
  exit 1
fi

ident='^[A-Za-z_][A-Za-z0-9_]*$'
if [[ ! "${DB_NAME}" =~ ${ident} || ! "${DB_USER}" =~ ${ident} ]]; then
  echo "DB_NAME and DB_USER may contain only letters, digits, and underscores." >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not installed. Run database/setup.sh first." >&2
  exit 1
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 \
  -v "db_user=${DB_USER}" \
  -v "db_name=${DB_NAME}" \
  -v "db_password=${DB_PASSWORD}" <<'SQL'
DO $body$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'db_user', :'db_password');
  END IF;
END
$body$;

SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec

GRANT ALL PRIVILEGES ON DATABASE :"db_name" TO :"db_user";
SQL

sudo -u postgres psql -c "\l ${DB_NAME}"
echo "Database ${DB_NAME} is ready for user ${DB_USER}."
