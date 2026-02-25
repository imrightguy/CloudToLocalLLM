#!/usr/bin/env bash
#
# AKS Deployment Prerequisites Validation Script
#
# This script validates all prerequisites required for AKS deployment.
# Can be run locally or in GitHub Actions to catch issues early.
#
# Usage:
#   ./scripts/validate-aks-prerequisites.sh [OPTIONS]
#
# Options:
#   --check-secrets-only     Only validate GitHub secrets (skip Azure resources)
#   --check-azure-only       Only validate Azure resources (skip secrets)
#   --resource-group NAME    Resource group name (default: CloudToLocalLLM-rg)
#   --acr-name NAME          ACR name (default: CloudToLocalLLM)
#   --keyvault-name NAME     Key Vault name (default: CloudToLocalLLM-kv)
#   --verbose                Show detailed output
#   --help                   Show this help message
#
# Exit codes:
#   0 - All checks passed
#   1 - Missing prerequisites
#   2 - Configuration issues
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CHECK_SECRETS_ONLY="false"
CHECK_AZURE_ONLY="false"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-CloudToLocalLLM-rg}"
ACR_NAME="${ACR_NAME:-CloudToLocalLLM}"
KEYVAULT_NAME="${AZURE_KEY_VAULT_NAME:-CloudToLocalLLM-kv}"
VERBOSE="false"

