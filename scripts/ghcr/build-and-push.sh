#!/usr/bin/env bash
# build-and-push.sh — construit et pousse les trois images vers GHCR.
# Usage : bash scripts/ghcr/build-and-push.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env.ghcr ]]; then
  set -a
  source .env.ghcr
  set +a
fi

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-${USER:-student}/formation-vote}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"

if [[ -z "${REGISTRY_USERNAME:-}" || -z "${REGISTRY_PASSWORD:-}" ]]; then
  echo "Connectez-vous d'abord :"
  echo "  echo \$GITHUB_TOKEN | docker login ghcr.io --username \$GITHUB_USER --password-stdin"
  exit 1
fi

echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY" --username "$REGISTRY_USERNAME" --password-stdin

VOTE_IMAGE="$REGISTRY/$IMAGE_NAMESPACE/vote:$IMAGE_TAG"
RESULT_IMAGE="$REGISTRY/$IMAGE_NAMESPACE/result:$IMAGE_TAG"
WORKER_IMAGE="$REGISTRY/$IMAGE_NAMESPACE/worker:$IMAGE_TAG"

docker build --target final -t "$VOTE_IMAGE" -t "$REGISTRY/$IMAGE_NAMESPACE/vote:latest" ./vote
docker build -t "$RESULT_IMAGE" -t "$REGISTRY/$IMAGE_NAMESPACE/result:latest" ./result
docker build -t "$WORKER_IMAGE" -t "$REGISTRY/$IMAGE_NAMESPACE/worker:latest" ./worker

docker image push "$VOTE_IMAGE"
docker image push "$REGISTRY/$IMAGE_NAMESPACE/vote:latest"
docker image push "$RESULT_IMAGE"
docker image push "$REGISTRY/$IMAGE_NAMESPACE/result:latest"
docker image push "$WORKER_IMAGE"
docker image push "$REGISTRY/$IMAGE_NAMESPACE/worker:latest"

cat <<EOF

Images poussées vers GHCR :
  $VOTE_IMAGE
  $RESULT_IMAGE
  $WORKER_IMAGE
EOF
