---
name: tailscale-relay
description: Comprehensive Tailscale relay service management with health monitoring, WebSocket testing, device discovery, and deployment automation
---

# Tailscale Relay Management

Streamline Tailscale tunnel relay development for CloudToLocalLLM with templates, diagnostic tools, and production checklists.

## Context

The Tailscale Relay service (`services/tailscale-relay/`) provides secure WebSocket tunneling to local LLM providers (Ollama, OpenClaw Gateway) via Tailscale network. It handles:
- JWT-authenticated WebSocket connections on `/tailscale/ws`
- Request forwarding to target devices (default: port 11434 for Ollama)
- Health monitoring on `/health` endpoint
- Multi-user support with JWT token validation

## Quick Start

### Start Relay Service
```bash
cd services/tailscale-relay
npm install
npm run dev  # Development with nodemon
npm start    # Production
```

### Health Check
```bash
curl http://localhost:3002/health
# Expected: {"status":"healthy","timestamp":"..."}
```

### Test WebSocket Connection
```bash
# Using the test script
./scripts/test-connection.sh
```

## Templates

### Relay Server Template
Location: `templates/relay-server.js`

```javascript
import express from 'express';
import http from 'http';
import { WebSocketServer } from 'ws';
import fetch from 'node-fetch';
import jwt from 'jsonwebtoken';

const app = express();
const server = http.createServer(app);

const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

app.get('/health', (req, res) => {
  res.send({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// WebSocket server for Tailscale connections
const wss = new WebSocketServer({
  server,
  path: '/tailscale/ws'
});

wss.on('connection', async (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const token = url.searchParams.get('token');
  const targetIp = url.searchParams.get('targetIp');

  if (!token || !targetIp) {
    ws.close(1008, 'Missing token or targetIp');
    return;
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const userId = decoded.sub || decoded.userId;
    console.log(`[${new Date().toISOString()}] Relay: User ${userId} → ${targetIp}`);

    ws.on('message', async (message) => {
      try {
        // Forward to target device (default: Ollama on 11434)
        const targetPort = process.env.TARGET_PORT || 11434;
        const response = await fetch(`http://${targetIp}:${targetPort}/api/generate`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: message
        });

        const data = await response.buffer();
        ws.send(data);
      } catch (error) {
        console.error(`Relay error to ${targetIp}:`, error.message);
        ws.send(JSON.stringify({
          error: 'Forward failed',
          details: error.message
        }));
      }
    });

    ws.on('close', () => {
      console.log(`[${new Date().toISOString()}] Relay: Disconnected ${userId}`);
    });

  } catch (error) {
    console.error('Relay auth failed:', error.message);
    ws.close(1008, 'Authentication failed');
  }
});

server.listen(PORT, () => {
  console.log(`Tailscale Relay listening on port ${PORT}`);
  console.log(`WebSocket path: /tailscale/ws?token=<jwt>&targetIp=<ip>`);
});
```

### Docker Compose Template
Location: `templates/docker-compose.yml`

```yaml
version: '3.8'
services:
  tailscale-relay:
    build: .
    ports:
      - "3002:3002"
    environment:
      - PORT=3002
      - JWT_SECRET=${JWT_SECRET}
      - TARGET_PORT=11434
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Scripts

### Health Check Script
Location: `scripts/health-check.sh`

```bash
#!/bin/bash
# Tailscale Relay Health Check

RELAY_URL="${RELAY_URL:-http://localhost:3002}"
ENDPOINT="/health"

echo "Checking Tailscale Relay health at $RELAY_URL$ENDPOINT..."

response=$(curl -s -w "\n%{http_code}" "$RELAY_URL$ENDPOINT")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
  status=$(echo "$body" | jq -r '.status')
  if [ "$status" = "healthy" ]; then
    echo "✓ Relay is healthy"
    echo "$body" | jq '.'
    exit 0
  fi
fi

echo "✗ Relay health check failed (HTTP $http_code)"
echo "$body"
exit 1
```

### WebSocket Connection Test
Location: `scripts/test-connection.sh`

