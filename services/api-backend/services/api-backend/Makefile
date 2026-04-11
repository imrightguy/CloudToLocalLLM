# ── ImmoGestion API Backend ──────────────────────────────────────────
# Convenience targets for local development and deployment
# ─────────────────────────────────────────────────────────────────────

.PHONY: dev test lint migrate seed build deploy logs shell

# ── Development ──────────────────────────────────────────────────────
dev:			## Start dev server with nodemon
	npm run dev

test:			## Run test suite
	npm test

test:coverage:		## Run tests with coverage
	npm run test:coverage

lint:			## Lint source files
	npm run lint

lint:fix:		## Auto-fix lint issues
	npm run lint:fix

# ── Database ─────────────────────────────────────────────────────────
migrate:		## Run database migrations
	npm run migrate

seed:			## Seed initial data
	npm run seed

# ── Docker ───────────────────────────────────────────────────────────
build:			## Build Docker image
	docker compose build

up:			## Start all services (postgres + api)
	docker compose up -d

down:			## Stop all services
	docker compose down

restart:		## Restart all services
	docker compose restart

logs:			## Tail logs from all services
	docker compose logs -f

logs:api:		## Tail API logs
	docker compose logs -f api

logs:db:		## Tail database logs
	docker compose logs -f postgres

ps:			## Show running containers
	docker compose ps

# ── Deployment ───────────────────────────────────────────────────────
# These targets assume you have SSH access to the VPS
# Usage: make deploy VPS_HOST=root@31.97.140.7

VPS_HOST ?= root@31.97.140.7
VPS_PATH ?= /opt/immogestion

deploy:			## Deploy to VPS (pull + rebuild + restart)
	ssh $(VPS_HOST) "cd $(VPS_PATH)/services/api-backend && git pull && docker compose up -d --build"

deploy:setup:		## First-time VPS setup (clone repo + configure)
	ssh $(VPS_HOST) "mkdir -p $(VPS_PATH) && cd $(VPS_PATH) && git clone https://github.com/imrightguy/ImmoGestion.git ."
	ssh $(VPS_HOST) "cd $(VPS_PATH)/services/api-backend && cp .env.production.template .env.production"
	@echo "Now edit .env.production on the VPS: ssh $(VPS_HOST) 'nano $(VPS_PATH)/services/api-backend/.env.production'"

deploy:logs:		## Tail VPS deployment logs
	ssh $(VPS_HOST) "cd $(VPS_PATH)/services/api-backend && docker compose logs -f --tail=100"

deploy:status:		## Check VPS container status
	ssh $(VPS_HOST) "cd $(VPS_PATH)/services/api-backend && docker compose ps"

deploy:health:		## Health check on VPS
	ssh $(VPS_HOST) "curl -s http://localhost:3000/health | python3 -m json.tool"

# ── Utility ──────────────────────────────────────────────────────────
shell:			## Open a shell in the API container
	docker compose exec api sh

db:shell:		## Open psql in the database container
	docker compose exec postgres psql -U postgres -d immogestion

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
