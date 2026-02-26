# Unified Cloudron Custom App Dockerfile
# Based on Cloudron's Node.js 20 environment (Cloudron Base Image 4.2.0 is common)
FROM cloudron/base:4.2.0@sha256:46da2fffb36353ef714f97ae8e962bd2c212ca091108d768ba473078319a47f4

# We use the generic app directory for Cloudron
WORKDIR /app/code

# Ensure python/make/g++ for any native deps
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
# For the unified container, we assume the web flutter build was done previously in the CI 
# and the output is copied here. If not, it can be served dynamically. We will copy build/web.
RUN mkdir -p /app/code/web
# In CI, we will copy 'build/web' into 'web/build/web' context.
COPY web/build/web /app/code/web

# ---- 4. Configuration ----

# Nginx configuration for serving the web frontend and proxying API
COPY config/cloudron/nginx.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Supervisor configuration to run API, Streaming Proxy, and Nginx
COPY config/cloudron/supervisor.conf /etc/supervisor/conf.d/cloudtolocalllm.conf

# Add startup script
COPY config/cloudron/start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Fix permissions
RUN chown -R cloudron:cloudron /app/code

# Cloudron expects apps to listen on port 3000 by default (as per manifest)
EXPOSE 3000

# Start script
CMD [ "/app/code/start.sh" ]
