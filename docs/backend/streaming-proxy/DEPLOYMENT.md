# Streaming Proxy Deployment Guide

## Overview

The streaming-proxy service is a Node.js application that provides WebSocket connection management, SSH tunneling, rate limiting, circuit breaking, and authentication for the Zoidbot system.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (AKS)                  │
│                                                              │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │  Ingress-Nginx │────────▶│ Streaming Proxy  │           │
│  │  (Load Balancer)│         │  (Port 3001)     │           │
│  └────────────────┘         │  - WebSocket     │           │
│         │                    │  - SSH Tunnel    │           │
│         │                    │  - Rate Limiting │           │
│         ▼                    │  - Auth          │           │
│  ┌────────────────┐         └──────────────────┘           │
│  │  API Backend   │                                         │
│  │  (Port 3000)   │                                         │
│  └────────────────┘                                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Options

### Option 1: Separate Streaming Proxy Service (Recommended)

Deploy streaming-proxy as a separate service alongside api-backend.

**Pros**:

- Independent scaling
- Isolated WebSocket connections
- Better resource management
- Easier debugging and monitoring

**Cons**:

- Additional deployment complexity
- More resources required

### Option 2: Integrated with API Backend

Integrate streaming-proxy code into the api-backend service.

**Pros**:

- Simpler deployment
- Fewer resources required
- Single service to manage

**Cons**:

- Coupled scaling
- Mixed concerns (REST + WebSocket)
- Harder to debug

## Current Status

**Current Architecture**: The streaming-proxy is currently a **separate service** with its own:

- Package.json
- Dockerfile (Dockerfile.prod)
- Source code (src/)
- Kubernetes deployment files (k8s/)

**Recommendation**: Deploy as a **separate service** for production.

## CI/CD Integration

### Current CI/CD Workflow

The `.github/workflows/deploy-aks.yml` currently deploys:

1. **Web Image**: Flutter web app
2. **API Backend**: REST API service

### Required Updates for Streaming Proxy

#### 1. Update CI/CD Workflow

Add streaming-proxy build and deployment to `.github/workflows/deploy-aks.yml`:

```yaml
env:
  REGISTRY: zoidbot
  API_IMAGE: zoidbot/zoidbot-api
  WEB_IMAGE: zoidbot/zoidbot-web
  STREAMING_PROXY_IMAGE: ghcr.io/zoidbot-online/zoidbot/streaming  # Add this

jobs:
  deploy:
    steps:
    # ... existing steps ...

    - name: Build and push streaming-proxy image
      run: |
        echo ${{ secrets.DOCKERHUB_TOKEN }} | docker login -u ${{ secrets.DOCKERHUB_USERNAME }} --password-stdin

        COMMIT_SHA=$(echo ${{ github.sha }} | cut -c1-8)
        docker build -f ./services/streaming-proxy/Dockerfile.prod \
          -t ${{ env.STREAMING_PROXY_IMAGE }}:$COMMIT_SHA \
          -t ${{ env.STREAMING_PROXY_IMAGE }}:latest .
        docker push ${{ env.STREAMING_PROXY_IMAGE }}:$COMMIT_SHA
        docker push ${{ env.STREAMING_PROXY_IMAGE }}:latest

    - name: Update Streaming Proxy deployment
      run: |
        COMMIT_SHA=$(echo ${{ github.sha }} | cut -c1-8)
        kubectl set image deployment/streaming-proxy \
          streaming-proxy=${{ env.STREAMING_PROXY_IMAGE }}:$COMMIT_SHA \
          -n zoidbot

    - name: Wait for rollout to complete
      run: |
        kubectl rollout status deployment/api-backend -n zoidbot --timeout=300s
        kubectl rollout status deployment/web -n zoidbot --timeout=300s
        kubectl rollout status deployment/streaming-proxy -n zoidbot --timeout=300s  # Add this
```

#### 2. Create Kubernetes Deployment

