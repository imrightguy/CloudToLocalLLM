FROM node:24-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN apk add --no-cache python3 make g++
RUN npm ci --omit=dev

COPY . ./

FROM node:24-alpine

RUN apk add --no-cache curl

RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G nodejs -g nodejs nodejs

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000

CMD ["npm", "start"]
