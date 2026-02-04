# --- Build Stage ---
FROM node:24-alpine AS builder

WORKDIR /app

# Install build dependencies for native modules (pg, etc.)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install ALL dependencies
RUN npm ci

# Copy source code
COPY . .

# Prune dev dependencies
RUN npm prune --omit=dev

# --- Runner Stage ---
FROM node:24-alpine

WORKDIR /app

# Install runtime utilities
RUN apk add --no-cache curl wget bash

# Create zoidbot user with UID 1001
RUN addgroup -g 1001 -S zoidbot && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G zoidbot -g zoidbot zoidbot

# Copy pruned node_modules and app from builder
COPY --from=builder /app /app

# Fix permissions
RUN mkdir -p /app/logs && chown -R zoidbot:zoidbot /app

USER zoidbot

EXPOSE 8080

# Health check - verify API is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/health || exit 1

CMD ["npm", "start"]
