FROM node:24-alpine AS builder

WORKDIR /app

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

COPY package*.json ./
# Use npm ci to ensure exact versions from package-lock.json
# Including dev dependencies for the build process (like eslint/prettier if they are part of prepublish)
# and then pruning is usually better, but here we just need a clean install.
RUN npm ci

# Copy source code (respects .dockerignore)
COPY . .

# Prune dev dependencies before copying to final image
RUN npm prune --omit=dev

# --- Runner Stage ---
FROM node:24-alpine

WORKDIR /app

# Install utilities for healthchecks
RUN apk add --no-cache curl wget bash

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G nodejs -g nodejs nodejs

# Copy EVERYTHING from builder stage (the app and pruned node_modules)
COPY --from=builder /app /app

# Fix permissions
RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 8080

CMD ["npm", "start"]
