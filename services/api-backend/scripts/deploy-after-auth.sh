#!/bin/bash

# CloudToLocalLLM Deployment Script (Post-Authentication)
# Run this after: gcloud auth login

set -e

PROJECT_ID="CloudToLocalLLM-468303"
INSTANCE_NAME="CloudToLocalLLM-db"
REGION="us-central1"
SERVICE_NAME="cloudtolocalllm-api"

echo " CloudToLocalLLM Deployment (Post-Authentication)"
echo "=================================================="

# Verify authentication
echo " Verifying authentication..."
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
if [ -z "$ACTIVE_ACCOUNT" ]; then
    echo " No active authentication. Please run: gcloud auth login"
    exit 1
fi
echo " Authenticated as: $ACTIVE_ACCOUNT"

# Set project
gcloud config set project $PROJECT_ID

# Check/create Cloud SQL instance
echo " Checking Cloud SQL instance..."
if gcloud sql instances describe $INSTANCE_NAME >/dev/null 2>&1; then
    echo " Instance exists"
    CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")
else
    echo "� Creating Cloud SQL instance..."
    bash scripts/setup-cloud-sql.sh
    CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")
fi

echo " Connection: $CONNECTION_NAME"

# Deploy to Cloud Run
echo "� Deploying to Cloud Run..."
bash scripts/deploy-cloud-run.sh

echo " Deployment complete!"
