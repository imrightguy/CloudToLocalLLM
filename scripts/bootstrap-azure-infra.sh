#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Azure infrastructure for CloudToLocalLLM.
# Can be run locally (after `az login`) or from GitHub Actions (after azure/login@v2).
#
# Usage (positional args take precedence over env vars):
#   bootstrap-azure-infra.sh [RESOURCE_GROUP] [LOCATION] [ACR_NAME] [KEY_VAULT_NAME]
#
# If an argument is omitted, the script falls back to the corresponding env var:
#   RESOURCE_GROUP   -> AZURE_RESOURCE_GROUP
#   LOCATION         -> AZURE_LOCATION (default: eastus)
#   ACR_NAME         -> ACR_NAME
#   KEY_VAULT_NAME   -> AZURE_KEY_VAULT_NAME

RESOURCE_GROUP="${1:-${AZURE_RESOURCE_GROUP:-}}"
LOCATION="${2:-${AZURE_LOCATION:-eastus}}"
ACR_NAME_ARG="${3:-}"  # allow empty to avoid creating ACR if not desired
ACR_NAME="${ACR_NAME_ARG:-${ACR_NAME:-}}"
KEY_VAULT_NAME_ARG="${4:-}"
KEY_VAULT_NAME="${KEY_VAULT_NAME_ARG:-${AZURE_KEY_VAULT_NAME:-}}"

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "ERROR: RESOURCE_GROUP not provided and AZURE_RESOURCE_GROUP is empty." >&2
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "[bootstrap-azure-infra] Subscription:   ${SUBSCRIPTION_ID}"
echo "[bootstrap-azure-infra] Tenant:         ${TENANT_ID}"
echo "[bootstrap-azure-infra] Resource group: ${RESOURCE_GROUP} (${LOCATION})"
[[ -n "${ACR_NAME:-}" ]] && echo "[bootstrap-azure-infra] ACR:            ${ACR_NAME}" || echo "[bootstrap-azure-infra] ACR:            (none)"
[[ -n "${KEY_VAULT_NAME:-}" ]] && echo "[bootstrap-azure-infra] Key Vault:      ${KEY_VAULT_NAME}" || echo "[bootstrap-azure-infra] Key Vault:      (none)"

# Register required resource providers (idempotent)
for ns in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.OperationsManagement Microsoft.Insights; do
  state=$(az provider show --namespace "$ns" --query "registrationState" -o tsv 2>/dev/null || echo "")
  if [[ "$state" != "Registered" ]]; then
    echo "[bootstrap-azure-infra] Registering provider $ns (current state: $state)"
    az provider register --namespace "$ns" >/dev/null 2>&1 || true
  else
    echo "[bootstrap-azure-infra] Provider $ns already Registered"
  fi
done

# Ensure resource group exists (idempotent)
echo "[bootstrap-azure-infra] Ensuring resource group ${RESOURCE_GROUP} exists..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --query "properties.provisioningState" --output tsv >/dev/null

# Ensure ACR exists if a name was provided
if [[ -n "${ACR_NAME:-}" ]]; then
  if az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "[bootstrap-azure-infra] ACR ${ACR_NAME} already exists in RG ${RESOURCE_GROUP}; reusing."
  else
    echo "[bootstrap-azure-infra] Creating ACR ${ACR_NAME} in RG ${RESOURCE_GROUP}..."
    az acr create --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --sku Basic --admin-enabled true >/dev/null
  fi
fi

# Ensure Key Vault exists if a name was provided
if [[ -n "${KEY_VAULT_NAME:-}" ]]; then
  if az keyvault show --name "${KEY_VAULT_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "[bootstrap-azure-infra] Key Vault ${KEY_VAULT_NAME} already exists in RG ${RESOURCE_GROUP}; reusing."
  else
    echo "[bootstrap-azure-infra] Creating Key Vault ${KEY_VAULT_NAME} in RG ${RESOURCE_GROUP}..."
    az keyvault create --name "${KEY_VAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" >/dev/null
  fi
fi

echo "[bootstrap-azure-infra] Completed Azure bootstrap for RG=${RESOURCE_GROUP}"
