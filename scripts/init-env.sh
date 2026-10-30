#!/usr/bin/env bash
# Creates .env from .env.example and generates a random database password.
# Safe to run twice: it never overwrites an existing .env.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -f .env ]; then
  echo ".env already exists, leaving it untouched."
  exit 0
fi

cp .env.example .env

if command -v openssl >/dev/null 2>&1; then
  PASSWORD="$(openssl rand -hex 16)"
else
  PASSWORD="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi

# Use "|" as the sed delimiter. The password is hex, so it has no special characters.
sed -i.bak "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PASSWORD}|" .env
rm -f .env.bak
chmod 600 .env

echo "Created .env with a randomly generated database password (not printed, not committed)."
