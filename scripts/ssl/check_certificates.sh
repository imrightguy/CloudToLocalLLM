#!/bin/bash

# CloudToLocalLLM Certificate Status Check Script
# This script checks the status of Let's Encrypt certificates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="cloudtolocalllm.online"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to check certificate files
check_cert_files() {
    echo_color "$BLUE" "Checking certificate files..."
    
    local files=("fullchain.pem" "privkey.pem" "cert.pem" "chain.pem")
    local all_exist=true
    
    for file in "${files[@]}"; do
        if docker compose exec webapp test -f "$CERT_PATH/$file" 2>/dev/null; then
            echo_color "$GREEN" "✓ $file exists"
        else
            echo_color "$RED" "✗ $file missing"
            all_exist=false
        fi
    done
    
    return $([ "$all_exist" = true ] && echo 0 || echo 1)
}

# Function to check certificate expiration
check_cert_expiration() {
    echo_color "$BLUE" "Checking certificate expiration..."
    
    if docker compose exec webapp test -f "$CERT_PATH/cert.pem" 2>/dev/null; then
        local expiry_date=$(docker compose exec webapp openssl x509 -in "$CERT_PATH/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo 0)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            echo_color "$GREEN" "✓ Certificate expires in $days_until_expiry days ($expiry_date)"
        elif [ $days_until_expiry -gt 7 ]; then
            echo_color "$YELLOW" "⚠ Certificate expires in $days_until_expiry days ($expiry_date) - Consider renewal"
        else
            echo_color "$RED" "✗ Certificate expires in $days_until_expiry days ($expiry_date) - URGENT RENEWAL NEEDED"
        fi
        
        return 0
    else
        echo_color "$RED" "✗ Certificate file not found"
        return 1
    fi
}

# Function to check certificate domains
check_cert_domains() {
    echo_color "$BLUE" "Checking certificate domains..."
    
    if docker compose exec webapp test -f "$CERT_PATH/cert.pem" 2>/dev/null; then
        local domains=$(docker compose exec webapp openssl x509 -in "$CERT_PATH/cert.pem" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g' | tr ',' '\n' | sed 's/^ *//' | sort)
        
        echo_color "$GREEN" "Certificate covers the following domains:"
        echo "$domains" | while read -r domain; do
            if [ -n "$domain" ]; then
                echo_color "$GREEN" "  ✓ $domain"
            fi
        done
        
        return 0
    else
        echo_color "$RED" "✗ Certificate file not found"
        return 1
    fi
}

# Function to test HTTPS connectivity
test_https_connectivity() {
    echo_color "$BLUE" "Testing HTTPS connectivity..."
    
    local test_domains=("cloudtolocalllm.online" "app.cloudtolocalllm.online")
    
    for domain in "${test_domains[@]}"; do
        if curl -s --max-time 10 "https://$domain" > /dev/null 2>&1; then
            echo_color "$GREEN" "✓ HTTPS connection to $domain successful"
        else
            echo_color "$RED" "✗ HTTPS connection to $domain failed"
        fi
    done
}

# Function to check certificate permissions
check_cert_permissions() {
    echo_color "$BLUE" "Checking certificate permissions..."
    
    if docker compose exec webapp test -d "$CERT_PATH" 2>/dev/null; then
        local perms=$(docker compose exec webapp stat -c "%a" "$CERT_PATH" 2>/dev/null || echo "unknown")
        echo_color "$GREEN" "Certificate directory permissions: $perms"
        
        if docker compose exec webapp test -f "$CERT_PATH/privkey.pem" 2>/dev/null; then
            local key_perms=$(docker compose exec webapp stat -c "%a" "$CERT_PATH/privkey.pem" 2>/dev/null || echo "unknown")
            echo_color "$GREEN" "Private key permissions: $key_perms"
            
            if [ "$key_perms" = "600" ] || [ "$key_perms" = "640" ]; then
                echo_color "$GREEN" "✓ Private key permissions are secure"
            else
                echo_color "$YELLOW" "⚠ Private key permissions may be too permissive"
            fi
        fi
        
        return 0
    else
        echo_color "$RED" "✗ Certificate directory not found"
        return 1
    fi
}

# Function to show certificate details
show_cert_details() {
    echo_color "$BLUE" "Certificate details:"
    
    if docker compose exec webapp test -f "$CERT_PATH/cert.pem" 2>/dev/null; then
        docker compose exec webapp openssl x509 -in "$CERT_PATH/cert.pem" -noout -text 2>/dev/null | grep -E "(Subject:|Issuer:|Not Before:|Not After:|DNS:)" | sed 's/^[[:space:]]*/  /'
        return 0
    else
        echo_color "$RED" "✗ Certificate file not found"
        return 1
    fi
}

# Main function
main() {
    echo_color "$BLUE" "CloudToLocalLLM Certificate Status Check"
    echo_color "$BLUE" "======================================="
    echo ""
    
    local overall_status=0
    
    # Check if webapp container is running
    if ! docker compose ps | grep -q "CloudToLocalLLM-webapp.*Up"; then
        echo_color "$RED" "✗ Webapp container is not running"
        echo_color "$YELLOW" "Please start the webapp container first: docker compose up -d webapp"
        exit 1
    fi
    
    # Run all checks
    check_cert_files || overall_status=1
    echo ""
    
    check_cert_expiration || overall_status=1
    echo ""
    
    check_cert_domains || overall_status=1
    echo ""
    
    check_cert_permissions || overall_status=1
    echo ""
    
    test_https_connectivity || overall_status=1
    echo ""
    
    if [ "${1:-}" = "--details" ]; then
        show_cert_details
        echo ""
    fi
    
    # Summary
    if [ $overall_status -eq 0 ]; then
        echo_color "$GREEN" "✓ All certificate checks passed!"
    else
        echo_color "$RED" "✗ Some certificate checks failed"
        echo_color "$YELLOW" "Consider running: ./scripts/ssl/setup_letsencrypt.sh renew"
    fi
    
    exit $overall_status
}

# Show help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo_color "$BLUE" "Usage: $0 [--details] [--help]"
    echo_color "$YELLOW" "  --details  Show detailed certificate information"
    echo_color "$YELLOW" "  --help     Show this help message"
    exit 0
fi

# Run main function
main "$@"
