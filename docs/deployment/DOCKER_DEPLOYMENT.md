# Zoidbot Docker Compose Deployment Guide

**⚠️ DEVELOPMENT/TESTING ONLY**: This Docker Compose deployment is suitable for development, testing, and small-scale deployments. For production use, **Kubernetes deployment is strongly recommended**.

See [Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md) for all deployment options.

## Overview

This guide will help you deploy Zoidbot using Docker Compose with a complete stack including:

- **Web Application** (Flutter + Nginx)
- **API Backend** (Node.js with WebSocket tunnel support)
- **PostgreSQL Database** (Self-contained)
- **Nginx Reverse Proxy** (SSL termination)
- **Certbot** (Automatic SSL certificate management with Let's Encrypt)

## Prerequisites

### Server Requirements

- **Operating System**: Linux (Ubuntu 22.04+ or Debian 11+ recommended)
- **RAM**: Minimum 2GB, recommended 4GB+
- **Storage**: Minimum 20GB free space
- **Network**: Public IP address with open ports 80 and 443

### Software Requirements

- Docker (version 20.10+)
- Docker Compose (version 2.0+)
- Domain name with DNS pointing to your server

### Domain Configuration

Before deployment, configure your DNS with A records for:

- `yourdomain.com` → Your server IP
- `app.yourdomain.com` → Your server IP
- `api.yourdomain.com` → Your server IP

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Zoidbot.git
cd Zoidbot
```

### 2. Run the Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:

1. Check prerequisites
2. Create `.env` configuration
3. Request SSL certificates from Let's Encrypt
4. Build and deploy all services

### 3. Access Your Application

After deployment:

- **Web App**: https://yourdomain.com
- **App Interface**: https://app.yourdomain.com
- **API**: https://api.yourdomain.com

## Manual Deployment

If you prefer manual deployment or need to customize:

### 1. Create Environment File

```bash
cp env.template .env
```

Edit `.env` and configure:

```env
# Domain Configuration
DOMAIN=yourdomain.com
SSL_EMAIL=admin@yourdomain.com

# Database Configuration
POSTGRES_DB=zoidbot
POSTGRES_USER=appuser
POSTGRES_PASSWORD=your_secure_password_here

# Auth0 Configuration
JWT_ISSUER_DOMAIN=your-tenant.us.auth0.com
JWT_AUDIENCE=https://app.yourdomain.com

# JWT Configuration (generate with: openssl rand -base64 32)
JWT_SECRET=your_jwt_secret_here
```

### 2. Generate Secure Passwords

```bash
# Database password
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

# JWT secret
openssl rand -base64 32
```

### 3. Create Required Directories

```bash
mkdir -p certbot/conf certbot/www certbot/logs
```

### 4. Start Services Without SSL (First Time)

```bash
# First, start nginx and certbot to obtain certificates
docker compose -f docker-compose.production.yml up -d nginx

# Request SSL certificate
docker compose -f docker-compose.production.yml run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  --email your@email.com \
  --agree-tos \
  --no-eff-email \
  -d yourdomain.com \
  -d app.yourdomain.com \
  -d api.yourdomain.com
```

### 5. Start All Services

```bash
docker compose -f docker-compose.production.yml up -d
```

### 6. Verify Deployment

```bash
# Check service status
docker compose -f docker-compose.production.yml ps

# Check logs
docker compose -f docker-compose.production.yml logs -f

# Test endpoints
curl https://yourdomain.com
curl https://api.yourdomain.com/health
```

## Architecture

```
Internet
   ↓
Nginx (Port 80/443)
   ├─→ SSL Termination
   ├─→ Static Web Content
   │   └─→ Web Service (Flutter App) :8080
   │
   ├─→ API Requests (/api/*)
   │   └─→ API Backend Service :3000
   │       └─→ PostgreSQL :5432
   │
   └─→ WebSocket Tunnel (/ws/tunnel)
       └─→ API Backend Service :3000
           └─→ Windows Desktop App
               └─→ Local Ollama :11434
```

## Service Details

### Web Application

- **Container**: `zoidbot-web`
- **Technology**: Flutter (built to static files) + Nginx
- **Port**: 8080 (internal)
- **Health Check**: HTTP GET /health

### API Backend

- **Container**: `zoidbot-api-backend`
- **Technology**: Node.js Express
- **Port**: 3000 (internal)
- **Features**:
  - REST API endpoints
  - WebSocket tunnel server at `/ws/tunnel`
  - Auth0 JWT validation
  - PostgreSQL database connection
  - Tier-based user management
- **Health Check**: HTTP GET /health

### PostgreSQL Database

- **Container**: `zoidbot-postgres`
- **Version**: PostgreSQL 16 Alpine
- **Port**: 5432 (internal only)
- **Data**: Persisted in Docker volume `zoidbot_postgres_data`
- **Schema**: Auto-initialized from `services/api-backend/database/schema.pg.sql`

### Nginx Reverse Proxy

- **Container**: `zoidbot-nginx`
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Features**:
  - SSL/TLS termination
  - HTTP to HTTPS redirect
  - WebSocket proxying
  - Rate limiting
  - Security headers
  - Gzip compression

### Certbot

- **Container**: `zoidbot-certbot`
- **Function**: Automatic SSL certificate renewal
- **Schedule**: Checks for renewal every 12 hours

## Windows Desktop App Connection

### Prerequisites

1. Windows desktop app installed
2. Local Ollama running on `localhost:11434`

### Connection Steps

1. Start your local Ollama instance
2. Launch the Zoidbot desktop app
3. Sign in with your Auth0 credentials
4. Desktop app will connect to: `wss://api.yourdomain.com/ws/tunnel`
5. WebSocket tunnel established

### Troubleshooting Desktop Connection

- Check desktop app logs in system tray
- Verify Auth0 authentication is successful
- Ensure firewall allows outbound WebSocket connections
- Check API backend logs: `docker compose -f docker-compose.production.yml logs api-backend`

## Management Commands

### View Logs

```bash
# All services
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f api-backend
docker compose -f docker-compose.production.yml logs -f web
docker compose -f docker-compose.production.yml logs -f nginx
```

### Restart Services

```bash
# All services
docker compose -f docker-compose.production.yml restart

# Specific service
docker compose -f docker-compose.production.yml restart api-backend
```

### Stop Services

```bash
docker compose -f docker-compose.production.yml down
```

### Update Application

```bash
# Pull latest code
git pull

# Rebuild and restart
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d
```

### Database Backup

```bash
# Backup PostgreSQL database
docker compose -f docker-compose.production.yml exec postgres \
  pg_dump -U appuser zoidbot > backup_$(date +%Y%m%d).sql

# Restore from backup
docker compose -f docker-compose.production.yml exec -T postgres \
  psql -U appuser zoidbot < backup_20240101.sql
```

### SSL Certificate Renewal

Certificates auto-renew, but to force renewal:

```bash
docker compose -f docker-compose.production.yml run --rm certbot renew
docker compose -f docker-compose.production.yml restart nginx
```

## Monitoring

### Health Checks

```bash
# Web application
curl https://yourdomain.com/health

# API backend
curl https://api.yourdomain.com/health

# Check WebSocket tunnel (requires auth token)
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
  -H "Sec-WebSocket-Version: 13" \
  https://api.yourdomain.com/ws/tunnel?token=YOUR_JWT_TOKEN
```

### Service Status

```bash
docker compose -f docker-compose.production.yml ps
```

### Resource Usage

```bash
docker stats
```

## Troubleshooting

### SSL Certificate Issues

```bash
# Check certificate status
docker compose -f docker-compose.production.yml exec certbot certbot certificates

# Test certificate renewal (dry run)
docker compose -f docker-compose.production.yml run --rm certbot renew --dry-run
```

### Database Connection Issues

```bash
# Access PostgreSQL shell
docker compose -f docker-compose.production.yml exec postgres \
  psql -U appuser -d zoidbot

# Check database tables
\dt

# Exit PostgreSQL
\q
```

### API Backend Issues

```bash
# Check API logs
docker compose -f docker-compose.production.yml logs api-backend

# Restart API backend
docker compose -f docker-compose.production.yml restart api-backend

# Access API container shell
docker compose -f docker-compose.production.yml exec api-backend sh
```

### Nginx Issues

```bash
# Test nginx configuration
docker compose -f docker-compose.production.yml exec nginx nginx -t

# Reload nginx configuration
docker compose -f docker-compose.production.yml exec nginx nginx -s reload

# Check nginx access logs
docker compose -f docker-compose.production.yml logs nginx
```

## Security Considerations

1. **Change Default Passwords**: Always use strong, unique passwords for database and JWT secrets
2. **Firewall Configuration**: Only expose ports 80 and 443
3. **Regular Updates**: Keep Docker images and application code updated
4. **SSL/TLS**: Let's Encrypt certificates auto-renew every 90 days
5. **Database Backups**: Schedule regular database backups
6. **Monitoring**: Set up monitoring and alerting for production deployments

## Performance Optimization

### Resource Limits

Edit `docker-compose.production.yml` to adjust resource limits:

```yaml
services:
  api-backend:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

### Database Tuning

For high-load scenarios, customize PostgreSQL configuration:

```bash
# Create custom postgresql.conf
# Mount it in docker-compose.production.yml
```

## Alternative: Kubernetes Deployment

For production deployments, **Kubernetes is recommended** over Docker Compose:

- ✅ Better scalability and high availability
- ✅ Auto-scaling capabilities
- ✅ More robust networking and service discovery
- ✅ Platform-agnostic (works with any Kubernetes cluster)
- ✅ Supports both managed and self-hosted clusters

**See:**

- [Kubernetes Quick Start](../k8s/README.md) - DigitalOcean example
- [Kubernetes README](../k8s/README.md) - Complete Kubernetes guide
- [Self-Hosted Kubernetes Guide](../KUBERNETES_SELF_HOSTED_GUIDE.md) - For businesses

## Support

For issues or questions:

- GitHub Issues: https://github.com/yourusername/Zoidbot/issues
- Documentation: https://docs.zoidbot.online
- Email: support@zoidbot.online
