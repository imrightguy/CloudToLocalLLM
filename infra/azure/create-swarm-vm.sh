#!/bin/bash
set -e

# Azure VM Creation for Docker Swarm (Single Node)
# Uses:
# - Standard_B2s (2 vCPU, 4 GiB RAM) - Cost effective, burstable
# - Ubuntu 24.04 LTS
# - Cloud-init for Docker installation

RESOURCE_GROUP="cloudtolocalllm-rg"
LOCATION="centralus"
VM_LOCATION="eastus"
VM_NAME="cloudtolocalllm-swarm"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

# Check login
if ! az account show > /dev/null 2>&1; then
    echo "❌ Not logged in to Azure. Run 'az login' first."
    exit 1
fi

echo "🚀 Creating Resource Group: $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Cloud-init config to install Docker & Init Swarm & Setup Swap
cat <<EOF > cloud-init.yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
  - docker-compose-v2
runcmd:
  # Enable Swap (Crucial for B1ms 2GB RAM)
  - fallocate -l 4G /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Setup Docker
  - systemctl start docker
  - systemctl enable docker
  - usermod -aG docker $ADMIN_USERNAME
  - docker swarm init || true
EOF

echo "🚀 Creating VM: $VM_NAME ($VM_SIZE)..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image Ubuntu2404 \
    --size $VM_SIZE \
    --admin-username $ADMIN_USERNAME \
    --ssh-key-values $SSH_KEY_PATH \
    --custom-data cloud-init.yaml \
    --public-ip-sku Standard \
    --location $VM_LOCATION

echo "🔓 Opening SSH Port..."
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 22 --priority 1000

echo "✅ VM Created Successfully!"
IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)
echo "Public IP: $IP"
echo "SSH Command: ssh $ADMIN_USERNAME@$IP"

rm cloud-init.yaml
