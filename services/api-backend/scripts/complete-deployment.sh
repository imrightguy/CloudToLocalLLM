#!/bin/bash

# Complete CloudToLocalLLM Deployment Script
# This script performs the full deployment after authentication is complete

set -e

# Configuration
PROJECT_ID="CloudToLocalLLM-468303"
INSTANCE_NAME="CloudToLocalLLM-db"
REGION="us-central1"
SERVICE_NAME="cloudtolocalllm-api"
DATABASE_NAME="CloudToLocalLLM"
DB_USER="appuser"

echo " CloudToLocalLLM Complete Deployment Script"
echo "=============================================="
echo ""

# Check authentication
echo " Checking authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo " No active authentication found. Please run:"
    echo "   gcloud auth login"
    exit 1
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo " Authenticated as: $ACTIVE_ACCOUNT"

# Set project
echo "� Setting project: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Check if Cloud SQL instance exists
echo " Checking for existing Cloud SQL instance..."
if gcloud sql instances describe $INSTANCE_NAME >/dev/null 2>&1; then
    echo " Cloud SQL instance '$INSTANCE_NAME' already exists"
    CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")
    echo "   Connection Name: $CONNECTION_NAME"
else
    echo "� Creating Cloud SQL PostgreSQL instance: $INSTANCE_NAME"
    
    # Generate secure password
    DB_PASSWORD=$(openssl rand -base64 32)
    
    # Create instance
    gcloud sql instances create $INSTANCE_NAME \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=$REGION \
        --storage-type=SSD \
        --storage-size=10GB \
        --storage-auto-increase \
        --backup-start-time=03:00 \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=04 \
        --deletion-protection
    
    echo "⏳ Waiting for instance to be ready..."
    gcloud sql instances describe $INSTANCE_NAME --format="value(state)" | grep -q RUNNABLE
    
    # Create database
    echo " Creating database: $DATABASE_NAME"
    gcloud sql databases create $DATABASE_NAME --instance=$INSTANCE_NAME
    
    # Create user
    echo "� Creating database user: $DB_USER"
    gcloud sql users create $DB_USER \
        --instance=$INSTANCE_NAME \
        --password=$DB_PASSWORD
    
    CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")
    
    # Save configuration
    cat > cloud-sql-config.env << EOF
# Cloud SQL Configuration for CloudToLocalLLM
# Generated on $(date)

DB_TYPE=postgresql
DB_NAME=$DATABASE_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=/cloudsql/$CONNECTION_NAME
CLOUD_SQL_CONNECTION_NAME=$CONNECTION_NAME
INSTANCE_NAME=$INSTANCE_NAME
PROJECT_ID=$PROJECT_ID
REGION=$REGION
EOF
    
    echo "� Configuration saved to: cloud-sql-config.env"
    echo "  Database password: $DB_PASSWORD"
    echo "   Please save this password securely!"
fi

# Load configuration
if [ -f "cloud-sql-config.env" ]; then
    source cloud-sql-config.env
    echo "� Loaded Cloud SQL configuration"
else
    echo " cloud-sql-config.env not found. Please check Cloud SQL setup."
    exit 1
fi

# Build and deploy
echo "� Building container image..."
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"
gcloud builds submit --tag $IMAGE_NAME .

echo "� Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --timeout 300 \
    --concurrency 100 \
    --max-instances 10 \
    --set-env-vars "NODE_ENV=production" \
    --set-env-vars "PORT=8080" \
    --set-env-vars "DB_TYPE=$DB_TYPE" \
    --set-env-vars "DB_NAME=$DB_NAME" \
    --set-env-vars "DB_USER=$DB_USER" \
    --set-env-vars "DB_PASSWORD=$DB_PASSWORD" \
    --set-env-vars "DB_HOST=$DB_HOST" \
    --set-env-vars "CLOUD_SQL_CONNECTION_NAME=$CLOUD_SQL_CONNECTION_NAME" \
    --add-cloudsql-instances $CLOUD_SQL_CONNECTION_NAME

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format "value(status.url)")

echo " Deployment complete!"
echo ""
echo " Service URL: $SERVICE_URL"
echo " Health Check: $SERVICE_URL/api/db/health"
echo ""

# Test deployment
echo " Testing deployment..."
sleep 15  # Wait for deployment to be ready

echo "Testing database health..."
if curl -f "$SERVICE_URL/api/db/health" >/dev/null 2>&1; then
    echo " Database health check passed!"
    
    # Run comprehensive tests
    echo "Running comprehensive authentication tests..."
    SERVICE_URL="$SERVICE_URL" npm run test:auth-flow
    
else
    echo " Health check failed. Checking logs..."
    gcloud logs tail --service=$SERVICE_NAME --limit=20
fi

echo ""
echo "� Deployment Summary"
echo "===================="
echo "Service URL: $SERVICE_URL"
echo "Database: PostgreSQL ($CONNECTION_NAME)"
echo "Health Endpoint: $SERVICE_URL/api/db/health"
echo ""
echo " Monitor logs:"
echo "  gcloud logs tail --service=$SERVICE_NAME"
echo ""
echo " Update frontend to use: $SERVICE_URL"
