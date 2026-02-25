#!/bin/bash
# This script manages the issuance and renewal of SSL certificates using Certbot
# Obtains a cert for cloudtolocalllm.online via HTTP (webroot) validation,
# and a wildcard cert for *.cloudtolocalllm.online via DNS validation.
# It is designed to be run as a non-root user with permissions to certbot directories.

# --- IMPORTANT PERMISSIONS NOTE ---
# This script is intended to be run by a user or process that has:
#   1. Permission to execute 'certbot'.
#   2. Write permissions to the host directories mounted for Certbot configuration, webroot, and logs.
#   3. Permissions to execute 'docker-compose' and 'docker exec' commands (e.g., user is in 'docker' group or has root privileges).
#      This script uses 'sudo' for docker-compose commands to ensure permissions if not run as root,
#      assuming sudo access is configured for the executing user if necessary.
# --- END PERMISSIONS NOTE ---

set -euo pipefail # Exit on error, unset variable, or pipe failure

# --- Configuration ---
EMAIL="christopher.maltais@gmail.com" # Email for Let's Encrypt account
DOMAIN_NAME="cloudtolocalllm.online"    # The domain to issue the certificate for
PROJECT_DIR="/opt/CloudToLocalLLM"    # Absolute path to your project's root on the host machine

# Certbot related paths
CERTBOT_CONFIG_SUBDIR="certbot/conf"
CERTBOT_WEBROOT_SUBDIR="certbot/www"
CERTBOT_LOGS_SUBDIR="logs/certbot"

# Construct full paths
CERT_CONFIG_DIR="$PROJECT_DIR/$CERTBOT_CONFIG_SUBDIR"
WEBROOT_PATH="$PROJECT_DIR/$CERTBOT_WEBROOT_SUBDIR"
CERTBOT_LOG_DIR="$PROJECT_DIR/$CERTBOT_LOGS_SUBDIR"

# Output Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---

echo_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

ensure_dependencies() {
    local missing_deps=0
    for dep in "$@"; do
        if ! command -v "$dep" &>/dev/null; then
            echo_color "$RED" "Error: Dependency '$dep' not found."
            missing_deps=$((missing_deps + 1))
        else
            echo_color "$GREEN" "Dependency '$dep' found."
        fi
    done
    if [ "$missing_deps" -gt 0 ]; then
        echo_color "$RED" "Please install missing dependencies and try again."
        exit 1
    fi
}

ensure_certbot_dirs() {
    echo_color "$YELLOW" "Ensuring Certbot directories exist:"
    echo_color "$YELLOW" "  Config dir: $CERT_CONFIG_DIR"
    echo_color "$YELLOW" "  Webroot dir: $WEBROOT_PATH/.well-known/acme-challenge"
    echo_color "$YELLOW" "  Logs dir: $CERTBOT_LOG_DIR"

    mkdir -p "$CERT_CONFIG_DIR"
    mkdir -p "$WEBROOT_PATH/.well-known/acme-challenge"
    mkdir -p "$CERTBOT_LOG_DIR"
    
    # Ensure the user has write permissions
    if [ ! -w "$CERT_CONFIG_DIR" ] || [ ! -w "$WEBROOT_PATH" ] || [ ! -w "$CERTBOT_LOG_DIR" ]; then
        echo_color "$RED" "Error: You don't have write permissions to the certbot directories."
        echo_color "$YELLOW" "Please run: sudo chown -R $(whoami):$(whoami) $CERT_CONFIG_DIR $WEBROOT_PATH $CERTBOT_LOG_DIR"
        exit 1
    fi
    
    echo_color "$GREEN" "Certbot directories checked/created."
}

run_webroot_certbot() {
    echo_color "$BLUE" "Obtaining certificate for $DOMAIN_NAME using HTTP (webroot) validation..."
    echo_color "$YELLOW" "Certbot will attempt to place a challenge file in: $WEBROOT_PATH/.well-known/acme-challenge/"

    set +e
    certbot certonly \
        --webroot \
        -w "$WEBROOT_PATH" \
        -d "$DOMAIN_NAME" \
        --email "$EMAIL" \
        --config-dir "$CERT_CONFIG_DIR" \
        --work-dir "$CERT_CONFIG_DIR/work" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        --agree-tos \
        --staging \
        "$@"
    local certbot_exit_code=$?
    set -e

    if [ $certbot_exit_code -eq 0 ]; then
        echo_color "$GREEN" "Regular certificate for $DOMAIN_NAME obtained successfully!"
    else
        echo_color "$RED" "Failed to obtain regular certificate. Check the logs in $CERTBOT_LOG_DIR"
        return $certbot_exit_code
    fi
}

run_dns_certbot() {
    echo_color "$BLUE" "Obtaining wildcard certificate for *.$DOMAIN_NAME using DNS validation..."
    echo_color "$YELLOW" "This will require you to add a TXT record to your DNS provider."
    echo_color "$YELLOW" "The script will pause and wait for you to add the TXT record."

    set +e
    certbot certonly \
        --manual \
        --preferred-challenges dns \
        --email "$EMAIL" \
        --config-dir "$CERT_CONFIG_DIR" \
        --work-dir "$CERT_CONFIG_DIR/work" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        --agree-tos \
        --staging \
        -d "*.${DOMAIN_NAME}" \
        "$@"
    local certbot_exit_code=$?
    set -e

    if [ $certbot_exit_code -eq 0 ]; then
        echo_color "$GREEN" "Wildcard certificate obtained successfully!"
        echo_color "$YELLOW" "To obtain production certificates, run this script again with --production flag."
    else
        echo_color "$RED" "Failed to obtain wildcard certificate. Check the logs in $CERTBOT_LOG_DIR"
    fi
    return $certbot_exit_code
}

# --- Main Script Logic ---
main() {
    echo_color "$GREEN" "--- SSL Certificate Management Script (Staging Mode) ---"
    echo_color "$YELLOW" "[DEBUG] This is the latest manage_ssl.sh version: $(date)"

    # --- Certbot Symlink Structure Cleanup ---
    LIVE_DIR="$CERT_CONFIG_DIR/live/$DOMAIN_NAME"
    ARCHIVE_DIR="$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"
    RENEWAL_CONF="$CERT_CONFIG_DIR/../renewal/$DOMAIN_NAME.conf"

    # --- Remove ALL existing certificates before doing anything ---
    echo_color "$YELLOW" "[CLEANUP] Removing all existing cert, archive, and renewal files for $DOMAIN_NAME before requesting a new certificate."
    rm -rf "$CERT_CONFIG_DIR/live/$DOMAIN_NAME"*
    rm -rf "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"*
    rm -f "$CERT_CONFIG_DIR/../renewal/$DOMAIN_NAME"*.conf

    ensure_dependencies "certbot"
    ensure_certbot_dirs

    # Step 1: Get regular certificate using HTTP validation
    run_webroot_certbot "$@"

    # Step 2: Get wildcard certificate using DNS validation
    run_dns_certbot "$@"

    # Reload nginx to apply the new certificates
    echo "Reloading nginx to apply the new certificates..."
    sed -i 's|ssl_certificate /etc/nginx/ssl/default.pem;|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|g' /opt/CloudToLocalLLM/config/nginx/nginx-webapp-internal.conf
    sed -i 's|ssl_certificate_key /etc/nginx/ssl/default.key;|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|g' /opt/CloudToLocalLLM/config/nginx/nginx-webapp-internal.conf
    docker compose restart webapp
    echo "Nginx reloaded successfully."
}

# Run the main function
main "$@" 