# Node.js streaming proxy
FROM node:24-alpine
WORKDIR /app

# Create zoidbot user with UID 1001
RUN addgroup -g 1001 -S zoidbot && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G zoidbot -g zoidbot zoidbot

# Install deps using files in the build context
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership
RUN chown -R zoidbot:zoidbot /app

# Install wget for health checks
RUN apk add --no-cache wget

EXPOSE 3001
USER zoidbot

# Health check - verify streaming proxy is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:3001/health || exit 1

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
