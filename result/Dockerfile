# Formation : Utiliser un dockerignore pour éviter de copier des fichiers inutiles dans l'image.

# TODO formation : choisissez une image de base Node.js.

# tini est un init minimaliste qui gère les signaux et les processus zombies.
# Il doit être installé dans l'image pour que l'ENTRYPOINT ci-dessous fonctionne.
# Sous Alpine : RUN apk add --no-cache tini
# Sous Debian/Ubuntu : RUN apt-get install -y tini

# We need curl for healthcheck

WORKDIR /usr/local/app

# TODO : copier les fichiers de dépendances en premier (pourquoi ?), puis installer, puis copier le code.
# have nodemon available for local dev use (file watching) instead of node

#ENV PORT=?
#EXPOSE ?

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]