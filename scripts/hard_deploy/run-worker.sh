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

dotnet run
