# --- Build Stage ---
FROM node:24-alpine AS builder

WORKDIR /app

# Install build dependencies for native modules (pg, etc.)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install ALL dependencies (production + dev for any build scripts)
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

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G nodejs -g nodejs nodejs

# Copy pruned node_modules and app from builder
COPY --from=builder /app /app

# Fix permissions
RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 8080

CMD ["npm", "start"]
