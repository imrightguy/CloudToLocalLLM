FROM node:24-alpine

WORKDIR /app

# Install runtime utilities and build tools for native modules
RUN apk add --no-cache curl wget bash python3 make g++

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev if needed for build steps)
# Then prune to keep image small
RUN npm ci && npm prune --omit=dev

# Copy application source
COPY . .

# Ensure logs directory exists and set permissions
RUN mkdir -p logs && chown -R node:node /app

USER node

EXPOSE 8080

CMD ["npm", "start"]
