# TP easy_deploy — Dockerfile volontairement simple pour commencer.
# À améliorer pendant le TP : utilisateur non-root, cache npm, tini, image finale minimale.

FROM alpine:3.22

RUN apk add --no-cache curl nodejs npm

WORKDIR /usr/local/app

# Le docker-compose.yml lance nodemon en développement.
RUN npm install -g nodemon

COPY package*.json ./
RUN npm ci && npm cache clean --force

COPY . .

ENV PORT=80
EXPOSE 80

CMD ["node", "server.js"]