# Track validation status
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --check-secrets-only)
      CHECK_SECRETS_ONLY="true"
      shift
      ;;
    --check-azure-only)
      CHECK_AZURE_ONLY="true"
      shift
      ;;
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --acr-name)
      ACR_NAME="$2"
      shift 2
      ;;
    --keyvault-name)
      KEYVAULT_NAME="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --help)
      head -n 25 "$0" | tail -n +2 | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}â„¹${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}âœ“${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

log_warning() {
    echo -e "${YELLOW}âš ${NC} $1"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

log_error() {
    echo -e "${RED}âœ—${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

log_section() {
    echo ""
    echo -e "${BLUE}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check environment variable
check_env_var() {
    local var_name="$1"
    local var_desc="$2"
    local required="${3:-true}"
    
    local var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        if [[ "$required" == "true" ]]; then
            log_error "$var_desc ($var_name) is not set"
            return 1
        else
            log_warning "$var_desc ($var_name) is not set (optional)"
            return 0
        fi
    else
        log_success "$var_desc ($var_name) is set"
        return 0
    fi
}

# Validate CLI tools
validate_cli_tools() {
    log_section "CLI Tools"
    
    # Azure CLI
    if command_exists az; then
        local az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
        log_success "Azure CLI is installed (version: $az_version)"
    else
        log_error "Azure CLI is not installed"
        log_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    fi
    
    # kubectl
    if command_exists kubectl; then
        local kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        log_success "kubectl is installed (version: $kubectl_version)"
    else
        log_warning "kubectl is not installed (needed for deployment verification)"
    fi
    
    # jq
    if command_exists jq; then
        log_success "jq is installed"
    else
        log_warning "jq is not installed (needed for JSON parsing)"
    fi
}

# Validate Azure CLI authentication
validate_azure_auth() {
    log_section "Azure Authentication"
    
    if ! command_exists az; then
        log_error "Cannot validate Azure auth: Azure CLI not installed"
        return
    fi
    
    if az account show >/dev/null 2>&1; then
        local subscription_id=$(az account show --query id -o tsv)
        local subscription_name=$(az account show --query name -o tsv)
        log_success "Authenticated to Azure"
        log_info "Subscription: $subscription_name ($subscription_id)"
    else
        log_error "Not authenticated to Azure CLI"
        log_info "Run: az login"
    fi
}

# Validate Azure resource providers
validate_azure_providers() {
    log_section "Azure Resource Providers"
    
    if ! az account show >/dev/null 2>&1; then
        log_error "Cannot validate providers: Not authenticated to Azure"
        return
    fi
    
    local providers=(
        "Microsoft.ContainerService"
        "Microsoft.ContainerRegistry"
        "Microsoft.KeyVault"
        "Microsoft.OperationsManagement"
        "Microsoft.Insights"
    )
    
    for provider in "${providers[@]}"; do
        local state=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
        
        if [[ "$state" == "Registered" ]]; then
            log_success "$provider is registered"
        elif [[ "$state" == "Registering" ]]; then
            log_warning "$provider is registering (wait a few minutes)"
        else
            log_error "$provider is not registered"
            log_info "Register with: az provider register --namespace $provider"
        fi
    done
}

# Validate Azure resources
validate_azure_resources() {
    log_section "Azure Resources"
    
    if ! az account show >/dev/null 2>&1; then
        log_error "Cannot validate resources: Not authenticated to Azure"
        return
    fi
    
    # Resource Group
    if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_success "Resource group exists: $RESOURCE_GROUP"
    else
        log_error "Resource group not found: $RESOURCE_GROUP"
        log_info "Create with: az group create --name $RESOURCE_GROUP --location eastus"
    fi
    
    # ACR
    if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_success "ACR exists: $ACR_NAME"
        
        # Check ACR admin enabled
        local admin_enabled=$(az acr show --name "$ACR_NAME" --query adminUserEnabled -o tsv)
        if [[ "$admin_enabled" == "true" ]]; then
            log_success "ACR admin access is enabled"
        else
            log_warning "ACR admin access is disabled"
        fi
        
        # Check ACR health
        if az acr check-health --name "$ACR_NAME" --yes >/dev/null 2>&1; then
            log_success "ACR health check passed"
        else
            log_warning "ACR health check failed"
        fi
    else
        log_error "ACR not found: $ACR_NAME"
    fi
    
    # Key Vault
    if az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_success "Key Vault exists: $KEYVAULT_NAME"
        
        # Check if RBAC authorization is enabled
        local rbac_enabled=$(az keyvault show --name "$KEYVAULT_NAME" --query "properties.enableRbacAuthorization" -o tsv 2>/dev/null || echo "false")
        if [[ "$rbac_enabled" == "true" ]]; then
            log_success "Key Vault RBAC authorization is enabled"
        else
            log_warning "Key Vault RBAC authorization is disabled (using access policies)"
        fi
    else
        log_error "Key Vault not found: $KEYVAULT_NAME"
    fi
}

# Validate service principal permissions
validate_service_principal() {
    log_section "Service Principal Permissions"
    
    if ! az account show >/dev/null 2>&1; then
        log_error "Cannot validate service principal: Not authenticated to Azure"
        return
    fi
    
    if [[ -z "${AZURE_CLIENT_ID:-}" ]]; then
        log_warning "AZURE_CLIENT_ID not set, cannot validate service principal"
        return
    fi
    
    # Check if service principal exists
    if az ad sp show --id "$AZURE_CLIENT_ID" >/dev/null 2>&1; then
        log_success "Service principal exists: $AZURE_CLIENT_ID"
        
        # Check federated credentials
        local fed_creds=$(az ad app federated-credential list --id "$AZURE_CLIENT_ID" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        if [[ "$fed_creds" -gt 0 ]]; then
            log_success "Federated credentials configured ($fed_creds)"
        else
            log_warning "No federated credentials found (needed for OIDC auth)"
        fi
        
        # Check role assignments
        local sp_object_id=$(az ad sp show --id "$AZURE_CLIENT_ID" --query id -o tsv)
        local role_count=$(az role assignment list --assignee "$sp_object_id" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        
        if [[ "$role_count" -gt 0 ]]; then
            log_success "Role assignments found ($role_count)"
            
            # Check for specific required roles (check all scopes)
            local has_contributor=$(az role assignment list --assignee "$sp_object_id" --all --query "[?roleDefinitionName=='Contributor'] | length(@)" -o tsv 2>/dev/null || echo "0")
            local has_user_access=$(az role assignment list --assignee "$sp_object_id" --all --query "[?roleDefinitionName=='User Access Administrator'] | length(@)" -o tsv 2>/dev/null || echo "0")
            
            if [[ "$has_contributor" -gt 0 ]]; then
                log_success "Has Contributor role (can create resources)"
            else
                log_warning "Missing Contributor role"
            fi
            
            if [[ "$has_user_access" -gt 0 ]]; then
                log_success "Has User Access Administrator role (can assign roles)"
            else
                log_error "Missing User Access Administrator role (cannot assign roles to AKS)"
                log_info "Grant with: az role assignment create --assignee $sp_object_id --role 'User Access Administrator' --scope /subscriptions/\$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
            fi
            
            # Check ACR push permissions
            if [[ -n "$ACR_NAME" ]]; then
                local acr_id=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || echo "")
                if [[ -n "$acr_id" ]]; then
                    local has_acr_push=$(az role assignment list --assignee "$sp_object_id" --scope "$acr_id" --query "[?roleDefinitionName=='AcrPush'] | length(@)" -o tsv 2>/dev/null || echo "0")
                    if [[ "$has_acr_push" -gt 0 ]]; then
                        log_success "Has AcrPush role (can push to ACR)"
                    else
                        log_warning "Missing AcrPush role for ACR"
                    fi
                fi
            fi
            
            # Check Key Vault permissions
            if [[ -n "$KEYVAULT_NAME" ]]; then
                local kv_id=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || echo "")
                if [[ -n "$kv_id" ]]; then
                    local has_kv_secrets=$(az role assignment list --assignee "$sp_object_id" --scope "$kv_id" --query "[?roleDefinitionName=='Key Vault Secrets Officer'] | length(@)" -o tsv 2>/dev/null || echo "0")
                    if [[ "$has_kv_secrets" -gt 0 ]]; then
                        log_success "Has Key Vault Secrets Officer role"
                    else
                        log_warning "Missing Key Vault Secrets Officer role"
                    fi
                fi
            fi
        else
            log_error "No role assignments found for service principal"
        fi
    else
        log_error "Service principal not found: $AZURE_CLIENT_ID"
    fi
}

# Validate GitHub secrets
validate_github_secrets() {
    log_section "GitHub Secrets"
    
    # Required secrets
    local required_secrets=(
        "AZURE_CLIENT_ID:Azure Service Principal Client ID"
        "AZURE_TENANT_ID:Azure Tenant ID"
        "AZURE_SUBSCRIPTION_ID:Azure Subscription ID"
        "AZURE_KEY_VAULT_NAME:Azure Key Vault Name"
        "POSTGRES_PASSWORD:PostgreSQL Password"
        "JWT_SECRET:JWT Secret"
        "STRIPE_TEST_SECRET_KEY:Stripe Test Secret Key"
        "CLOUDFLARE_DNS_TOKEN:Cloudflare DNS Token"
        "CLOUDFLARE_TUNNEL_TOKEN:Cloudflare Tunnel Token"
        "SUPABASE_JWT_SECRET:Supabase JWT Secret"
    )
    
    # Optional secrets
    local optional_secrets=(
        "SENTRY_DSN:Sentry DSN"
        "STRIPE_TEST_PUBLISHABLE_KEY:Stripe Test Publishable Key"
        "STRIPE_TEST_WEBHOOK_SECRET:Stripe Test Webhook Secret"
        "STRIPE_LIVE_SECRET_KEY:Stripe Live Secret Key"
        "STRIPE_LIVE_PUBLISHABLE_KEY:Stripe Live Publishable Key"
        "STRIPE_LIVE_WEBHOOK_SECRET:Stripe Live Webhook Secret"
    )
    
    # Check required secrets
    for secret_pair in "${required_secrets[@]}"; do
        IFS=: read -r secret_name secret_desc <<< "$secret_pair"
        case "$secret_name" in CLOUDFLARE_DNS_TOKEN) check_env_var "$secret_name" "$secret_desc" false ;; *) check_env_var "$secret_name" "$secret_desc" true ;; esac
    done
    
    # Check optional secrets
    for secret_pair in "${optional_secrets[@]}"; do
        IFS=: read -r secret_name secret_desc <<< "$secret_pair"
        check_env_var "$secret_name" "$secret_desc" false
    done
}

# Validate Docker images can be pushed to ACR
validate_acr_access() {
    log_section "ACR Access Validation"
    
    if ! command_exists az; then
        log_warning "Cannot validate ACR access: Azure CLI not installed"
        return
    fi
    
    if ! az account show >/dev/null 2>&1; then
        log_warning "Cannot validate ACR access: Not authenticated to Azure"
        return
    fi
    
    if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_warning "Cannot validate ACR access: ACR not found"
        return
    fi
    
    # Try to get ACR credentials
    if az acr credential show --name "$ACR_NAME" >/dev/null 2>&1; then
        log_success "Can retrieve ACR credentials"
    else
        log_error "Cannot retrieve ACR credentials (admin access may be disabled)"
    fi
    
    # Check if current user/SP can push to ACR
    local acr_id=$(az acr show --name "$ACR_NAME" --query id -o tsv)
    local current_user=$(az account show --query user.name -o tsv)
    
    local has_push_role=$(az role assignment list \
        --scope "$acr_id" \
        --query "[?contains(roleDefinitionName, 'Push') || contains(roleDefinitionName, 'Contributor') || contains(roleDefinitionName, 'Owner')] | length(@)" \
        -o tsv 2>/dev/null || echo "0")
    
    if [[ "$has_push_role" -gt 0 ]]; then
        log_success "Current account has ACR push permissions"
    else
        log_warning "Current account may not have ACR push permissions"
    fi
}

# Generate summary
generate_summary() {
    log_section "Validation Summary"
    
    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))
    
    echo ""
    echo "Results:"
    echo -e "  ${GREEN}âœ“ Passed:${NC}  $CHECKS_PASSED"
    echo -e "  ${YELLOW}âš  Warning:${NC} $CHECKS_WARNING"
    echo -e "  ${RED}âœ— Failed:${NC}  $CHECKS_FAILED"
    echo -e "  Total:    $total_checks"
    echo ""
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        if [[ $CHECKS_WARNING -eq 0 ]]; then
            echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
            echo -e "${GREEN}âœ“ All checks passed! Ready for deployment.${NC}"
            echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
            return 0
        else
            echo -e "${YELLOW}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
            echo -e "${YELLOW}âš  All critical checks passed, but there are warnings.${NC}"
            echo -e "${YELLOW}  Deployment may proceed, but review warnings above.${NC}"
            echo -e "${YELLOW}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
            return 0
        fi
    else
        echo -e "${RED}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
        echo -e "${RED}âœ— Validation failed! Fix errors before deployment.${NC}"
        echo -e "${RED}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}AKS Deployment Prerequisites Validation${NC}"
    echo -e "${BLUE}CloudToLocalLLM${NC}"
    echo ""
    
    # Always check CLI tools
    validate_cli_tools
    
    if [[ "$CHECK_SECRETS_ONLY" == "true" ]]; then
        # Only check secrets
        validate_github_secrets
    elif [[ "$CHECK_AZURE_ONLY" == "true" ]]; then
        # Only check Azure
        validate_azure_auth
        validate_azure_providers
        validate_azure_resources
        validate_service_principal
        validate_acr_access
    else
        # Check everything
        validate_azure_auth
        validate_azure_providers
        validate_azure_resources
        validate_service_principal
        validate_github_secrets
        validate_acr_access
    fi
    
    if ! generate_summary; then
        exit 1
    fi
}

# Run main function
main "$@"

