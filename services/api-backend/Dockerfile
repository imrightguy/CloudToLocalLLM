ARG BASE_REGISTRY=cloudtolocalllm
FROM ${BASE_REGISTRY}/base:latest

# Switch to root to install dependencies
USER root

# Install deps using files in the build context (services/api-backend as context)
COPY package*.json ./
# Build tools for native modules (sqlite3) - with robust retry for network issues
RUN apt-get update && \
    (apt-get install -y python3 make g++ || \
    (echo "First attempt failed, retrying with --fix-missing..." && sleep 10 && apt-get update && apt-get install -y python3 make g++ --fix-missing) || \
    (echo "Second attempt failed, trying with different mirror..." && sleep 15 && sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && apt-get update && apt-get install -y python3 make g++ --fix-missing)) && \
    rm -rf /var/lib/apt/lists/*

RUN npm ci --omit=dev --ignore-scripts && npm rebuild sqlite3 && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for cloudtolocalllm user and ensure logs dir exists
RUN mkdir -p /app/logs && chown -R cloudtolocalllm:cloudtolocalllm /app

# Health port
EXPOSE 3000

# Run as non-root
USER cloudtolocalllm

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
