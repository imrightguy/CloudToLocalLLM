#!/bin/bash

# CloudToLocalLLM Let's Encrypt Certificate Setup Script
# This script sets up and manages Let's Encrypt certificates for cloudtolocalllm.online

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="cloudtolocalllm.online"
EMAIL="admin@cloudtolocalllm.online"
WEBROOT_PATH="/var/www/certbot"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo_color "$RED" "This script should not be run as root for security reasons."
        echo_color "$YELLOW" "Please run as the cloudllm user."
        exit 1
    fi
}

# Function to check if Docker and Docker Compose are available
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo_color "$RED" "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        echo_color "$RED" "Docker Compose is not available"
        exit 1
    fi
}

# Function to check if the webapp container is running
check_webapp_running() {
    if ! docker compose ps | grep -q "CloudToLocalLLM-webapp.*Up"; then
        echo_color "$YELLOW" "Starting webapp container for certificate validation..."
        docker compose up -d webapp
        sleep 10
    fi
}

# Function to test ACME challenge accessibility for all domains
precheck_acme_challenge() {
    local testfile="/opt/CloudToLocalLLM/certbot/www/.well-known/acme-challenge/testfile"
    local teststr="test-$(date +%s)"
    
    # Create directory if it doesn't exist
    mkdir -p "/opt/CloudToLocalLLM/certbot/www/.well-known/acme-challenge"
    
    echo "$teststr" > "$testfile"
    chmod 644 "$testfile"
    
    local failed=0
    for d in cloudtolocalllm.online www.cloudtolocalllm.online app.cloudtolocalllm.online mail.cloudtolocalllm.online; do
        echo -n "[Precheck] Testing $d: "
        local result=$(curl -s -m 5 "http://$d/.well-known/acme-challenge/testfile")
        if [ "$result" = "$teststr" ]; then
            echo "OK"
        else
            echo "FAILED (got: $result)"
            echo "[INFO] This is expected if DNS is not yet pointing to this server."
            echo "[INFO] Make sure your domain's DNS records point to this server's IP address."
            failed=1
        fi
    done
    rm -f "$testfile"
    
    if [ $failed -ne 0 ]; then
        echo "[WARNING] ACME challenge precheck failed for one or more domains."
        echo "[WARNING] This could be due to DNS not being properly configured yet."
        echo "[WARNING] You can continue, but Let's Encrypt certificate acquisition may fail."

        # Check if running in automated mode (no TTY)
        if [ ! -t 0 ]; then
            echo "[INFO] Running in automated mode, continuing with certificate acquisition attempt..."
        else
            echo "[INFO] Would you like to continue anyway? (y/n)"
            read -r response
            if [[ "$response" != "y" && "$response" != "Y" ]]; then
                echo "[INFO] Aborting. Please fix DNS configuration and try again."
                exit 1
            fi
            echo "[INFO] Continuing with certificate acquisition attempt..."
        fi
    fi
}

# Function to obtain Let's Encrypt certificate
obtain_certificate() {
    echo_color "$BLUE" "Obtaining Let's Encrypt certificate for $DOMAIN..."

    # Check if containers are running
    if ! docker compose ps | grep -q "CloudToLocalLLM-webapp.*Up"; then
        echo_color "$RED" "Webapp container is not running. Cannot obtain certificates."
        echo_color "$YELLOW" "Starting webapp container..."
        docker compose up -d webapp
        sleep 10
    fi

    # Ensure webroot directory exists
    echo_color "$BLUE" "Creating webroot directory..."
    mkdir -p "/opt/CloudToLocalLLM/certbot/www/.well-known/acme-challenge"
    chmod -R 755 "/opt/CloudToLocalLLM/certbot/www"

    echo_color "$BLUE" "Attempting initial certificate acquisition..."
    echo_color "$YELLOW" "This may take a few minutes..."

    # Run certbot to obtain certificate with timeout
    echo_color "$BLUE" "Running certbot..."
    
    # Obtain production certificate directly (no staging test)
    echo_color "$BLUE" "Obtaining production Let's Encrypt certificate..."
    timeout 300 docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT_PATH" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN" \
        -d "app.$DOMAIN" \
        -d "api.$DOMAIN" \
        -d "docs.$DOMAIN" \
        -d "mail.$DOMAIN" 2>&1

    local cert_result=$?

    if [ $cert_result -eq 0 ]; then
        echo_color "$GREEN" "Production certificate obtained successfully!"
        return 0
    elif [ $cert_result -eq 124 ]; then
        echo_color "$RED" "Certificate acquisition timed out after 5 minutes"
        return 1
    else
        echo_color "$RED" "Certificate acquisition failed with code $cert_result"
        echo_color "$YELLOW" "This could be due to DNS not being properly configured yet."
        echo_color "$YELLOW" "Make sure your domain's DNS records point to this server's IP address."
        return 1
    fi
}

