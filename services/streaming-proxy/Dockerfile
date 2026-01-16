# Node.js streaming proxy
FROM node:24-alpine
WORKDIR /app

# Install deps using files in the build context (services/streaming-proxy as context)
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy application source
COPY . .

# Fix ownership for node user
RUN chown -R node:node /app

EXPOSE 3001
USER node

# Start with npm script to ensure proper environment
CMD ["npm", "start"]
