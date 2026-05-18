# TP DevOps — Volet 1 : déployer sans conteneur

Bienvenue dans la branche `hard_deploy`. Ici, il n'y a volontairement aucun Dockerfile, aucun fichier Compose et aucun workflow GitHub Actions. Le but est de sentir la douleur du déploiement manuel avant de la supprimer avec Docker.

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

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
- PostgreSQL 14 ou plus (Ubuntu 22.04 LTS fournit la version 14 par défaut).

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
sudo apt install python3 nodejs npm dotnet-sdk-7.0 redis-server postgresql-14
```

> `postgresql-14` installe le **serveur** et le client. Ne confondez pas avec `postgresql-client-14` qui n'installe que le client sans le serveur.

Vérifiez que le serveur est bien présent (il doit exister un cluster) :

```bash
pg_lsclusters
# Doit afficher une ligne : 14  main  5432  down  postgres ...
```

Si la commande ne retourne aucune ligne, le serveur n'est pas installé :

```bash
dpkg -l postgresql-14
# Si absent :
sudo apt install postgresql-14
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

Important : si vous mettez une **chaîne de connexion complète** dans `.env` contenant des `;` (points-virgules),
entourez-la de quotes simples `'...'` dans `.env` — sinon `source .env` coupera la valeur au premier `;`.
Alternativement, préférez définir `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` et `POSTGRES_DB`
et laissez les scripts construire la `POSTGRES_CONNECTION_STRING` automatiquement.

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

**Étape 1** — démarrez le cluster :

```bash
sudo pg_ctlcluster 14 main start
```

**Étape 2** — passez l'authentification TCP en `md5`.

Par défaut, Ubuntu 22.04 utilise `scram-sha-256`. Le worker .NET tourne avec Npgsql 4.x qui ne supporte pas ce protocole. Changez-le en `md5` :

```bash
sudo sed -i 's/scram-sha-256/md5/g' /etc/postgresql/14/main/pg_hba.conf
sudo pg_ctlcluster 14 main restart
```

> `pg_hba.conf` (Host-Based Authentication) contrôle quelle méthode d'authentification PostgreSQL exige selon l'adresse cliente. `md5` est compatible avec tous les clients courants.

**Étape 3** — configurez le mot de passe du rôle PostgreSQL :

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```

> Important : `sudo passwd postgres` change le mot de passe de l'utilisateur **Linux** `postgres`. Le worker .NET utilise une connexion TCP ; il lui faut le mot de passe du **rôle** PostgreSQL, configuré avec `ALTER USER`.

**Étape 4** — vérifiez la connexion TCP, comme le fera le worker :

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -c "select 1;"
```

Le worker créera la table `votes` automatiquement.

### Terminal 3 — application de vote

```bash
bash scripts/hard_deploy/run-vote.sh
```

> Formatter les fichiers en LF (Unix) si vous avez des erreurs du type $'\r': command not found

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
| `Connection refused` sur le port 5432 | Le serveur PostgreSQL n'est pas installé ou pas démarré. Vérifiez avec `pg_lsclusters` puis `sudo pg_ctlcluster 14 main start` |
| `worker` affiche `Waiting for db` en boucle | PostgreSQL inaccessible ou auth `scram-sha-256` incompatible. Suivez les étapes 1-4 du Terminal 2 (pg_hba.conf → md5, restart, ALTER USER) |
| `relation "votes" does not exist` dans result | Le worker n'a pas encore créé la table : attendez qu'il affiche `Connected to db`, ou vérifiez qu'il tourne |
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