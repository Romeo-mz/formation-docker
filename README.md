# TP DevOps — de l'installation manuelle au déploiement Azure

Ce dépôt sert de support de formation pour comprendre, pas à pas, comment on passe d'une application lancée « à la main » à une livraison automatisée dans Azure.

L'application est volontairement simple : un vote entre deux options. Son intérêt vient de son architecture distribuée. Elle mélange Python, Node.js, .NET, Redis et PostgreSQL. C'est un bon terrain de jeu pour apprendre Docker, Docker Compose, les registres d'images et le déploiement cloud.

## Objectifs du TP

À la fin du TP, vous saurez :

1. lancer une application multi-services sans Docker ;
2. écrire les Dockerfiles des services applicatifs ;
3. utiliser Docker Compose pour orchestrer les services ;
4. construire et publier des images dans Azure Container Registry ;
5. déployer ces images sur Azure Container Apps via GitHub Actions.

## Organisation des branches

Le TP est découpé en trois volets. Chaque volet correspond à une branche de travail.

| Branche | Objectif | Ce que l'on apprend |
| --- | --- | --- |
| `hard_deploy` | Déployer sans Docker | Dépendances système, ordre de démarrage, variables d'environnement, logs |
| `easy_deploy` | Créer les Dockerfiles uniquement | Images, layers, ports, commandes de lancement, healthchecks |
| `azure_deploy` | Publier et déployer dans Azure | ACR, GitHub Actions, Azure Container Apps, secrets |

> Les fichiers Compose restent dans le dépôt. Ils servent de filet de sécurité et d'outil d'orchestration pendant le TP.

## Architecture de l'application

![Diagramme d'architecture](architecture.excalidraw.png)

L'application contient cinq services.

| Service | Technologie | Rôle | Port local |
| --- | --- | --- | --- |
| `vote` | Python / Flask / Gunicorn | Interface pour voter | `8080` |
| `redis` | Redis | File de messages des votes entrants | interne |
| `worker` | .NET / C# | Lit Redis et écrit dans PostgreSQL | aucun |
| `db` | PostgreSQL | Stocke les votes | interne |
| `result` | Node.js / Express / Socket.io | Affiche les résultats en temps réel | `8081` |

Flux principal :

```text
Navigateur → vote → Redis → worker → PostgreSQL → result → Navigateur
```

Un vote passe donc par plusieurs composants. C'est exactement ce que l'on veut observer dans un TP DevOps : réseau, configuration, logs, healthchecks et persistance.

## Prérequis

Pour faire tout le TP, installez :

- Git ;
- Python 3.11 ou une version compatible ;
- Node.js 18 ;
- SDK .NET 7 ;
- Redis ;
- PostgreSQL 15 ;
- Docker ;
- Docker Compose ;
- Azure CLI ;
- un compte Azure ;
- un dépôt GitHub avec GitHub Actions activé.

Vérifiez Docker :

```bash
docker run hello-world
```

Vérifiez Azure CLI :

```bash
az version
az login
```

## Démarrage rapide avec Docker Compose

Si vous voulez d'abord voir l'application fonctionner :

```bash
docker compose up
```

Ouvrez ensuite :

- application de vote : <http://localhost:8080> ;
- résultats : <http://localhost:8081>.

Pour générer automatiquement des votes :

```bash
docker compose --profile seed up
```

Pour tout arrêter et supprimer le volume PostgreSQL :

```bash
docker compose down -v
```

## Volet 1 — Déployer à la dure, sans Docker

Branche cible : `hard_deploy`.

Le but est de comprendre ce que Docker nous évite ensuite. Ici, vous lancez chaque composant vous-même.

### Travail à faire

1. Installer Redis et PostgreSQL localement.
2. Lancer Redis.
3. Lancer PostgreSQL.
4. Lancer le service `vote`.
5. Lancer le service `result`.
6. Lancer le service `worker`.
7. Faire un vote et vérifier qu'il apparaît dans les résultats.

### 1. Redis

Lancez Redis avec votre gestionnaire de services ou directement en ligne de commande.

Vérifiez qu'il répond :

```bash
redis-cli PING
```

Résultat attendu :

```text
PONG
```

### 2. PostgreSQL

Créez une base compatible avec les valeurs par défaut de l'application.

```bash
createdb postgres
```

Le `worker` crée automatiquement la table `votes` au démarrage si elle n'existe pas.

En local, les valeurs de développement sont :

```text
user     : postgres
password : postgres
database : postgres
```

> Ces identifiants sont utiles pour le TP. Ne les utilisez pas en production.

### 3. Service vote

Le service `vote` est une application Flask.

```bash
cd vote
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export REDIS_HOST=localhost
export OPTION_A="Cats"
export OPTION_B="Dogs"
python app.py
```

Ouvrez <http://localhost:80> si vous lancez `python app.py` tel quel.

Si vous préférez exposer le même port que Docker Compose :

```bash
gunicorn app:app -b 0.0.0.0:8080 --workers 4
```

Ouvrez alors <http://localhost:8080>.

### 4. Service result

Le service `result` est une application Node.js.

```bash
cd result
npm ci
export PORT=8081
export DATABASE_URL=postgres://postgres:postgres@localhost/postgres
node server.js
```

Ouvrez <http://localhost:8081>.

### 5. Service worker

Le `worker` lit les votes dans Redis et les écrit dans PostgreSQL.

```bash
cd worker
dotnet restore
dotnet build
export REDIS_CONNECTION_STRING=localhost
export POSTGRES_CONNECTION_STRING="Server=localhost;Username=postgres;Password=postgres;Database=postgres;"
dotnet run
```

### Checkpoints

Après un vote :

```bash
redis-cli LLEN votes
```

Puis côté PostgreSQL :

```bash
psql -U postgres -d postgres -c "select * from votes;"
```

Vous devez voir le vote stocké ou mis à jour.

### Questions pour comprendre

- Pourquoi faut-il lancer Redis avant `vote` ?
- Pourquoi `worker` dépend-il de Redis et PostgreSQL ?
- Que se passe-t-il si PostgreSQL tombe ?
- Où sont les valeurs de connexion dans chaque service ?
- Que gagne-t-on à les sortir dans des variables d'environnement ?

## Volet 2 — Créer les Dockerfiles

Branche cible : `easy_deploy`.

Le but est de containeriser les services applicatifs. Les fichiers Compose restent en place pour lancer toute l'application.

### Travail à faire

Écrire ou compléter :

- `vote/Dockerfile` ;
- `result/Dockerfile` ;
- `worker/Dockerfile`.

Les images Redis et PostgreSQL viennent du registre Docker officiel. Vous ne les reconstruisez pas.

### Construire les images

Depuis la racine du dépôt :

```bash
docker build --target final -t formation-vote:local ./vote
docker build -t formation-result:local ./result
docker build -t formation-worker:local ./worker
```

Pour le worker, vous pouvez aussi utiliser Buildx si vous voulez cibler une architecture précise :

```bash
docker buildx build --platform linux/amd64 -t formation-worker:local ./worker --load
```

### Lancer avec Compose

Le fichier `docker-compose.yml` sait construire les services depuis les sources :

```bash
docker compose up --build
```

Si vous voulez tester vos images taguées à la main, remplacez temporairement les blocs `build:` par `image:` dans `docker-compose.yml`.

Exemple :

```yaml
services:
	vote:
		image: formation-vote:local
```

### Observer les services

```bash
docker compose ps
docker compose logs vote
docker compose logs worker
docker compose logs result
```

### Comprendre les healthchecks

Deux scripts aident Compose à attendre que les dépendances soient prêtes :

- `healthchecks/redis.sh` ;
- `healthchecks/postgres.sh`.

Dans `docker-compose.yml`, les services applicatifs utilisent `depends_on` avec `condition: service_healthy`. Cela évite de démarrer trop tôt.

### Exercices

1. Supprimez Redis et observez les erreurs.
2. Relancez Redis et observez la reconnexion.
3. Inspectez la taille des images.
4. Expliquez la différence entre le stage `dev` et le stage `final` du service `vote`.
5. Trouvez où le port interne `80` devient `8080` ou `8081` sur votre machine.

## Volet 3 — Publier dans Azure et déployer

Branche cible : `azure_deploy`.

Le but est d'automatiser la livraison : GitHub Actions construit les images, les pousse dans Azure Container Registry, puis met à jour Azure Container Apps.

### Pourquoi Azure Container Apps ?

Une Azure Web App mono-conteneur convient bien à une seule application web. Ici, l'application contient plusieurs services : `vote`, `result`, `worker`, Redis et PostgreSQL.

Azure Container Apps est plus adapté pour ce TP, car il permet de déployer plusieurs applications conteneurisées dans un même environnement, avec ingress, variables, secrets et révisions.

### Architecture cible

```text
GitHub Actions
	├─ build vote/result/worker
	├─ push vers Azure Container Registry
	└─ update Azure Container Apps

Azure
	├─ Azure Container Registry
	├─ Container App vote    (ingress public)
	├─ Container App result  (ingress public)
	├─ Container App worker  (pas d'ingress)
	├─ Azure Cache for Redis
	└─ Azure Database for PostgreSQL
```

Pour un TP court, vous pouvez aussi lancer Redis et PostgreSQL en conteneurs. Pour un environnement durable, préférez les services managés Azure.

### Ressources Azure à créer

Adaptez les noms à votre groupe.

```bash
az group create \
	--name rg-formation-vote \
	--location westeurope

az acr create \
	--resource-group rg-formation-vote \
	--name acrformationvote \
	--sku Basic

az containerapp env create \
	--resource-group rg-formation-vote \
	--name cae-formation-vote \
	--location westeurope
```

> Azure peut générer des coûts. Supprimez les ressources à la fin du TP si vous n'en avez plus besoin.

### Paramètres du workflow GitHub Actions

Le workflow `.github/workflows/azure-container-apps.yml` contient des placeholders pédagogiques en haut du fichier. Remplacez-les pendant le TP par vos vraies valeurs ou par des références à des variables/secrets GitHub Actions.

Paramètres non sensibles :

| Paramètre | Exemple |
| --- | --- |
| `AZURE_CLIENT_ID` | identifiant de l'application Azure AD |
| `AZURE_TENANT_ID` | identifiant du tenant |
| `AZURE_SUBSCRIPTION_ID` | identifiant de la souscription |
| `AZURE_RESOURCE_GROUP` | `rg-formation-vote` |
| `AZURE_LOCATION` | `westeurope` |
| `ACR_NAME` | `acrformationvote` |
| `ACR_LOGIN_SERVER` | `acrformationvote.azurecr.io` |
| `CONTAINERAPPS_ENVIRONMENT` | `cae-formation-vote` |
| `VOTE_APP_NAME` | `ca-vote` |
| `RESULT_APP_NAME` | `ca-result` |
| `WORKER_APP_NAME` | `ca-worker` |

Paramètres sensibles à stocker comme secrets GitHub dans un vrai projet :

| Paramètre | Usage |
| --- | --- |
| `ACR_USERNAME` | utilisateur autorisé à lire dans ACR |
| `ACR_PASSWORD` | mot de passe ou token de lecture ACR |
| `REDIS_CONNECTION_STRING` | connexion Redis pour Azure |
| `POSTGRES_CONNECTION_STRING` | connexion PostgreSQL pour le worker |
| `DATABASE_URL` | connexion PostgreSQL pour `result` |

Exemple de remplacement après création des variables GitHub :

```yaml
ACR_LOGIN_SERVER: ${{ vars.ACR_LOGIN_SERVER }}
DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

Le workflow est pensé pour une authentification Azure par OIDC avec `azure/login`. C'est préférable à un mot de passe statique.

### Variables applicatives utiles

Les services acceptent les variables suivantes :

| Service | Variables |
| --- | --- |
| `vote` | `OPTION_A`, `OPTION_B`, `REDIS_URL`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_SSL` |
| `result` | `PORT`, `DATABASE_URL` |
| `worker` | `REDIS_CONNECTION_STRING`, `REDIS_HOST`, `POSTGRES_CONNECTION_STRING` |

Les valeurs par défaut restent compatibles avec Docker Compose : `redis`, `db`, `postgres/postgres`.

### Pipeline fournie

Le workflow Azure se trouve dans :

```text
.github/workflows/azure-container-apps.yml
```

Il réalise les étapes suivantes :

1. checkout du code ;
2. connexion à Azure ;
3. connexion à Azure Container Registry ;
4. build des images `vote`, `result`, `worker` ;
5. push des images vers ACR ;
6. création ou mise à jour des Container Apps.

### Nettoyage Azure

À la fin du TP :

```bash
az group delete --name rg-formation-vote --yes
```

## Fichiers importants

| Fichier | Rôle |
| --- | --- |
| `docker-compose.yml` | orchestration locale depuis les sources |
| `docker-compose.images.yml` | orchestration avec images préconstruites |
| `vote/` | application Flask de vote |
| `result/` | application Node.js de résultats |
| `worker/` | worker .NET de traitement |
| `healthchecks/` | scripts de healthcheck Redis/PostgreSQL |
| `seed-data/` | génération de votes de test |
| `.github/workflows/` | pipelines CI/CD |

## Dépannage

### Le service `vote` ne démarre pas

Vérifiez Redis :

```bash
docker compose logs redis
docker compose logs vote
```

### Le service `result` affiche zéro vote

Vérifiez PostgreSQL et le worker :

```bash
docker compose logs db
docker compose logs worker
docker compose logs result
```

### Le worker boucle en attente

Il attend probablement Redis ou PostgreSQL. Vérifiez les variables de connexion et les healthchecks.

### Les résultats ne changent pas

Le navigateur ne peut voter qu'une fois par cookie. Essayez une fenêtre privée ou supprimez le cookie `voter_id`.

## Pour aller plus loin

- Ajouter des tests automatisés plus modernes à la place de PhantomJS.
- Ajouter une migration SQL explicite pour la table `votes`.
- Remplacer les mots de passe de développement par des secrets.
- Ajouter des probes et règles de scaling dans Azure Container Apps.
- Comparer Azure Container Apps, Azure Web App for Containers et Kubernetes.
