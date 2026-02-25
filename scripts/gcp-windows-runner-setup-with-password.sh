#!/bin/bash

# This script automates the creation of a GitHub Actions self-hosted runner on a GCP Windows VM.

# --- Configuration Variables ---
GCP_PROJECT_ID="CloudToLocalLLM-468303"
GCP_REGION="us-central1"
GCP_ZONE="us-central1-a"
VM_NAME="github-runner-windows-$(date +%s)"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="windows-2019"
IMAGE_PROJECT="windows-cloud"
GITHUB_RUNNER_ORG_URL="https://github.com/CloudToLocalLLM-online/CloudToLocalLLM"
GITHUB_RUNNER_TOKEN="BOBH5XEA7XJPPTNW2CYI7F3IUR2RG"
NEW_USER="gemini"
NEW_PASSWORD=$(openssl rand -base64 12)

# --- Startup Script for the VM (PowerShell) ---
STARTUP_SCRIPT_FILE=$(mktemp)
cat > "${STARTUP_SCRIPT_FILE}" << EOM
# Create a new user
New-LocalUser -Name "${NEW_USER}" -Password (ConvertTo-SecureString -String "${NEW_PASSWORD}" -AsPlainText -Force) -FullName "Gemini User"
Add-LocalGroupMember -Group "Administrators" -Member "${NEW_USER}"

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Git
choco install git -y

# Create runner directory
New-Item -ItemType Directory -Path C:\actions-runner -Force
Set-Location C:\actions-runner

# Download the runner application
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip" -OutFile "actions-runner-win-x64-2.311.0.zip"
Expand-Archive -Path "actions-runner-win-x64-2.311.0.zip" -DestinationPath "."

# Configure the runner
.\config.cmd --url ${GITHUB_RUNNER_ORG_URL} --token ${GITHUB_RUNNER_TOKEN} --labels windows,self-hosted --unattended

# Install as a service
.\svc.exe install
.\svc.exe start
EOM

# --- Create the VM Instance ---
echo "Creating GCP VM instance: ${VM_NAME}"...
gcloud compute instances create "${VM_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --zone="${GCP_ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --image-family="${IMAGE_FAMILY}" \
  --image-project="${IMAGE_PROJECT}" \
  --metadata-from-file=windows-startup-script-ps1="${STARTUP_SCRIPT_FILE}" \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=http-server,https-server

# Clean up the temporary file
rm "${STARTUP_SCRIPT_FILE}"

echo "VM instance creation initiated. It may take a few minutes for the runner to come online."
echo "Monitor the runner status in GitHub: ${GITHUB_RUNNER_ORG_URL}/settings/actions/runners"
echo "The password for the user '${NEW_USER}' is: ${NEW_PASSWORD}"
