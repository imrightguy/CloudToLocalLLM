---
name: tunnel-config
description: Create SSH tunnel configuration for connecting to remote LLM gateway
disable-model-invocation: true
---

Create a new SSH tunnel configuration for connecting to {{remote_host}}.

Include:
- Tunnel configuration in TunnelConfigManager
- SSH credentials setup (key-based or password)
- Health check configuration
- Automatic reconnection settings
- WebSocket tunneling for LLM streaming

Follow existing patterns in lib/services/tunnel/ and lib/services/ssh/

Tunnel configuration structure:

```dart
import 'package:cloudtolocalllm/models/tunnel_config.dart';

// Create tunnel configuration
final tunnelConfig = TunnelConfig(
  id: '{{tunnel_id}}',
  name: '{{tunnel_name}}',
  remoteHost: '{{remote_host}}',  // e.g., '192.168.1.100' or 'llm.example.com'
  remotePort: {{remote_port}},       // e.g., 18789 (OpenClaw Gateway)
  localPort: {{local_port}},         // e.g., 18900 (local forward port)
  sshHost: '{{ssh_host}}',          // SSH bastion host (optional)
  sshPort: {{ssh_port}},            // Default: 22
  sshUsername: '{{ssh_username}}',
  sshPassword: null,  // Use key-based auth when possible
  sshKeyPath: '~/.ssh/id_rsa',  // Path to private key
  enabled: true,
  autoConnect: true,
  healthCheckInterval: Duration(seconds: 30),
  reconnectInterval: Duration(seconds: 5),
  maxRetries: 10,
);
```

SSH tunnel types:

**1. Local Port Forwarding (access remote LLM locally):**
```dart
final tunnelConfig = TunnelConfig(
  id: 'local-llm-tunnel',
  name: 'Local LLM Gateway',
  remoteHost: 'localhost',  // Relative to SSH host
  remotePort: 18789,         // OpenClaw Gateway port
  localPort: 18900,          // Expose locally on port 18900
  sshHost: 'remote-server.com',
  sshUsername: 'user',
  sshKeyPath: '~/.ssh/id_rsa',
);
```

**2. Remote Port Forwarding (expose local LLM to remote):**
```dart
final tunnelConfig = TunnelConfig(
  id: 'remote-expose-tunnel',
  name: 'Expose Local LLM',
  remoteHost: '0.0.0.0',  // Bind to all interfaces
  remotePort: 18789,         // Listen on remote server
  localPort: 1234,           // Local LM Studio port
  sshHost: 'public-server.com',
  sshUsername: 'user',
  sshKeyPath: '~/.ssh/id_rsa',
);
```

**3. Dynamic Port Forwarding (SOCKS proxy):**
```dart
final tunnelConfig = TunnelConfig(
  id: 'socks-proxy-tunnel',
  name: 'SOCKS Proxy',
  tunnelType: TunnelType.dynamic,
  localPort: 1080,           // SOCKS proxy port
  sshHost: 'bastion.example.com',
  sshUsername: 'user',
  sshKeyPath: '~/.ssh/id_rsa',
);
```

SSH key setup (recommended):

```bash
# Generate SSH key pair (if not exists)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy public key to remote server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote-host.com

# Test connection
ssh -i ~/.ssh/id_ed25519 user@remote-host.com
```

WebSocket tunneling for LLM streaming:

The tunnel service creates WebSocket connections for real-time LLM communication:

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'lib/services/ssh/websocket_ssh_socket.dart';

// Create WebSocket through SSH tunnel
final wsUrl = 'ws://localhost:18900/v1/stream';  // Local forwarded port
final channel = WebSocketChannel.connect(wsUrl);

// Subscribe to streaming responses
channel.stream.listen(
  (message) {
    // Handle streaming LLM response
    final response = parseLlmResponse(message);
    // Update UI
  },
  onError: (error) {
    // Handle connection errors
    debugPrint('[Tunnel] WebSocket error: $error');
  },
  onDone: () {
    // Connection closed
    debugPrint('[Tunnel] WebSocket closed');
  },
);
```

Tunnel service registration in lib/di/locator.dart:

```dart
// In setupAuthenticatedServices()
final tunnelConfigManager = TunnelConfigManager();
serviceLocator.registerSingleton<TunnelConfigManager>(tunnelConfigManager);

