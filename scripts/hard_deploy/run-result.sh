#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

cd result
npm ci

export PORT="${RESULT_PORT:-8081}"
export DATABASE_URL="${DATABASE_URL:-postgres://postgres:postgres@localhost/postgres}"

node server.js
