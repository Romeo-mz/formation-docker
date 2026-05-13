FROM alpine:3.22

RUN apk add --no-cache curl nodejs npm tini

WORKDIR /usr/local/app

COPY package*.json ./

RUN npm ci --omit=dev && npm cache clean --force

COPY . .

ENV PORT=80
ENV NODE_ENV=production
EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
