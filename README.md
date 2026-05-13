# TP DevOps — Volet 3 : pousser les images et déployer

Bienvenue dans la branche `azure_deploy`. Les Dockerfiles sont complets. Le but principal est maintenant de publier les images avec `docker image push`, puis de déployer l'application.

Deux chemins sont proposés :

1. cible principale : Azure Container Registry puis Azure Container Apps ;
2. fallback : GitHub Container Registry personnel de chaque étudiant.

## Architecture

```text
GitHub ou terminal étudiant
  ├─ docker build
  ├─ docker image push
  └─ déploiement optionnel

Registry
  ├─ vote
  ├─ result
  └─ worker

Azure Container Apps
  ├─ ca-vote    (ingress public)
  ├─ ca-result  (ingress public)
  └─ ca-worker  (pas d'ingress)
```

Redis et PostgreSQL peuvent être :

- des services managés Azure, recommandé pour un déploiement propre ;
- des services temporaires fournis par un autre environnement de TP.

## Prérequis

Installez :

- Docker ;
- Azure CLI si vous ciblez Azure ;
- un compte Azure si vous utilisez ACR ou Container Apps ;
- un compte GitHub si vous utilisez GHCR.

Vérifiez :

```bash
docker version
az version
```

## Étape 1 — Choisir le registry

### Option A — Azure Container Registry

Créez les ressources de base :

```bash
az login
az group create --name rg-formation-vote --location westeurope
az acr create --resource-group rg-formation-vote --name acrformationvote --sku Basic
az acr login --name acrformationvote
```

Votre registry sera :

```text
acrformationvote.azurecr.io
```

### Option B — GitHub Container Registry

Connectez-vous à GHCR :

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io --username "$GITHUB_USER" --password-stdin
```

Votre registry sera :

```text
ghcr.io
```

Votre namespace peut être :

```text
<votre-login-github>/formation-vote
```

## Étape 2 — Configurer les variables

Copiez l'exemple :

```bash
cp .env.azure.example .env.azure
```

Pour ACR :

```bash
REGISTRY=acrformationvote.azurecr.io
IMAGE_NAMESPACE=formation-vote
ACR_NAME=acrformationvote
```

Pour GHCR :

```bash
REGISTRY=ghcr.io
IMAGE_NAMESPACE=<votre-login-github>/formation-vote
```

Ne commitez jamais `.env.azure`.

## Étape 3 — Build et push manuel

Le script fourni utilise explicitement `docker image push`.

```bash
bash scripts/azure/build-and-push.sh
```

Il construit et pousse :

```text
$REGISTRY/$IMAGE_NAMESPACE/vote:$IMAGE_TAG
$REGISTRY/$IMAGE_NAMESPACE/result:$IMAGE_TAG
$REGISTRY/$IMAGE_NAMESPACE/worker:$IMAGE_TAG
```

Vous pouvez aussi le faire à la main :

```bash
docker build --target final -t "$REGISTRY/$IMAGE_NAMESPACE/vote:$IMAGE_TAG" ./vote
docker image push "$REGISTRY/$IMAGE_NAMESPACE/vote:$IMAGE_TAG"
```

Refaites la même chose pour `result` et `worker`.

## Étape 4 — Déployer via Azure CLI

Créez un environnement Container Apps :

```bash
az containerapp env create \
  --resource-group rg-formation-vote \
  --name cae-formation-vote \
  --location westeurope
```

Renseignez dans `.env.azure` :

```text
AZURE_RESOURCE_GROUP=rg-formation-vote
CONTAINERAPPS_ENVIRONMENT=cae-formation-vote
REDIS_CONNECTION_STRING=...
DATABASE_URL=...
POSTGRES_CONNECTION_STRING=...
```

Déployez :

```bash
bash scripts/azure/deploy-container-apps.sh
```

Le script crée ou met à jour :

- `ca-vote` avec ingress public ;
- `ca-result` avec ingress public ;
- `ca-worker` sans ingress.

## Étape 5 — Déployer via GitHub Actions

Le workflow fourni est :

```text
.github/workflows/publish-and-deploy.yml
```

Par défaut, il pousse vers GHCR :

```text
ghcr.io/${{ github.repository_owner }}/formation-vote
```

Pour cibler ACR, éditez le bloc `env` du workflow ou remplacez les valeurs par des variables/secrets GitHub :

```yaml
REGISTRY: acrformationvote.azurecr.io
IMAGE_NAMESPACE: formation-vote
REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```

Le workflow a deux usages :

1. push sur `azure_deploy` : build + push des images ;
2. lancement manuel `workflow_dispatch` avec `deploy_to_azure=true` : build + push + déploiement Azure Container Apps.

## Variables applicatives

| Service | Variables utiles |
| --- | --- |
| `vote` | `OPTION_A`, `OPTION_B`, `REDIS_URL`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_SSL` |
| `result` | `DATABASE_URL`, `PORT` |
| `worker` | `REDIS_CONNECTION_STRING`, `POSTGRES_CONNECTION_STRING` |

Les valeurs par défaut restent compatibles avec `docker-compose.yml` pour un test local.

## Tester localement avant push

```bash
docker compose up --build
```

Ouvrez :

- vote : <http://localhost:8080> ;
- résultats : <http://localhost:8081>.

Arrêtez :

```bash
docker compose down -v
```

## Nettoyage Azure

Attention, Azure peut générer des coûts.

```bash
az group delete --name rg-formation-vote --yes
```

## Critères de réussite

Le volet est terminé quand :

1. les trois images sont visibles dans ACR ou GHCR ;
2. vous savez expliquer la différence entre `docker build`, `docker tag` et `docker image push` ;
3. vous pouvez déployer via Azure CLI ou via GitHub Actions ;
4. les URLs publiques de `vote` et `result` répondent.
