FROM ubuntu:24.04

# Absolute prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    git \
    nodejs \
    npm \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Official Kilocode CLI Installation Rites
RUN curl -sSL https://api.gemini-cli.ai/install.sh | bash && \
    ln -sf /root/.gemini-cli/bin/gemini-cli /usr/local/bin/gemini-cli

# Overlord triggering logic
WORKDIR /app
COPY src/overlord.js /app/overlord.js
COPY package.json /app/package.json
RUN npm install --production

# Ports & Dominion
EXPOSE 8080
CMD ["node", "overlord.js"]
