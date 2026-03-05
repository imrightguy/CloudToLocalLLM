#!/bin/bash
# CloudToLocalLLM Deployment Script
# Usage: ./scripts/deployment/deploy.sh [environment]
# Environment: prod (default) or dev

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-prod}"
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
STACK_NAME="cloudtolocalllm"
ENV_FILE=".env"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}CloudToLocalLLM Deployment${NC}"
echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}======================================${NC}"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Copy docker-compose.env.example to .env and fill in the values${NC}"
    exit 1
fi

# Load environment variables
export $(cat "$ENV_FILE" | grep -v '^#' | xargs)

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Check if Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${YELLOW}Docker Swarm is not active. Initializing...${NC}"
    docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
fi

# Create required networks
echo -e "${GREEN}Creating networks...${NC}"
docker network create frontend --driver overlay 2>/dev/null || echo "Network 'frontend' already exists"
docker network create backend --driver overlay 2>/dev/null || echo "Network 'backend' already exists"

# Pull latest images
echo -e "${GREEN}Pulling latest images...${NC}"
docker-compose -f "$COMPOSE_FILE" pull

# Deploy the stack
echo -e "${GREEN}Deploying stack...${NC}"
docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Show service status
echo -e "${GREEN}Service Status:${NC}"
docker stack services "$STACK_NAME"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Services:"
echo "  - API Backend: http://localhost:8080"
echo "  - Streaming Proxy: http://localhost:3001"
echo "  - Traefik Dashboard: http://localhost:8080"
echo "  - Grafana: http://localhost:3000 (if deployed)"
echo ""
echo "View logs:"
echo "  docker service logs -f ${STACK_NAME}_api-backend"
echo ""
echo "Scale services:"
echo "  docker service scale ${STACK_NAME}_api-backend=3"
