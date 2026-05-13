#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env.azure ]]; then
  set -a
  source .env.azure
  set +a
fi

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-${USER:-student}/formation-vote}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

if [[ -n "${ACR_NAME:-}" ]]; then
  az acr login --name "$ACR_NAME"
elif [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
  echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY" --username "$REGISTRY_USERNAME" --password-stdin
else
  echo "No registry credentials provided. If you target GHCR, run: docker login ghcr.io" >&2
fi

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

Images pushed:
- $VOTE_IMAGE
- $RESULT_IMAGE
- $WORKER_IMAGE
EOF
