# Node.js streaming proxy
FROM node:24-alpine
WORKDIR /app

# Create cloudtolocalllm user with UID 1001
RUN addgroup -g 1001 -S cloudtolocalllm && \
    adduser -S -D -H -u 1001 -h /app -s /bin/sh -G cloudtolocalllm -g cloudtolocalllm cloudtolocalllm

# Install deps using files in the build context
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership
RUN chown -R cloudtolocalllm:cloudtolocalllm /app

EXPOSE 3001
USER cloudtolocalllm

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
