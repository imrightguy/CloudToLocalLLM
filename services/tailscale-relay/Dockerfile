FROM node:20-alpine

WORKDIR /app

COPY services/tailscale-relay/package*.json ./
RUN npm install --only=production

COPY services/tailscale-relay/src ./src

EXPOSE 3002

CMD ["node", "src/server.js"]
