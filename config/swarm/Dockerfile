# Docker Swarm Web Image
# Multi-service container: Web frontend, API backend, and streaming proxy
FROM node:20-bookworm-slim

WORKDIR /app/code

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    curl \
    wget \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# ---- 1. API Backend ----
RUN mkdir -p /app/code/api-backend
COPY services/api-backend/package*.json /app/code/api-backend/
RUN cd /app/code/api-backend && npm ci --omit=dev

COPY services/api-backend /app/code/api-backend

# ---- 2. Streaming Proxy ----
RUN mkdir -p /app/code/streaming-proxy
COPY services/streaming-proxy/package*.json /app/code/streaming-proxy/
RUN cd /app/code/streaming-proxy && npm ci --omit=dev

COPY services/streaming-proxy /app/code/streaming-proxy

# ---- 3. Web Frontend ----
# Flutter web build output (created by 'flutter build web' in repo root)
RUN mkdir -p /app/code/web
COPY build/web /app/code/web

# ---- 4. Configuration ----

# Nginx configuration for serving the web frontend and proxying API
COPY config/swarm/nginx.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Supervisor configuration to run API, Streaming Proxy, and Nginx
COPY config/swarm/supervisor.conf /etc/supervisor/conf.d/cloudtolocalllm.conf

# Add startup script
COPY config/swarm/start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Create non-root user for running services
RUN groupadd -r cloudtolocalllm && useradd -r -g cloudtolocalllm cloudtolocalllm
RUN chown -R cloudtolocalllm:cloudtolocalllm /app/code

# Expose port for web traffic (nginx)
EXPOSE 8080

# Start script
CMD [ "/app/code/start.sh" ]
