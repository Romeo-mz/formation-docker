#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

cd worker

dotnet restore

dotnet build

export REDIS_CONNECTION_STRING="${REDIS_CONNECTION_STRING:-localhost}"
export POSTGRES_CONNECTION_STRING="${POSTGRES_CONNECTION_STRING:-Server=localhost;Username=postgres;Password=postgres;Database=postgres;}"

if command -v psql >/dev/null 2>&1; then
  if ! PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql -h "${POSTGRES_HOST:-localhost}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" -c "select 1;" >/dev/null 2>&1; then
    cat <<'EOF'
PostgreSQL ne répond pas avec les identifiants attendus par le worker.

Fix rapide sous WSL/Linux :
  sudo service postgresql start
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
  PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -c "select 1;"

Si vous utilisez un autre mot de passe, mettez aussi à jour POSTGRES_CONNECTION_STRING dans .env.
EOF
    exit 1
  fi
fi

dotnet run
