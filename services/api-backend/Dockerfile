FROM node:24-alpine AS builder

WORKDIR /app

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci --omit=dev

# Copy source code (respects .dockerignore)
COPY . .

# --- Runner Stage ---
FROM node:24-alpine

WORKDIR /app

# Install utilities for healthchecks
RUN apk add --no-cache curl wget bash

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G nodejs -g nodejs nodejs

# Copy from builder
COPY --from=builder /app /app

# Fix permissions
RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 8080

CMD ["npm", "start"]