Create `k8s/streaming-proxy-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: streaming-proxy
  namespace: zoidbot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: streaming-proxy
  template:
    metadata:
      labels:
        app: streaming-proxy
    spec:
      containers:
      - name: streaming-proxy
        image: ghcr.io/zoidbot-online/zoidbot/streaming:latest
        ports:
        - containerPort: 3001
          name: websocket
        env:
        - name: NODE_ENV
          value: "production"
        - name: WEBSOCKET_PORT
          value: "3001"
        - name: SUPABASE_AUTH_DOMAIN
          valueFrom:
            secretKeyRef:
              name: zoidbot-secrets
              key: auth0-domain
        - name: SUPABASE_AUTH_AUDIENCE
          valueFrom:
            secretKeyRef:
              name: zoidbot-secrets
              key: auth0-audience
        - name: SUPABASE_AUTH_ISSUER
          valueFrom:
            secretKeyRef:
              name: zoidbot-secrets
              key: auth0-issuer
        - name: PING_INTERVAL
          value: "30000"
        - name: PONG_TIMEOUT
          value: "5000"
        - name: MAX_MISSED_PONGS
          value: "3"
        - name: COMPRESSION_ENABLED
          value: "true"
        - name: COMPRESSION_LEVEL
          value: "6"
        - name: MAX_FRAME_SIZE
          value: "1048576"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: streaming-proxy
  namespace: zoidbot
spec:
  selector:
    app: streaming-proxy
  ports:
  - port: 3001
    targetPort: 3001
    name: websocket
  type: ClusterIP
```

#### 3. Update Ingress Configuration

Update `k8s/ingress-nginx.yaml` to include streaming-proxy routes:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zoidbot-ingress
  namespace: zoidbot
  annotations:
    # ... existing annotations ...
    nginx.ingress.kubernetes.io/websocket-services: "streaming-proxy"
spec:
  rules:
  # ... existing rules ...
  - host: ws.zoidbot.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: streaming-proxy
            port:
              number: 3001
```

## Package Installation

The `ws` package and TypeScript types are now included in `package.json`:

```json
{
  "dependencies": {
    "ws": "^8.18.0"
  },
  "devDependencies": {
    "@types/ws": "^8.5.13",
    "typescript": "^5.7.2"
  }
}
```

### Installation Process

The Docker build process automatically installs dependencies:

```dockerfile
# In Dockerfile.prod
FROM node:24-alpine AS base
WORKDIR /app
COPY services/streaming-proxy/package*.json ./
RUN npm ci  # ← This installs ws and all dependencies
```

### CI/CD Flow

1. **Code Push**: Developer pushes code to `main` branch
2. **CI Trigger**: GitHub Actions workflow triggers
3. **Docker Build**:
   - Copies `package.json` and `package-lock.json`
   - Runs `npm ci` (installs `ws` and all dependencies)
   - Copies source code
   - Builds Docker image
4. **Docker Push**: Pushes image to Docker Hub
5. **Kubernetes Deploy**: Updates deployment with new image
6. **Rollout**: Kubernetes rolls out new pods with updated code

## Environment Variables

Required environment variables for streaming-proxy:

```bash
# Auth0 Configuration
SUPABASE_AUTH_DOMAIN=your-domain.auth0.com
SUPABASE_AUTH_AUDIENCE=https://api.zoidbot.com
SUPABASE_AUTH_ISSUER=https://your-domain.auth0.com/

# WebSocket Configuration
WEBSOCKET_PORT=3001
WEBSOCKET_PATH=/ws

# Heartbeat Configuration
PING_INTERVAL=30000
PONG_TIMEOUT=5000
MAX_MISSED_PONGS=3

# Compression Configuration
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL=6
COMPRESSION_THRESHOLD=1024

# Frame Size Configuration
MAX_FRAME_SIZE=1048576
FRAME_WARN_THRESHOLD=524288

