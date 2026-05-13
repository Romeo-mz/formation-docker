# Formation : Utiliser un dockerignore pour éviter de copier des fichiers inutiles dans l'image.
FROM node:18-slim

# add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# have nodemon available for local dev use (file watching) instead of node
RUN npm install -g nodemon

COPY package*.json ./

RUN npm ci && \
 npm cache clean --force && \
 mv /usr/local/app/node_modules /node_modules

COPY . .

#ENV PORT=?
#EXPOSE ?

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]