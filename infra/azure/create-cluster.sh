#!/bin/bash
set -e

# Azure Free Tier / Low Cost Cluster Creation Script
# Uses:
# - Free Tier AKS (Cluster management free)
# - Basic Load Balancer (Free)
# - Standard_B2s Node (Low cost burstable, ~2 vCPU, 4GB RAM)
# - 1 Node count

RESOURCE_GROUP="cloudtolocalllm-rg"
LOCATION="eastus"
CLUSTER_NAME="cloudtolocalllm-aks"
NODE_VM_SIZE="Standard_B2s"

# Login check
if ! az account show > /dev/null 2>&1; then
    echo "❌ Not logged in to Azure. Run 'az login' first."
    exit 1
fi

echo "🚀 Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "🚀 Creating AKS Cluster: $CLUSTER_NAME..."
# --tier free: Free cluster management
# --load-balancer-sku basic: Free load balancer (Standard costs $)
# --node-vm-size: Small burstable instance
# --node-count 1: Minimize compute
# --generate-ssh-keys: Required for Linux nodes
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --tier free \
    --node-count 1 \
    --node-vm-size $NODE_VM_SIZE \
    --load-balancer-sku basic \
    --generate-ssh-keys \
    --enable-managed-identity \
    --yes

echo "✅ Cluster created successfully!"
echo "To get credentials:"
echo "az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME"
