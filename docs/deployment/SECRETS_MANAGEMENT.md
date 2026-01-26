# CloudToLocalLLM - Secrets Management Guide

This document provides a comprehensive overview of all the required secrets for the CloudToLocalLLM CI/CD pipeline and local development.

## Table of Contents

1. [Overview](#overview)
2. [Required Secrets](#required-secrets)
3. [Obtaining Secrets](#obtaining-secrets)
4. [Setting Up Secrets](#setting-up-secrets)
5. [Security Best Practices](#security-best-practices)

## Overview

Secrets are sensitive pieces of information, such as API keys, passwords, and certificates, that are required for the application to function correctly. This guide provides a single source of truth for all the secrets used in the CloudToLocalLLM project.

## Required Secrets

| Secret Name | Description | Used In |
| --- | --- | --- |
| `GCP_PROJECT_ID` | Google Cloud Project ID | CI/CD |
| `GCP_SA_KEY` | Service account JSON key for Google Cloud authentication | CI/CD |
| `JWT_SECRET` | JWT secret for token signing | CI/CD |
| `JWT_AUDIENCE` | Auth0 API Audience | CI/CD |

## Obtaining Secrets

### Google Cloud Platform

* **`GCP_PROJECT_ID`**: Your Google Cloud Project ID.
* **`GCP_SA_KEY`**:
    1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
    2. Navigate to **IAM & Admin > Service Accounts**.
    3. Create or select a service account.
    4. Create a new JSON key and download it. The content of this file is the value for this secret.

### Authentication

* **`JWT_SECRET`**: A secure, randomly generated string for signing JWTs.
* **`JWT_AUDIENCE`**: Your Auth0 API audience.

## Setting Up Secrets

### GitHub Actions

1. Navigate to your repository on GitHub.
2. Go to **Settings > Secrets and variables > Actions**.
3. Click **New repository secret**.
4. Add each secret with the name and value as specified above.

### Local Development

1. Copy the `env.template` file to `.env`.
2. Update the `.env` file with the values for your local environment.

## Security Best Practices

* **Never commit secrets to version control.**
* **Use the principle of least privilege when creating service accounts.**
* **Rotate secrets periodically.**
* **Use a secrets management tool for local development.**
