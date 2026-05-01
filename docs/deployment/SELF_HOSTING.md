# Self-Hosting Guide

This guide explains how to deploy CloudToLocalLLM for self-hosted, privacy-first operation.

## Overview

CloudToLocalLLM is designed to run primarily on local devices with optional cloud/SaaS features. Self-hosting allows you to run backend services on your own infrastructure while maintaining control over your data.

Current orientation is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are optional support model providers for app-owned memory/background features, not primary app runtimes. Remote agent runtimes and cloud connectors should live inside the user's Tailscale tailnet where possible.

## Prerequisites

- Docker and Docker Compose
- Node.js >=22 <25 (for backend development)
- Flutter SDK >=3.5.0 <4.0.0 (for frontend development)
- PostgreSQL >=14
- Redis >=7
- Git

## Architecture Overview

When self-hosted, CloudToLocalLLM consists of:

1. **Frontend**: Flutter application (runs locally on user's device)
2. **Backend Services** (optional, for cloud features):
   - API Backend (Express 5, PostgreSQL)
   - Tailscale Relay and cloud connector support for secure device mesh
   - Streaming Proxy (legacy/fallback WebSocket proxy for tunnel-heavy paths)
   - Auth Backend (JWT validation)
   - SDK (TypeScript service SDK)

## Deployment Options

### Option 1: Local-First Only (Recommended for Privacy)

Run only the Flutter frontend with local SQLite storage. No backend services required.

```bash
# Get the code
git clone https://github.com/your-repo/cloudtolocalllm.git
cd cloudtolocalllm

# Install Flutter dependencies
flutter pub get

# Run the app (local-first mode)
flutter run -d linux  # or windows, macos, chrome
```

In this mode:
- All data stored locally via encrypted SQLite (Drift)
- No external dependencies
- Full functionality for the selected local agent runtime where its capabilities are available
- Optional features requiring backend services are disabled

### Option 2: Full Self-Hosted Stack

Run both frontend and backend services on your infrastructure.

#### Step 1: Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration:
# - Database connection strings
# - Redis configuration
# - JWT secrets
# - API keys for external LLM providers (optional)
# - Tailscale configuration for secure device mesh
```

#### Step 2: Start Infrastructure Services

```bash
# Start PostgreSQL and Redis
docker-compose up -d postgres redis

# Initialize database
npm run db:migrate
```

#### Step 3: Start Backend Services

```bash
# Start backend services. Streaming proxy is legacy/fallback for tunnel-heavy paths.
docker-compose up -d api-backend streaming-proxy tailscale-relay auth-backend
```

#### Step 4: Build and Configure Frontend

```bash
# Get Flutter dependencies
flutter pub get

# Configure frontend to point to your self-hosted backend
# Update lib/config/endpoint.dart with your backend URLs

# Run the app
flutter run -d linux  # or your target platform
```

#### Step 5: Production Build

```bash
# Build frontend for production
flutter build linux --release  # or windows, macos, web

# Build backend (if making changes)
cd services/api-backend
npm run build
```

## Configuration

### Environment Variables

Key environment variables in `.env`:

```
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=cloudtolocalllm
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=cloudtolocalllm

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT
JWT_ACCESS_TOKEN_SECRET=your_access_token_secret
JWT_REFRESH_TOKEN_SECRET=your_refresh_token_secret

# API
API_PORT=8080
STREAMING_PROXY_PORT=3001

# External LLM Providers (optional)
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
# Add others as needed

# Tailscale (optional)
TAILSCALE_AUTHKEY=your_tailscale_authkey
```

### Flutter Configuration

Edit `lib/config/endpoint.dart` to point to your self-hosted services:

```dart
class EndpointConfig {
  static String get apiBaseUrl => 'http://your-server:8080/api';
  static String get streamingProxyUrl => 'ws://your-server:3001';
  static String get authBaseUrl => 'http://your-server:8080/auth';
  // ... other endpoints
}
```

## Security Considerations

1. **Network Security**:
   - Use firewalls to restrict access to backend services
   - Consider using a reverse proxy (NGINX, Traefik) with SSL termination
   - Enable CORS restrictions on API endpoints

2. **Data Protection**:
   - Enable full-disk encryption on your server
   - Regularly backup PostgreSQL database
   - Use strong, unique passwords for all services
   - Consider enabling PostgreSQL column-level encryption for sensitive data

3. **Updates**:
   - Regularly update Docker images and dependencies
   - Monitor security advisories for used technologies
   - Keep Flutter and Node.js versions current

## Maintenance

### Backups

```bash
# Backup PostgreSQL database
pg_dump -h localhost -U cloudtolocalllm cloudtolocalllm > backup.sql

# Backup Redis (optional, mainly for caching)
redis-cli BGSAVE
```

### Logs

Backend services log to stdout/stderr, captured by Docker Compose:

```bash
# View logs
docker-compose logs -f api-backend
docker-compose logs -f streaming-proxy
```

### Updates

```bash
# Pull latest code
git pull origin main

# Update Flutter dependencies
flutter pub get

# Update Node.js dependencies
npm ci  # in each service directory

# Apply database migrations
npm run db:migrate

# Restart services
docker-compose restart
```

## Troubleshooting

### Common Issues

1. **Database Connection Failures**:
   - Verify PostgreSQL is running: `docker-compose ps postgres`
   - Check `.env` database credentials
   - Ensure database has been migrated: `npm run db:migrate`

2. **Service Startup Failures**:
   - Check logs: `docker-compose logs <service-name>`
   - Verify required environment variables are set
   - Check port conflicts (8080 for API, 3001 for streaming proxy)

3. **Frontend Cannot Connect to Backend**:
   - Verify `lib/config/endpoint.dart` points to correct URLs
   - Check network connectivity between frontend and backend devices
   - Ensure backend services are exposed on the correct network interface

## Getting Help

- Check the [Troubleshooting Guide](../user-guide/TROUBLESHOOTING.md)
- Review existing tests in `test/api-backend/` for service behavior
- Consult the [API Reference](../development/API_DOCUMENTATION.md)
- Join community forums for self-hosting discussions

## Support

This is community-supported software. For enterprise support options, please refer to the project's funding and sponsorship page.