final tunnelService = TunnelService(
  tunnelConfigManager: tunnelConfigManager,
  authService: authService,
);
serviceLocator.registerSingleton<TunnelService>(tunnelService);

// Start auto-connect tunnels
await tunnelService.connectEnabledTunnels();
```

Health monitoring:

```dart
// Health check implementation
class TunnelHealthChecker {
  Future<bool> checkTunnel(TunnelConfig config) async {
    try {
      final socket = await Socket.connect(
        'localhost',
        config.localPort,
        timeout: Duration(seconds: 5),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  void startHealthMonitoring(TunnelConfig config) {
    Timer.periodic(
      config.healthCheckInterval,
      (timer) async {
        final isHealthy = await checkTunnel(config);
        if (!isHealthy) {
          debugPrint('[Tunnel] ${config.name} is unhealthy, reconnecting...');
          await tunnelService.reconnect(config.id);
        }
      },
    );
  }
}
```

Automatic reconnection:

```dart
// Exponential backoff reconnection
Future<void> reconnectWithBackoff(TunnelConfig config) async {
  int attempt = 0;
  final maxAttempts = config.maxRetries;

  while (attempt < maxAttempts) {
    try {
      await tunnelService.connect(config.id);
      debugPrint('[Tunnel] ${config.name} reconnected successfully');
      return;
    } catch (e) {
      attempt++;
      if (attempt < maxAttempts) {
        final delay = Duration(
          seconds: config.reconnectInterval.inSeconds * (2 ^ attempt),
        );
        debugPrint('[Tunnel] Reconnect attempt $attempt failed, retrying in $delay...');
        await Future.delayed(delay);
      }
    }
  }

  throw TunnelConnectionException(
    'Failed to reconnect after $maxAttempts attempts',
  );
}
```

Configuration persistence (SQLite):

```dart
// Store tunnel configs in database
class TunnelConfigStorage {
  Future<void> saveConfig(TunnelConfig config) async {
    // Save to database
  }

  Future<List<TunnelConfig>> getAllConfigs() async {
    // Load from database
  }

  Future<void> deleteConfig(String tunnelId) async {
    // Delete from database
  }
}
```

Testing the tunnel:

```bash
# Test SSH connection
ssh -i ~/.ssh/id_ed25519 user@remote-host.com

# Test local port forwarding
ssh -L 18900:localhost:18789 user@remote-host.com

# Test LLM connection through tunnel
curl http://localhost:18900/health
curl http://localhost:18900/v1/models

# Test WebSocket connection
wscat -c ws://localhost:18900/v1/stream
```

Monitoring tunnel status:

```dart
// Subscribe to tunnel state changes
tunnelService.stateChanges.listen((state) {
  switch (state.status) {
    case TunnelStatus.connected:
      debugPrint('[Tunnel] Connected to ${state.tunnel.name}');
      break;
    case TunnelStatus.connecting:
      debugPrint('[Tunnel] Connecting to ${state.tunnel.name}...');
      break;
    case TunnelStatus.disconnected:
      debugPrint('[Tunnel] Disconnected from ${state.tunnel.name}');
      break;
    case TunnelStatus.error:
      debugPrint('[Tunnel] Error: ${state.error}');
      break;
  }
});
```

Common tunnel configurations:

**OpenClaw Gateway (local):**
```dart
TunnelConfig(
  id: 'openclaw-local',
  name: 'OpenClaw Gateway',
  remoteHost: 'localhost',
  remotePort: 18789,
  localPort: 18900,
  enabled: true,
)
```

**Remote LLM Server:**
```dart
TunnelConfig(
  id: 'remote-llm',
  name: 'Remote LLM Server',
  remoteHost: 'localhost',
  remotePort: 1234,  // LM Studio
  localPort: 18901,
  sshHost: 'cloud-server.com',
  sshUsername: 'llm-user',
  sshKeyPath: '~/.ssh/id_rsa',
  enabled: true,
  autoConnect: true,
)
```

Security best practices:
- Use SSH key authentication, not passwords
- Restrict SSH user permissions on remote server
- Use bastion hosts for production environments
- Enable SSH key passphrase protection
- Rotate SSH keys regularly
- Monitor tunnel access logs
- Use firewall rules to restrict port access
