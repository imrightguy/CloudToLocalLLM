#!/bin/bash

# Cloud SQL PostgreSQL Setup Script for CloudToLocalLLM
# Run this script to create and configure the PostgreSQL instance

set -e

# Configuration
PROJECT_ID="CloudToLocalLLM-468303"
INSTANCE_NAME="CloudToLocalLLM-db"
REGION="us-central1"  # Change to your preferred region
DATABASE_NAME="CloudToLocalLLM"
DB_USER="appuser"
TIER="db-f1-micro"  # Start small, can upgrade later

echo " Setting up Cloud SQL PostgreSQL instance for CloudToLocalLLM..."

# Set the project
gcloud config set project $PROJECT_ID

# Create the Cloud SQL PostgreSQL instance
echo "� Creating Cloud SQL PostgreSQL instance: $INSTANCE_NAME"
gcloud sql instances create $INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --tier=$TIER \
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

# Create the database
echo " Creating database: $DATABASE_NAME"
gcloud sql databases create $DATABASE_NAME --instance=$INSTANCE_NAME

# Create the application user
echo "� Creating database user: $DB_USER"
DB_PASSWORD=$(openssl rand -base64 32)
gcloud sql users create $DB_USER \
    --instance=$INSTANCE_NAME \
    --password=$DB_PASSWORD

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")

echo " Cloud SQL PostgreSQL instance setup complete!"
echo ""
echo "� Configuration Details:"
echo "  Instance Name: $INSTANCE_NAME"
echo "  Connection Name: $CONNECTION_NAME"
echo "  Database: $DATABASE_NAME"
echo "  User: $DB_USER"
echo "  Password: $DB_PASSWORD"
echo ""
echo " Environment Variables for Cloud Run:"
echo "  DB_TYPE=postgresql"
echo "  DB_NAME=$DATABASE_NAME"
echo "  DB_USER=$DB_USER"
echo "  DB_PASSWORD=$DB_PASSWORD"
echo "  DB_HOST=/cloudsql/$CONNECTION_NAME"
echo "  CLOUD_SQL_CONNECTION_NAME=$CONNECTION_NAME"
echo ""
echo "  IMPORTANT: Save the password securely!"
echo "� Next steps:"
echo "  1. Update your Cloud Run service with these environment variables"
echo "  2. Ensure your Cloud Run service account has 'Cloud SQL Client' role"
echo "  3. Deploy your updated backend with PostgreSQL support"

# Save configuration to file for reference
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
