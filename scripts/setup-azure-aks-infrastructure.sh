#!/usr/bin/env bash
#
# Azure AKS Infrastructure Setup Script
# 
# This script sets up all required Azure infrastructure for CloudToLocalLLM deployment
# on a brand new Azure account. It creates:
#   - Resource Group
#   - Azure Container Registry (ACR)
#   - Azure Key Vault
#   - Service Principal with Federated Credentials for GitHub Actions
#   - Optionally: AKS Cluster
#
# Usage:
#   ./scripts/setup-azure-aks-infrastructure.sh [OPTIONS]
#
# Options:
#   --subscription-id ID     Azure subscription ID (prompts if not provided)
#   --location LOCATION      Azure region (default: eastus)
#   --resource-group NAME    Resource group name (default: CloudToLocalLLM-rg)
#   --acr-name NAME          ACR name (default: CloudToLocalLLM)
#   --keyvault-name NAME     Key Vault name (default: CloudToLocalLLM-kv)
#   --aks-name NAME          AKS cluster name (default: CloudToLocalLLM-aks)
#   --create-aks             Create AKS cluster now (default: no, workflow creates it)
#   --github-repo OWNER/REPO GitHub repository (default: prompts)
#   --non-interactive        Run without prompts (use defaults/env vars)
#   --help                   Show this help message
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_LOCATION="eastus"
DEFAULT_RESOURCE_GROUP="CloudToLocalLLM-rg"
DEFAULT_ACR_NAME="CloudToLocalLLM"
DEFAULT_KEYVAULT_NAME="CloudToLocalLLM-kv"
DEFAULT_AKS_NAME="CloudToLocalLLM-aks"
CREATE_AKS="false"
NON_INTERACTIVE="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --subscription-id)
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --location)
      LOCATION="$2"
      shift 2
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
    --aks-name)
      AKS_NAME="$2"
      shift 2
      ;;
    --create-aks)
      CREATE_AKS="true"
      shift
      ;;
    --github-repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE="true"
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
    echo -e "${BLUE}â„¹${NC} $1"
}

log_success() {
    echo -e "${GREEN}âœ“${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}âš ${NC} $1"
}