# Function to test certificate renewal
test_renewal() {
    echo_color "$BLUE" "Testing certificate renewal..."

    docker compose run --rm certbot renew --dry-run

    if [ $? -eq 0 ]; then
        echo_color "$GREEN" "Certificate renewal test passed!"
        return 0
    else
        echo_color "$RED" "Certificate renewal test failed"
        return 1
    fi
}

# Function to restart webapp to apply new certificates
restart_webapp() {
    echo_color "$BLUE" "Restarting webapp to apply new certificates..."
    docker compose restart webapp
    echo_color "$GREEN" "Webapp restarted successfully!"
}

# Function to check certificate status
check_certificate() {
    echo_color "$BLUE" "Checking certificate status..."

    if docker compose run --rm certbot certificates | grep -q "$DOMAIN"; then
        echo_color "$GREEN" "Certificate found for $DOMAIN"
        docker compose run --rm certbot certificates
        return 0
    else
        echo_color "$YELLOW" "No certificate found for $DOMAIN"
        return 1
    fi
}

# Function to setup automatic renewal
setup_renewal() {
    echo_color "$BLUE" "Setting up automatic certificate renewal..."

    # Create renewal script
    cat > /tmp/renew_certs.sh << 'EOF'
#!/bin/bash
cd /opt/CloudToLocalLLM
docker compose run --rm certbot renew --quiet
docker compose restart webapp
EOF

    # Move to proper location and set permissions
    sudo mv /tmp/renew_certs.sh /etc/cron.daily/renew-CloudToLocalLLM-certs
    sudo chmod +x /etc/cron.daily/renew-CloudToLocalLLM-certs

    echo_color "$GREEN" "Automatic renewal setup complete!"
    echo_color "$YELLOW" "Certificates will be renewed daily if needed."
}

# Main function
main() {
    echo_color "$BLUE" "CloudToLocalLLM Let's Encrypt Certificate Setup"
    echo_color "$BLUE" "=============================================="

    check_root
    check_docker

    precheck_acme_challenge

    case "${1:-setup}" in
        "setup")
            check_webapp_running
            if obtain_certificate; then
                restart_webapp
                setup_renewal
                echo_color "$GREEN" "Certificate setup complete!"
                exit 0
            else
                echo_color "$YELLOW" "Certificate setup failed, but continuing deployment..."
                echo_color "$YELLOW" "You can try again later with: ./scripts/ssl/setup_letsencrypt.sh setup"
                echo_color "$YELLOW" "The application will work with HTTP for now."
                exit 0  # Don't fail the deployment, just continue without SSL
            fi
            ;;
        "renew")
            if obtain_certificate; then
                restart_webapp
                echo_color "$GREEN" "Certificate renewal complete!"
            else
                echo_color "$RED" "Certificate renewal failed!"
                exit 1
            fi
            ;;
        "test")
            test_renewal
            ;;
        "status")
            check_certificate
            ;;
        "help"|"-h"|"--help")
            echo_color "$BLUE" "Usage: $0 [setup|renew|test|status|help]"
            echo_color "$YELLOW" "  setup  - Initial certificate setup (default)"
            echo_color "$YELLOW" "  renew  - Force certificate renewal"
            echo_color "$YELLOW" "  test   - Test certificate renewal"
            echo_color "$YELLOW" "  status - Check certificate status"
            echo_color "$YELLOW" "  help   - Show this help message"
            ;;
        *)
            echo_color "$RED" "Unknown command: $1"
            echo_color "$YELLOW" "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
