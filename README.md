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

Vérification :

```bash
redis-cli PING
```

Résultat attendu : `PONG`.

### Terminal 2 — PostgreSQL

Lancez PostgreSQL avec votre installation locale, puis vérifiez :

```bash
psql -U postgres -d postgres -c "select 1;"
```

Le worker créera la table `votes` automatiquement.

### Terminal 3 — application de vote

```bash
bash scripts/hard_deploy/run-vote.sh
```

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
| `worker` attend en boucle | Redis ou PostgreSQL est inaccessible |
| impossible de revoter | supprimez le cookie `voter_id` ou utilisez une fenêtre privée |

## À retenir

Ce volet montre pourquoi le déploiement manuel devient fragile : chaque service a son runtime, son port, ses variables et son ordre de démarrage. Le volet suivant remplace cette friction par des images et Compose.
