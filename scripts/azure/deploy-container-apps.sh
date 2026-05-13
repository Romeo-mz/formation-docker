#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env.azure ]]; then
  set -a
  source .env.azure
  set +a
fi

REGISTRY="${REGISTRY:?Set REGISTRY in .env.azure, e.g. acrformationvote.azurecr.io or ghcr.io}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:?Set IMAGE_NAMESPACE in .env.azure}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP}"
AZURE_LOCATION="${AZURE_LOCATION:-westeurope}"
CONTAINERAPPS_ENVIRONMENT="${CONTAINERAPPS_ENVIRONMENT:?Set CONTAINERAPPS_ENVIRONMENT}"
VOTE_APP_NAME="${VOTE_APP_NAME:-ca-vote}"
RESULT_APP_NAME="${RESULT_APP_NAME:-ca-result}"
WORKER_APP_NAME="${WORKER_APP_NAME:-ca-worker}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:?Set REGISTRY_USERNAME}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:?Set REGISTRY_PASSWORD}"
REDIS_CONNECTION_STRING="${REDIS_CONNECTION_STRING:?Set REDIS_CONNECTION_STRING}"
DATABASE_URL="${DATABASE_URL:?Set DATABASE_URL}"
POSTGRES_CONNECTION_STRING="${POSTGRES_CONNECTION_STRING:?Set POSTGRES_CONNECTION_STRING}"

az containerapp env show \
  --name "$CONTAINERAPPS_ENVIRONMENT" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  >/dev/null 2>&1 || \
az containerapp env create \
  --name "$CONTAINERAPPS_ENVIRONMENT" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_LOCATION"

create_or_update_vote() {
  local image="$REGISTRY/$IMAGE_NAMESPACE/vote:$IMAGE_TAG"

  if az containerapp show --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" >/dev/null 2>&1; then
    az containerapp registry set --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --server "$REGISTRY" --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD"
    az containerapp secret set --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --secrets redis-url="$REDIS_CONNECTION_STRING"
    az containerapp update --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --image "$image" --set-env-vars OPTION_A="Cats" OPTION_B="Dogs" REDIS_URL="secretref:redis-url"
  else
    az containerapp create --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --environment "$CONTAINERAPPS_ENVIRONMENT" --image "$image" --registry-server "$REGISTRY" --registry-username "$REGISTRY_USERNAME" --registry-password "$REGISTRY_PASSWORD" --target-port 80 --ingress external --secrets redis-url="$REDIS_CONNECTION_STRING" --env-vars OPTION_A="Cats" OPTION_B="Dogs" REDIS_URL="secretref:redis-url"
  fi
}

create_or_update_result() {
  local image="$REGISTRY/$IMAGE_NAMESPACE/result:$IMAGE_TAG"

  if az containerapp show --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" >/dev/null 2>&1; then
    az containerapp registry set --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --server "$REGISTRY" --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD"
    az containerapp secret set --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --secrets database-url="$DATABASE_URL"
    az containerapp update --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --image "$image" --set-env-vars DATABASE_URL="secretref:database-url"
  else
    az containerapp create --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --environment "$CONTAINERAPPS_ENVIRONMENT" --image "$image" --registry-server "$REGISTRY" --registry-username "$REGISTRY_USERNAME" --registry-password "$REGISTRY_PASSWORD" --target-port 80 --ingress external --secrets database-url="$DATABASE_URL" --env-vars DATABASE_URL="secretref:database-url"
  fi
}

create_or_update_worker() {
  local image="$REGISTRY/$IMAGE_NAMESPACE/worker:$IMAGE_TAG"

  if az containerapp show --name "$WORKER_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" >/dev/null 2>&1; then
    az containerapp registry set --name "$WORKER_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --server "$REGISTRY" --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD"
    az containerapp secret set --name "$WORKER_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --secrets redis-connection-string="$REDIS_CONNECTION_STRING" postgres-connection-string="$POSTGRES_CONNECTION_STRING"
    az containerapp update --name "$WORKER_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --image "$image" --set-env-vars REDIS_CONNECTION_STRING="secretref:redis-connection-string" POSTGRES_CONNECTION_STRING="secretref:postgres-connection-string"
  else
    az containerapp create --name "$WORKER_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --environment "$CONTAINERAPPS_ENVIRONMENT" --image "$image" --registry-server "$REGISTRY" --registry-username "$REGISTRY_USERNAME" --registry-password "$REGISTRY_PASSWORD" --ingress disabled --secrets redis-connection-string="$REDIS_CONNECTION_STRING" postgres-connection-string="$POSTGRES_CONNECTION_STRING" --env-vars REDIS_CONNECTION_STRING="secretref:redis-connection-string" POSTGRES_CONNECTION_STRING="secretref:postgres-connection-string"
  fi
}

create_or_update_vote
create_or_update_result
create_or_update_worker

az containerapp show --name "$VOTE_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv
az containerapp show --name "$RESULT_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv
