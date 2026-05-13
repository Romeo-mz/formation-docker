# TP DevOps — Volet 1 : déployer sans conteneur

Bienvenue dans la branche `hard_deploy`. Ici, il n'y a volontairement aucun Dockerfile, aucun fichier Compose et aucun workflow GitHub Actions. Le but est de sentir la douleur du déploiement manuel avant de la supprimer avec Docker.

## Objectif

Lancer une application distribuée complète à la main :

```text
Navigateur → vote → Redis → worker → PostgreSQL → result → Navigateur
```

| Service | Technologie | Rôle | Port local |
| --- | --- | --- | --- |
| `vote` | Python / Flask | formulaire de vote | `8080` |
| `redis` | Redis | file des votes | `6379` |
| `worker` | .NET / C# | transfert Redis → PostgreSQL | aucun |
| `db` | PostgreSQL | stockage des votes | `5432` |
| `result` | Node.js / Express | résultats temps réel | `8081` |

## Prérequis

Installez localement :

- Python 3 ;
- Node.js 18 ou plus ;
- SDK .NET 7 ;
- Redis ;
- PostgreSQL 15 ou plus.

Vérifiez les commandes :

```bash
python3 --version
node --version
npm --version
dotnet --version
redis-cli PING
psql --version
```
### Installation sous WSL

Sous WSL :

```bash
sudo apt update
sudo apt install python3 nodejs npm dotnet-sdk-7.0 redis-server postgresql
```

## Configuration minimale

Copiez le fichier d'exemple :

```bash
cp .env.example .env
```

Chargez-le dans chaque terminal qui lance un service :

```bash
set -a
source .env
set +a
```

## Démarrage en 5 terminaux

### Terminal 1 — Redis

```bash
redis-server
```

Si vous obtenez `Could not create server TCP listening socket *:6379: bind: Address already in use`, Redis tourne déjà.

```bash
sudo lsof -i :6379
sudo kill -9 <PID>

# Ou plus proprement :
sudo systemctl stop redis-server.service
```

Vérification :

Le terminal Redis doit afficher `Ready to accept connections`.


### Terminal 2 — PostgreSQL

Lancer PostgreSQL :

```bash
sudo service postgresql start
```

Configurez ensuite le mot de passe du rôle PostgreSQL utilisé par l'application :

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```

> Important : `sudo passwd postgres` change le mot de passe de l'utilisateur Linux `postgres`. Le worker .NET utilise une connexion TCP PostgreSQL ; il lui faut donc le mot de passe du rôle PostgreSQL, configuré avec `ALTER USER`.

Puis vérifiez la connexion TCP, comme le fera le worker :

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -c "select 1;"
```

Le worker créera la table `votes` automatiquement.

### Terminal 3 — application de vote

```bash
bash scripts/hard_deploy/run-vote.sh
```

> Formatter le script en LF (Unix) si vous êtes sous Windows, sinon il ne fonctionnera pas.

Ouvrez <http://localhost:8080>.

### Terminal 4 — application de résultats

```bash
bash scripts/hard_deploy/run-result.sh
```

Ouvrez <http://localhost:8081>.

### Terminal 5 — worker

```bash
bash scripts/hard_deploy/run-worker.sh
```

## Checkpoint

Votez depuis <http://localhost:8080>, puis vérifiez la base :

```bash
psql -U postgres -d postgres -c "select * from votes;"
```

Vous devez voir une ligne par navigateur votant.

## Dépannage rapide

| Symptôme | Piste |
| --- | --- |
| `vote` ne démarre pas | Redis n'est pas lancé ou `REDIS_HOST` est incorrect |
| `result` affiche zéro vote | PostgreSQL ou `worker` ne fonctionne pas |
| `worker` affiche `Waiting for db` en boucle | Lancez `sudo service postgresql start`, puis `sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"` |
| `worker` attend en boucle | Redis ou PostgreSQL est inaccessible, ou `POSTGRES_CONNECTION_STRING` ne correspond pas au mot de passe PostgreSQL |
| impossible de revoter | supprimez le cookie `voter_id` ou utilisez une fenêtre privée |

## À retenir

Ce volet montre pourquoi le déploiement manuel devient fragile : chaque service a son runtime, son port, ses variables et son ordre de démarrage. Le volet suivant remplace cette friction par des images et Compose.

## Désinstallation

Supprimez les services et les données :

```bash
redis-cli FLUSHALL
psql -U postgres -d postgres -c "DROP TABLE IF EXISTS votes;"
```

```bash
sudo apt remove --purge dotnet-sdk-7.0 redis-server postgresql
```