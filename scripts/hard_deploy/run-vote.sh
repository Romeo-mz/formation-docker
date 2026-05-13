#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

python3 -m venv vote/.venv
source vote/.venv/bin/activate
pip install -r vote/requirements.txt

export PORT="${PORT:-8080}"
export OPTION_A="${OPTION_A:-Cats}"
export OPTION_B="${OPTION_B:-Dogs}"
export REDIS_HOST="${REDIS_HOST:-localhost}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export REDIS_SSL="${REDIS_SSL:-false}"

python vote/app.py
