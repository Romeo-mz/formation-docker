# TP DevOps — Volet 2 : créer les Dockerfiles

Bienvenue dans la branche `easy_deploy`. Les fichiers Compose sont déjà fournis. Votre mission est de comprendre et améliorer les Dockerfiles des services applicatifs.

Le but n'est pas encore de faire du cloud. Le but est de transformer trois applications lancées à la main en trois images reproductibles.

## Architecture

```text
Navigateur → vote → Redis → worker → PostgreSQL → result → Navigateur
```

| Service | Image à construire ? | Technologie | Rôle |
| --- | --- | --- | --- |
| `vote` | oui | Python / Flask | interface de vote |
| `result` | oui | Node.js / Express | résultats temps réel |
| `worker` | oui | .NET / C# | transfert Redis → PostgreSQL |
| `redis` | non | image officielle | file de messages |
| `db` | non | image officielle PostgreSQL | stockage |

## Ce qui est déjà prêt

- `docker-compose.yml` orchestre toute l'application.
- `docker-compose.images.yml` montre une variante avec images préconstruites.
- `healthchecks/` contient les checks Redis/PostgreSQL.
- Les Dockerfiles de `vote`, `result` et `worker` existent, mais ils sont volontairement simples.

## Travail à faire

Améliorez progressivement :

- `vote/Dockerfile` ;
- `result/Dockerfile` ;
- `worker/Dockerfile`.

Commencez par les faire fonctionner. Optimisez ensuite.



## Étapes pédagogiques proposées

### Étape 1 — Image naïve

Objectif : une image qui démarre.

Questions :

- Quelle image de base utilisez-vous ?
- Quel est le répertoire de travail ?
- Quels fichiers faut-il copier ?
- Quelle commande démarre le service ?

### Étape 2 — Cache des dépendances

Objectif : éviter de réinstaller toutes les dépendances à chaque changement de code.

Indice : copiez d'abord les fichiers de dépendances, installez, puis copiez le code.

Exemples :

- `requirements.txt` pour Python ;
- `package*.json` pour Node.js ;
- `*.csproj` pour .NET.

### Étape 3 — Image de production

Objectif : ne pas embarquer les outils inutiles.

Pistes :

- `vote` : lancer avec Gunicorn plutôt qu'avec le serveur Flask dev ;
- `result` : garder Node.js runtime et éviter les dépendances globales inutiles ;
- `worker` : utiliser un build multi-stage SDK → runtime.

### Étape 4 — Healthchecks

Le service `vote` a un healthcheck HTTP dans `docker-compose.yml`.

Vérifiez que l'image contient ce qu'il faut :

```bash
docker compose ps
```

Si `vote` est `unhealthy`, regardez :

```bash
docker compose logs vote
```

## Générer des votes

Une fois l'application lancée :

```bash
docker compose --profile seed up
```

Le service `seed` envoie des votes à l'application `vote`.
## Démarrage rapide

Depuis la racine du dépôt :

```bash
docker compose up --build
```



Ouvrez :

- vote : <http://localhost:8080> ;
- résultats : <http://localhost:8081>.

Arrêt complet :

```bash
docker compose down -v
```

## Construire une image à la fois

```bash
docker build -t formation-vote:local ./vote
docker build -t formation-result:local ./result
docker build -t formation-worker:local ./worker
```

Puis inspectez :

```bash
docker image ls | grep formation
```

## Utiliser vos images dans Compose

Le Compose actuel utilise `build:`. C'est pratique en TP.

Pour tester explicitement une image taguée, remplacez temporairement :

```yaml
services:
  vote:
    build:
      context: ./vote
```

par :

```yaml
services:
  vote:
    image: formation-vote:local
```

Faites la même chose pour `result` et `worker` si besoin.

## Dépannage
> Permission denied 
> Netskope peut bloquer le build. Essayez de monter les certifs netskope dans le dockerfile bloquant pour Docker.

| Symptôme | Cause probable |
| --- | --- |
| `vote` est `unhealthy` | `curl` manque dans l'image ou l'application ne répond pas sur le port 80 |
| `result` ne démarre pas | dépendances Node absentes ou port incorrect |
| `worker` boucle | Redis ou PostgreSQL n'est pas prêt |
| build très lent | les dépendances sont copiées après tout le code |

## Critères de réussite

Le volet est terminé quand :

1. `docker compose up --build` démarre l'application ;
2. <http://localhost:8080> permet de voter ;
3. <http://localhost:8081> affiche les résultats ;
4. `docker compose ps` montre les services principaux démarrés ;
5. vous savez expliquer chaque ligne de chaque Dockerfile.

## Pour aller plus loin

- Ajouter un utilisateur non-root dans les images.
- Comparer la taille avant/après multi-stage.
- Ajouter `.dockerignore` dans chaque service.
- Construire pour `linux/amd64` et `linux/arm64` avec Buildx.
