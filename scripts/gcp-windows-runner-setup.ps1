# This script automates the creation of a GitHub Actions self-hosted runner on a GCP Windows VM.
#
# IMPORTANT: Replace the placeholder values with your actual GCP project details and GitHub runner token.
#
# Usage:
#   1. Ensure you are authenticated with gcloud and have the necessary permissions.
#   2. Run the script: powershell -File scripts/gcp-windows-runner-setup.ps1

# --- Configuration Variables ---
$GCP_PROJECT_ID = "zoidbot-468303"
$GCP_REGION = "us-central1"
$GCP_ZONE = "us-central1-a"
$VM_NAME = "github-runner-windows-$(Get-Date -Format yyyyMMddHHmmss)"
$MACHINE_TYPE = "e2-medium"
$IMAGE_FAMILY = "windows-2019"
$IMAGE_PROJECT = "windows-cloud"
$GITHUB_RUNNER_ORG_URL = "https://github.com/Zoidbot-online/Zoidbot" # e.g., https://github.com/Zoidbot-online
$GITHUB_RUNNER_TOKEN = "BOBH5XEA7XJPPTNW2CYI7F3IUR2RG" # Obtain from GitHub -> Settings -> Actions -> Runners -> New runner

# --- Startup Script for the VM (PowerShell) ---
$StartupScript = @"
<powershell>
# Install Git and Chocolatey
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command \"iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))\"" -Wait -Verb RunAs
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
</powershell>
"@

# --- Create the VM Instance ---
Write-Host "Creating GCP VM instance: $($VM_NAME)..."
gcloud compute instances create $VM_NAME \
  --project=$GCP_PROJECT_ID \
  --zone=$GCP_ZONE \
  --machine-type=$MACHINE_TYPE \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --metadata=startup-script-ps1=$StartupScript \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=http-server,https-server

Write-Host "VM instance creation initiated. It may take a few minutes for the runner to come online."
Write-Host "Monitor the runner status in GitHub: ${GITHUB_RUNNER_ORG_URL}/settings/actions/runners"
