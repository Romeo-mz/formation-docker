# TP DevOps — Volet 3 : publier les images sur GitHub Container Registry

Bienvenue dans la branche `github_deploy`. Les Dockerfiles sont complets. Le but est de comprendre le cycle **build → tag → push** et d'automatiser cette publication via GitHub Actions.

## Objectif

```text
Code source
  └─ docker build
       └─ image locale
            └─ docker image push
                 └─ ghcr.io/<login>/formation-vote/vote:sha
                    ghcr.io/<login>/formation-vote/result:sha
                    ghcr.io/<login>/formation-vote/worker:sha
```

Deux chemins possibles :

1. **Manuel** — build et push depuis votre machine avec `scripts/ghcr/build-and-push.sh` ;
2. **Automatique** — push sur la branche déclenche le workflow GitHub Actions qui fait tout.

## Prérequis

- Docker installé et en cours d'exécution ;
- un compte GitHub.

Vérifiez :

```bash
docker version
```

## Étape 1 — Créer un token GitHub

Allez sur <https://github.com/settings/tokens> et créez un **Personal Access Token (classic)** avec la portée `write:packages`.

Gardez-le, il sera votre mot de passe pour `docker login ghcr.io`.

## Étape 2 — Se connecter à GHCR

```bash
echo "VOTRE_TOKEN" | docker login ghcr.io --username VOTRE_LOGIN --password-stdin
```

Résultat attendu : `Login Succeeded`.

## Étape 3 — Configurer les variables

Copiez l'exemple :

```bash
cp .env.ghcr.example .env.ghcr
```

Éditez `.env.ghcr` :

```bash
REGISTRY=ghcr.io
IMAGE_NAMESPACE=VOTRE_LOGIN_GITHUB/formation-vote
REGISTRY_USERNAME=VOTRE_LOGIN_GITHUB
REGISTRY_PASSWORD=VOTRE_TOKEN
IMAGE_TAG=local
```

Ne commitez jamais `.env.ghcr`.

## Étape 4 — Build et push manuel

```bash
bash scripts/ghcr/build-and-push.sh
```

Ce script construit les trois images et les pousse vers GHCR :

```text
ghcr.io/$IMAGE_NAMESPACE/vote:$IMAGE_TAG
ghcr.io/$IMAGE_NAMESPACE/result:$IMAGE_TAG
ghcr.io/$IMAGE_NAMESPACE/worker:$IMAGE_TAG
```

Vous pouvez aussi le faire image par image pour comprendre chaque commande :

```bash
# Construire
docker build --target final -t ghcr.io/<login>/formation-vote/vote:local ./vote

# Vérifier l'image locale
docker image ls ghcr.io/<login>/formation-vote/vote

# Pousser
docker image push ghcr.io/<login>/formation-vote/vote:local
```

Refaites la même chose pour `result` et `worker`.

## Étape 5 — Vérifier dans GHCR

Allez sur `https://github.com/<login>?tab=packages`. Vous devez voir les trois packages :

- `formation-vote/vote`
- `formation-vote/result`
- `formation-vote/worker`

## Étape 6 — Automatiser avec GitHub Actions

Le workflow est prêt :

```text
.github/workflows/publish-and-deploy.yml
```

Il se déclenche automatiquement à chaque push sur `github_deploy` ou manuellement via **Actions → Run workflow**.

Il effectue les opérations suivantes :

1. connexion à GHCR avec `GITHUB_TOKEN` (aucun secret à configurer) ;
2. `docker build` des trois images ;
3. `docker image push` vers `ghcr.io/${{ github.repository_owner }}/formation-vote/...`.

Pour activer le workflow :

1. Poussez un changement sur la branche `github_deploy` (par exemple, modifiez un Dockerfile) ;
2. Allez dans l'onglet **Actions** du dépôt ;
3. Observez le job `Build and push images to GHCR` s'exécuter.

## Tester localement avant push

```bash
docker compose up --build
```

Ouvrez :

- vote : <http://localhost:8080>
- résultats : <http://localhost:8081>

Arrêtez :

```bash
docker compose down -v
```

## Variables applicatives

| Service | Variables configurables |
| --- | --- |
| `vote` | `OPTION_A`, `OPTION_B`, `REDIS_URL` ou `REDIS_HOST`/`REDIS_PORT` |
| `result` | `DATABASE_URL`, `PORT` |
| `worker` | `REDIS_CONNECTION_STRING`, `POSTGRES_CONNECTION_STRING` |

Les valeurs par défaut dans `docker-compose.yml` fonctionnent en local.

## Nettoyage

Supprimez les images locales :

```bash
docker rmi ghcr.io/<login>/formation-vote/vote:local
docker rmi ghcr.io/<login>/formation-vote/result:local
docker rmi ghcr.io/<login>/formation-vote/worker:local
```

Pour supprimer un package de GHCR, allez dans **Settings → Packages** sur votre profil GitHub.

## Critères de réussite

Le volet est terminé quand :

1. les trois images sont visibles dans GHCR (`ghcr.io/<login>/formation-vote/...`) ;
2. vous savez expliquer la différence entre `docker build`, `docker tag` et `docker image push` ;
3. le workflow GitHub Actions s'est exécuté avec succès dans l'onglet **Actions** du dépôt.