log_error() {
    echo -e "${RED}âœ—${NC} $1"
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

# Validate Azure CLI
validate_azure_cli() {
    log_section "Validating Azure CLI"
    
    if ! command_exists az; then
        log_error "Azure CLI is not installed"
        log_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    log_success "Azure CLI is installed: $(az version --query '"azure-cli"' -o tsv)"
    
    # Check if logged in
    if ! az account show >/dev/null 2>&1; then
        log_error "Not logged in to Azure CLI"
        log_info "Run: az login"
        exit 1
    fi
    
    log_success "Logged in to Azure CLI"
}

# Select or validate subscription
setup_subscription() {
    log_section "Azure Subscription Setup"
    
    if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            # Use current subscription
            SUBSCRIPTION_ID=$(az account show --query id -o tsv)
            log_info "Using current subscription: $SUBSCRIPTION_ID"
        else
            # List available subscriptions
            echo "Available subscriptions:"
            az account list --query "[].{Name:name, ID:id, State:state}" -o table
            echo ""
            read -p "Enter subscription ID (or press Enter to use current): " input_sub
            if [[ -n "$input_sub" ]]; then
                SUBSCRIPTION_ID="$input_sub"
            else
                SUBSCRIPTION_ID=$(az account show --query id -o tsv)
            fi
        fi
    fi
    
    # Set the subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    log_success "Using subscription: $SUBSCRIPTION_ID"
    
    # Get tenant ID
    TENANT_ID=$(az account show --query tenantId -o tsv)
    log_info "Tenant ID: $TENANT_ID"
}

# Set configuration values
setup_configuration() {
    log_section "Configuration"
    
    # Set defaults if not provided
    LOCATION="${LOCATION:-$DEFAULT_LOCATION}"
    RESOURCE_GROUP="${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}"
    ACR_NAME="${ACR_NAME:-$DEFAULT_ACR_NAME}"
    KEYVAULT_NAME="${KEYVAULT_NAME:-$DEFAULT_KEYVAULT_NAME}"
    AKS_NAME="${AKS_NAME:-$DEFAULT_AKS_NAME}"
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo "Configuration:"
        echo "  Location: $LOCATION"
        echo "  Resource Group: $RESOURCE_GROUP"
        echo "  ACR Name: $ACR_NAME"
        echo "  Key Vault Name: $KEYVAULT_NAME"
        echo "  AKS Name: $AKS_NAME"
        echo "  Create AKS: $CREATE_AKS"
        echo ""
        read -p "Continue with these values? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
    
    log_success "Configuration confirmed"
}

# Register Azure resource providers
register_providers() {
    log_section "Registering Azure Resource Providers"
    
    local providers=(
        "Microsoft.ContainerService"
        "Microsoft.ContainerRegistry"
        "Microsoft.KeyVault"
        "Microsoft.OperationsManagement"
        "Microsoft.Insights"
        "Microsoft.OperationalInsights"
    )
    
    for provider in "${providers[@]}"; do
        log_info "Checking provider: $provider"
        
        state=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
        
        if [[ "$state" == "Registered" ]]; then
            log_success "$provider already registered"
        else
            log_info "Registering $provider (this may take a few minutes)..."
            az provider register --namespace "$provider" --wait
            log_success "$provider registered"
        fi
    done
}

# Create resource group
create_resource_group() {
    log_section "Resource Group"
    
    if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_warning "Resource group $RESOURCE_GROUP already exists"
        log_info "Location: $(az group show --name "$RESOURCE_GROUP" --query location -o tsv)"
    else
        log_info "Creating resource group: $RESOURCE_GROUP in $LOCATION"
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
        log_success "Resource group created"
    fi
}

# Create Azure Container Registry
create_acr() {
    log_section "Azure Container Registry"
    
    if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_warning "ACR $ACR_NAME already exists"
        ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
        log_info "Login server: $ACR_LOGIN_SERVER"
    else
        log_info "Creating ACR: $ACR_NAME (this may take 2-3 minutes)..."
        az acr create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$ACR_NAME" \
            --sku Basic \
            --admin-enabled true \
            --location "$LOCATION" \
            >/dev/null
        
        ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
        log_success "ACR created: $ACR_LOGIN_SERVER"
    fi
    
    # Verify ACR health
    log_info "Checking ACR health..."
    if az acr check-health --name "$ACR_NAME" --yes >/dev/null 2>&1; then
        log_success "ACR health check passed"
    else
        log_warning "ACR health check had warnings (this is usually okay)"
    fi
}

# Create Azure Key Vault
create_keyvault() {
    log_section "Azure Key Vault"
    
    if az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log_warning "Key Vault $KEYVAULT_NAME already exists"
    else
        log_info "Creating Key Vault: $KEYVAULT_NAME"
        az keyvault create \
            --name "$KEYVAULT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --enable-rbac-authorization true \
            >/dev/null
        log_success "Key Vault created"
    fi
}

# Create service principal for GitHub Actions
create_service_principal() {
    log_section "Service Principal for GitHub Actions"
    
    # Get GitHub repository
    if [[ -z "${GITHUB_REPO:-}" ]]; then
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            log_error "GitHub repository is required in non-interactive mode (--github-repo OWNER/REPO)"
            exit 1
        fi
        
        echo ""
        echo "Enter your GitHub repository (format: owner/repository)"
        echo "Example: myusername/CloudToLocalLLM"
        read -p "GitHub repository: " GITHUB_REPO
        
        if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
            log_error "Invalid repository format. Expected: owner/repository"
            exit 1
        fi
    fi
    
    SP_NAME="CloudToLocalLLM-github-actions"
    
    log_info "Creating service principal: $SP_NAME"
    
    # Check if SP already exists
    SP_APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$SP_APP_ID" ]]; then
        log_warning "Service principal already exists"
        log_info "App ID: $SP_APP_ID"
        
        # Get object ID
        SP_OBJECT_ID=$(az ad sp show --id "$SP_APP_ID" --query id -o tsv)
    else
        # Create service principal
        SP_OUTPUT=$(az ad sp create-for-rbac \
            --name "$SP_NAME" \
            --role contributor \
            --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
            --sdk-auth \
            2>/dev/null)
        
        SP_APP_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
        SP_OBJECT_ID=$(az ad sp show --id "$SP_APP_ID" --query id -o tsv)
        
        log_success "Service principal created"
    fi
    
    log_info "Service Principal App ID: $SP_APP_ID"
    
    # Add federated credential for GitHub Actions
    log_info "Setting up federated credential for GitHub Actions..."
    
    CREDENTIAL_NAME="github-actions-main"
    
    # Check if federated credential already exists
    if az ad app federated-credential show \
        --id "$SP_APP_ID" \
        --federated-credential-id "$CREDENTIAL_NAME" >/dev/null 2>&1; then
        log_warning "Federated credential already exists"
    else
        # Create federated credential
        cat > /tmp/federated-credential.json <<EOF
{
  "name": "$CREDENTIAL_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_REPO}:ref:refs/heads/main",
  "description": "GitHub Actions - main branch",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF
        
        if az ad app federated-credential create \
            --id "$SP_APP_ID" \
            --parameters /tmp/federated-credential.json \
            >/dev/null 2>&1; then
            log_success "Federated credential created for GitHub Actions"
        else
            log_warning "Federated credential may already exist (this is okay)"
        fi
        
        rm -f /tmp/federated-credential.json
    fi
    
    # Assign additional roles
    log_info "Assigning additional roles to service principal..."
    
    # AcrPush role for pushing images to ACR
    ACR_ID=$(az acr show --name "$ACR_NAME" --query id -o tsv)
    if ! az role assignment list --assignee "$SP_OBJECT_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPush']" -o tsv | grep -q .; then
        az role assignment create \
            --assignee "$SP_OBJECT_ID" \
            --role "AcrPush" \
            --scope "$ACR_ID" \
            >/dev/null
        log_success "Assigned AcrPush role for ACR"
    else
        log_info "AcrPush role already assigned"
    fi
    
    # Key Vault Secrets Officer role
    KV_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)
    if ! az role assignment list --assignee "$SP_OBJECT_ID" --scope "$KV_ID" --query "[?roleDefinitionName=='Key Vault Secrets Officer']" -o tsv | grep -q .; then
        az role assignment create \
            --assignee "$SP_OBJECT_ID" \
            --role "Key Vault Secrets Officer" \
            --scope "$KV_ID" \
            >/dev/null
        log_success "Assigned Key Vault Secrets Officer role"
    else
        log_info "Key Vault Secrets Officer role already assigned"
    fi
    
    # User Access Administrator role (needed to assign roles to AKS managed identity)
    RG_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
    if ! az role assignment list --assignee "$SP_OBJECT_ID" --scope "$RG_SCOPE" --query "[?roleDefinitionName=='User Access Administrator']" -o tsv | grep -q .; then
        az role assignment create \
            --assignee "$SP_OBJECT_ID" \
            --role "User Access Administrator" \
            --scope "$RG_SCOPE" \
            >/dev/null
        log_success "Assigned User Access Administrator role for resource group"
    else
        log_info "User Access Administrator role already assigned"
    fi
    
    # Store the app ID for output
    AZURE_CLIENT_ID="$SP_APP_ID"
}

# Optionally create AKS cluster
create_aks_cluster() {
    if [[ "$CREATE_AKS" != "true" ]]; then
        log_info "Skipping AKS cluster creation (will be created by GitHub Actions workflow)"
        return
    fi
    
    log_section "Azure Kubernetes Service (AKS)"
    
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" >/dev/null 2>&1; then
        log_warning "AKS cluster $AKS_NAME already exists"
        return
    fi
    
    log_info "Creating AKS cluster: $AKS_NAME (this may take 10-15 minutes)..."
    log_warning "This is a long operation. You can press Ctrl+C and let GitHub Actions create it instead."
    
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_NAME" \
        --node-count 1 \
        --node-vm-size Standard_B2s \
        --enable-addons monitoring \
        --enable-msi-auth \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --network-plugin kubenet \
        --location "$LOCATION" \
        --generate-ssh-keys \
        --attach-acr "$ACR_NAME" \
        >/dev/null
    
    log_success "AKS cluster created"
}

# Generate output configuration
generate_output() {
    log_section "Configuration Summary"
    
    # Create output file
    OUTPUT_FILE=".azure-deployment-config.json"
    
    cat > "$OUTPUT_FILE" <<EOF
{
  "AZURE_SUBSCRIPTION_ID": "$SUBSCRIPTION_ID",
  "AZURE_TENANT_ID": "$TENANT_ID",
  "AZURE_CLIENT_ID": "$AZURE_CLIENT_ID",
  "AZURE_RESOURCE_GROUP": "$RESOURCE_GROUP",
  "ACR_NAME": "$ACR_NAME",
  "ACR_LOGIN_SERVER": "$ACR_LOGIN_SERVER",
  "AZURE_KEY_VAULT_NAME": "$KEYVAULT_NAME",
  "AZURE_CLUSTER_NAME": "$AKS_NAME",
  "AZURE_LOCATION": "$LOCATION",
  "GITHUB_REPO": "$GITHUB_REPO"
}
EOF
    
    log_success "Configuration saved to: $OUTPUT_FILE"
    
    echo ""
    echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo -e "${GREEN}âœ“ Azure Infrastructure Setup Complete!${NC}"
    echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo ""
    echo "GitHub Secrets Required:"
    echo "  AZURE_CLIENT_ID:         $AZURE_CLIENT_ID"
    echo "  AZURE_TENANT_ID:         $TENANT_ID"
    echo "  AZURE_SUBSCRIPTION_ID:   $SUBSCRIPTION_ID"
    echo "  AZURE_KEY_VAULT_NAME:    $KEYVAULT_NAME"
    echo ""
    echo "Next Steps:"
    echo "  1. Run: ./scripts/setup-github-secrets-aks.sh"
    echo "  2. Push to GitHub main branch to trigger deployment"
    echo ""
    echo "Configuration file: $OUTPUT_FILE"
    echo ""
}

# Main execution
main() {
    log_section "Azure AKS Infrastructure Setup"
    log_info "CloudToLocalLLM - Automated Infrastructure Provisioning"
    
    validate_azure_cli
    setup_subscription
    setup_configuration
    register_providers
    create_resource_group
    create_acr
    create_keyvault
    create_service_principal
    create_aks_cluster
    generate_output
    
    log_success "All done! ðŸŽ‰"
}

# Run main function
main "$@"

