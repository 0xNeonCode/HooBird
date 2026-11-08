#!/bin/bash
# Creates the loopback roles when the Postgres volume is empty.
# The entrypoint runs this once. Passwords come from the container environment,
# which compose reads from the gitignored runtime/localhost.env.
# They are not production credentials and must not be reused on another host.
set -euo pipefail

if [[ -z "${SYNAPSE_DB_PASSWORD:-}" || -z "${POLICY_DB_PASSWORD:-}" ]]; then
  echo "SYNAPSE_DB_PASSWORD and POLICY_DB_PASSWORD are required" >&2
  exit 1
fi
if [[ "$SYNAPSE_DB_PASSWORD" == replace-with-* || "$POLICY_DB_PASSWORD" == replace-with-* ]]; then
  echo "database passwords are still placeholders" >&2
  exit 1
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
CREATE USER synapse WITH PASSWORD '${SYNAPSE_DB_PASSWORD//\'/\'\'}';
CREATE DATABASE synapse WITH OWNER synapse TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C';
CREATE USER hoobird_policy WITH PASSWORD '${POLICY_DB_PASSWORD//\'/\'\'}';
CREATE DATABASE hoobird_policy OWNER hoobird_policy;
SQL
