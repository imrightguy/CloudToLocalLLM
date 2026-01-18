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

# Create cloudtolocalllm user with UID 1001
RUN addgroup -g 1001 -S cloudtolocalllm && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G cloudtolocalllm -g cloudtolocalllm cloudtolocalllm

# Copy pruned node_modules and app from builder
COPY --from=builder /app /app

# Fix permissions
RUN mkdir -p /app/logs && chown -R cloudtolocalllm:cloudtolocalllm /app

USER cloudtolocalllm

EXPOSE 8080

CMD ["npm", "start"]
