#!/bin/bash

# Cloud Run Deployment Script with PostgreSQL Configuration
# This script deploys the CloudToLocalLLM API backend with PostgreSQL support

set -e

# Configuration
PROJECT_ID="CloudToLocalLLM-468303"
SERVICE_NAME="cloudtolocalllm-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

# Load Cloud SQL configuration if available
if [ -f "cloud-sql-config.env" ]; then
    echo "� Loading Cloud SQL configuration..."
    source cloud-sql-config.env
else
    echo "  cloud-sql-config.env not found. Please run setup-cloud-sql.sh first or set environment variables manually."
    exit 1
fi

echo " Deploying CloudToLocalLLM API Backend to Cloud Run with PostgreSQL..."

# Set the project
gcloud config set project $PROJECT_ID

# Build and push the container image
echo "� Building container image..."
gcloud builds submit --tag $IMAGE_NAME .

# Deploy to Cloud Run with PostgreSQL configuration
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

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format "value(status.url)")

echo " Deployment complete!"
echo ""
echo " Service URL: $SERVICE_URL"
echo " Health Check: $SERVICE_URL/api/db/health"
echo ""
echo " Test the deployment:"
echo "  curl $SERVICE_URL/api/db/health"
echo ""
echo " Monitor logs:"
echo "  gcloud logs tail --service=$SERVICE_NAME"

# Test the health endpoint
echo " Testing database health endpoint..."
sleep 10  # Wait for deployment to be ready
if curl -f "$SERVICE_URL/api/db/health" > /dev/null 2>&1; then
    echo " Health check passed!"
else
    echo " Health check failed. Check logs:"
    echo "  gcloud logs tail --service=$SERVICE_NAME --limit=50"
fi