```bash
#!/bin/bash
# Test WebSocket connection to Tailscale Relay

RELAY_URL="${RELAY_URL:-ws://localhost:3002/tailscale/ws}"
JWT_TOKEN="${JWT_TOKEN}"
TARGET_IP="${TARGET_IP:-100.100.100.100}"

if [ -z "$JWT_TOKEN" ]; then
  echo "Error: JWT_TOKEN environment variable required"
  echo "Usage: JWT_TOKEN=xxx TARGET_IP=xxx ./test-connection.sh"
  exit 1
fi

echo "Testing WebSocket connection to $RELAY_URL"
echo "Target IP: $TARGET_IP"

# Using websocat for testing (install: apt install websocat)
echo '{"model":"llama2","prompt":"Hello"}' | websocat "$RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP"

# Alternative: Use wscat
# echo '{"model":"llama2","prompt":"Hello"}' | wscat -c "$RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP"
```

### Tailscale Device Discovery
Location: `scripts/list-devices.sh`

```bash
#!/bin/bash
# List Tailscale devices on the tailnet

if ! command -v tailscale &> /dev/null; then
  echo "Error: tailscale CLI not installed"
  echo "Install: curl -fsSL https://tailscale.com/install.sh | sh"
  exit 1
fi

echo "Tailscale devices on your tailnet:"
echo "=================================="
tailscale status --json | jq -r '.Peer[] | select(.Online == true) | "\(.HostName)\t\(.TailscaleIPs[0])\t\(.OS)"' | column -t
```

## Flutter Client Integration Example

Location: `examples/client-implementation.dart`

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class TailscaleRelayClient {
  final String relayUrl;
  final String jwtToken;
  final String targetIp;

  TailscaleRelayClient({
    required this.relayUrl,
    required this.jwtToken,
    required this.targetIp,
  });

  WebSocketChannel connect() {
    final wsUrl = Uri.parse('$relayUrl/tailscale/ws?token=$jwtToken&targetIp=$targetIp');
    return WebSocketChannel.connect(wsUrl);
  }

  Future<void> sendRequest(Map<String, dynamic> request) async {
    final channel = connect();

    await channel.ready;

    channel.sink.add(jsonEncode(request));

    channel.stream.listen(
      (response) {
        print('Response: $response');
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        channel.sink.close();
      },
    );
  }
}
```

## Deployment Checklist

### Pre-Deployment
- [ ] JWT_SECRET configured in environment (strong random key)
- [ ] TARGET_PORT set correctly (11434 for Ollama, 18789 for OpenClaw)
- [ ] Firewall allows inbound traffic on PORT (default: 3002)
- [ ] Tailscale installed and authenticated on relay server
- [ ] TLS/SSL termination configured (reverse proxy)

### Security Verification
- [ ] JWT validation tested with expired/invalid tokens
- [ ] WebSocket connection timeout configured
- [ ] Rate limiting implemented (consider express-rate-limit)
- [ ] CORS configured if accessed from browser
- [ ] Input sanitization on targetIp parameter

### Monitoring Setup
- [ ] Health check endpoint accessible
- [ ] Logging configured (Winston or similar)
- [ ] Metrics collection (Prometheus format optional)
- [ ] Alert rules for connection failures
- [ ] Uptime monitoring configured

### Production Rollout
- [ ] Docker image built and pushed to registry
- [ ] docker-compose.yml deployed to server
- [ ] Health check passing: `curl http://localhost:3002/health`
- [ ] WebSocket connection tested with real client
- [ ] Log rotation configured
- [ ] Restart policy set (unless-stopped)

## Troubleshooting

### Relay Not Starting
```bash
# Check port availability
lsof -i :3002

# Verify Tailscale status
tailscale status

# Check JWT_SECRET is set
echo $JWT_SECRET
```

### WebSocket Connection Failures
```bash
# Test WebSocket directly
websocat ws://localhost:3002/tailscale/ws?token=xxx&targetIp=yyy

# Check relay logs
docker logs tailscale-relay -f

# Verify JWT token validity
echo "eyJ..." | jq -R 'split(".") | .[0],.[1] | @base64d | fromjson'
```

### Target Device Unreachable
```bash
# Ping target via Tailscale
ping <target-tailscale-ip>

# Check target service is running
curl http://<target-ip>:11434/api/tags

# Verify Tailscale network connectivity
tailscale ping <target-hostname>
```

## Related Files
- Relay service: `services/tailscale-relay/src/server.js`
- Flutter integration: `lib/screens/onboarding/steps/tailscale_discovery_step.dart`
- Onboarding service: `lib/services/onboarding/setup_wizard_service.dart`
- Documentation: `docs/user-guide/SETUP_GUIDE.md`