# Close Configuration
CLOSE_TIMEOUT=5000

# Rate Limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=100
RATE_LIMIT_MAX_CONCURRENT=3

# Logging
LOG_LEVEL=info
NODE_ENV=production
```

## Secrets Management

Add to `k8s/secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zoidbot-secrets
  namespace: zoidbot
type: Opaque
stringData:
  auth0-domain: "your-domain.auth0.com"
  auth0-audience: "https://api.zoidbot.com"
  auth0-issuer: "https://your-domain.auth0.com/"
```

## Deployment Steps

### 1. Update Package Dependencies

```bash
cd services/streaming-proxy
npm install
```

### 2. Build Docker Image Locally (Optional)

```bash
docker build -f services/streaming-proxy/Dockerfile.prod -t ghcr.io/zoidbot-online/zoidbot/streaming:latest .
```

### 3. Push to Docker Hub (Optional)

```bash
docker push ghcr.io/zoidbot-online/zoidbot/streaming:latest
```

### 4. Deploy to Kubernetes

```bash
# Create deployment
kubectl apply -f k8s/streaming-proxy-deployment.yaml

# Verify deployment
kubectl get pods -n zoidbot
kubectl get svc -n zoidbot
kubectl logs -f deployment/streaming-proxy -n zoidbot
```

### 5. Update Ingress

```bash
kubectl apply -f k8s/ingress-nginx.yaml
```

### 6. Test Connection

```bash
# Test WebSocket connection
wscat -c "wss://ws.zoidbot.online?token=YOUR_JWT_TOKEN"
```

## Monitoring

### Health Check

```bash
curl https://ws.zoidbot.online/health
```

### Logs

```bash
# View logs
kubectl logs -f deployment/streaming-proxy -n zoidbot

# View logs for specific pod
kubectl logs -f streaming-proxy-xxxxx-xxxxx -n zoidbot
```

### Metrics

```bash
# Get pod metrics
kubectl top pods -n zoidbot

# Get deployment status
kubectl get deployment streaming-proxy -n zoidbot
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment streaming-proxy --replicas=3 -n zoidbot
```

### Auto-scaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: streaming-proxy-hpa
  namespace: zoidbot
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: streaming-proxy
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Troubleshooting

### Issue: Pods not starting

```bash
# Check pod status
kubectl describe pod streaming-proxy-xxxxx -n zoidbot

# Check logs
kubectl logs streaming-proxy-xxxxx -n zoidbot
```

### Issue: WebSocket connection fails

```bash
# Check service
kubectl get svc streaming-proxy -n zoidbot

# Check ingress
kubectl get ingress -n zoidbot

# Test from inside cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
apk add curl
curl http://streaming-proxy.zoidbot.svc.cluster.local:3001/health
```

### Issue: Authentication fails

```bash
# Check secrets
kubectl get secret zoidbot-secrets -n zoidbot -o yaml

# Verify Auth0 configuration
kubectl exec -it streaming-proxy-xxxxx -n zoidbot -- env | grep SUPABASE_AUTH
```

## Summary

**Deployment Architecture**: Streaming proxy runs as a **separate service** in the Kubernetes cluster.

**CI/CD Integration**:

- ✅ Package dependencies (`ws`) automatically installed during Docker build
- ✅ Docker image built and pushed to Docker Hub
- ✅ Kubernetes deployment updated automatically
- ⏳ Need to add streaming-proxy steps to CI/CD workflow
- ⏳ Need to create Kubernetes deployment manifest

**Next Steps**:

1. Create `k8s/streaming-proxy-deployment.yaml`
2. Update `.github/workflows/deploy-aks.yml` to build and deploy streaming-proxy
3. Update `k8s/ingress-nginx.yaml` to route WebSocket traffic
4. Add secrets to `k8s/secrets.yaml`
5. Deploy and test

The implementation is ready for deployment once the Kubernetes manifests and CI/CD workflow are updated.
