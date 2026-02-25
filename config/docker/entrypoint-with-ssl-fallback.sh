#!/bin/sh
set -e

CERT_DIR="/etc/letsencrypt/live/cloudtolocalllm.online"
FALLBACK_CERT="/etc/nginx/ssl/selfsigned.crt"
FALLBACK_KEY="/etc/nginx/ssl/selfsigned.key"

# Create fallback SSL directory if needed
mkdir -p /etc/nginx/ssl
mkdir -p /var/www/certbot/.well-known/acme-challenge

# Set permissions for certbot directory (only if writable)
if [ -w /var/www/certbot ]; then
  chmod -R 755 /var/www/certbot 2>/dev/null || echo "[entrypoint] Could not set permissions on /var/www/certbot"
else
  echo "[entrypoint] /var/www/certbot is not writable, skipping permission changes"
fi

# Check if real Let's Encrypt certificates exist
if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
  echo "[entrypoint] Real Let's Encrypt certificates found, using them."
  echo "[entrypoint] Configuration already mounted with correct certificate paths."
else
  echo "[entrypoint] Real certs not found, generating self-signed fallback certificates..."
  # Generate self-signed certificates
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$FALLBACK_KEY" \
    -out "$FALLBACK_CERT" \
    -subj "/CN=cloudtolocalllm.online" \
    2>/dev/null || echo "[entrypoint] Self-signed cert generation failed, continuing..."

  # Create Let's Encrypt directory structure and link self-signed certs
  mkdir -p "$CERT_DIR"
  ln -sf "$FALLBACK_CERT" "$CERT_DIR/fullchain.pem"
  ln -sf "$FALLBACK_KEY" "$CERT_DIR/privkey.pem"

  echo "[entrypoint] Self-signed certificates created as fallback."
  echo "[entrypoint] Symbolic links created for nginx configuration compatibility."
  echo "[entrypoint] WARNING: Using self-signed certificates. Configuration may need to be updated manually for production use."
fi

# Create a test file in the ACME challenge directory (only if writable)
if [ -w /var/www/certbot/.well-known/acme-challenge ]; then
  echo "acme-challenge-test" > /var/www/certbot/.well-known/acme-challenge/test.txt 2>/dev/null || echo "[entrypoint] Could not create test file"
  chmod 644 /var/www/certbot/.well-known/acme-challenge/test.txt 2>/dev/null || echo "[entrypoint] Could not set test file permissions"
else
  echo "[entrypoint] ACME challenge directory is not writable, skipping test file creation"
fi

echo "[entrypoint] ACME challenge directory is ready for Let's Encrypt verification."
echo "[entrypoint] Starting Nginx..."

# Start nginx
exec nginx -g 'daemon off;' 