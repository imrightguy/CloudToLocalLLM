# CloudToLocalLLM Docker Development Environment

> **Current orientation**: Docker development can include optional support model providers for testing memory/background features, but the main app channel still requires an agent runtime such as Hermes, OpenClaw, or a compatible agent gateway. Do not treat Ollama/LM Studio containers as primary app runtimes unless wrapped by a compatible agent runtime.

## Quick Start

### 1. Build and Validate Environment

```bash
# Validate the Docker development environment
./scripts/docker/validate_dev_environment.sh
```

### 2. Start Development

```bash
# Start the development environment
docker compose -f docker-compose.dev.yml up -d

# Enter the development container
docker compose -f docker-compose.dev.yml exec flutter bash

# Run health check
flutter-health
```

### 3. Develop CloudToLocalLLM

```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Build for Linux desktop
flutter-build

# Build for web
flutter-web

# Run tests
flutter test
```

## Features

- **Complete Flutter Environment**: Flutter 3.32.2+ with Dart SDK
- **System Tray Support**: GTK3 and system tray libraries pre-installed
- **Web Development**: Chrome for web testing and debugging
- **Security**: Non-root development environment
- **Persistence**: Cached dependencies and build artifacts
- **Health Monitoring**: Built-in validation and health checks

## System Requirements

- Docker 20.10+ with Docker Compose
- 4GB+ available RAM
- 10GB+ available disk space
- X11 forwarding support (for GUI testing on Linux/macOS)

## Container Specifications

| Component | Version/Details |
|-----------|----------------|
| Base Image | `ghcr.io/cirruslabs/flutter:3.32.2` |
| Flutter SDK | 3.32.2+ |
| Dart SDK | Bundled with Flutter |
| User | `flutter` (UID 1000) |
| Working Dir | `/workspace` |
| Platforms | Linux desktop, Web |

## Updated Package Support

The Docker environment fully supports CloudToLocalLLM v3.5.0+ with updated packages:

- ✅ `tray_manager: ^0.5.0` - System tray functionality
- ✅ `connectivity_plus: ^6.1.4` - Network connectivity monitoring  
- ✅ `web_socket_channel: ^3.0.3` - WebSocket communication
- ✅ `rxdart: ^0.28.0` - Reactive programming
- ✅ `go_router: ^15.1.3` - Navigation

## Available Commands

| Command | Description |
|---------|-------------|
| `flutter-health` | Run comprehensive health check |
| `flutter-build` | Build for Linux desktop |
| `flutter-web` | Build for web |
| `flutter-test` | Run tests |
| `flutter-analyze` | Analyze code |
| `flutter-clean` | Clean build artifacts |

## Ports

| Port | Service |
|------|---------|
| 8080 | Flutter web dev server |
| 3000 | Alternative web port |
| 4000 | API development |
| 5000 | Additional services |

## Volumes

| Volume | Purpose |
|--------|---------|
| `.:/workspace` | Source code |
| `flutter-pub-cache` | Package cache |
| `flutter-build-cache` | Build cache |

## Testing Profiles

### Basic Development

```bash
docker compose -f docker-compose.dev.yml up -d
```

### With Testing Services

```bash
# Includes optional support model provider and web server
docker compose -f docker-compose.dev.yml --profile testing up -d
```

## GUI Testing (System Tray)

### Linux

```bash
# Enable X11 forwarding
xhost +local:docker

# Run with GUI support
docker run -it --rm \
  -v $(pwd):/workspace \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  CloudToLocalLLM:dev
```

### macOS

```bash
# Install XQuartz first
brew install --cask xquartz

# Start XQuartz and enable network connections
# Then use same commands as Linux
```

### Windows (WSL2)

```bash
# Install VcXsrv or similar X11 server
# Configure DISPLAY variable
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0.0

# Use same Docker commands as Linux
```

## Troubleshooting

### Common Issues

1. **Permission Errors**

   ```bash
   sudo chown -R $(id -u):$(id -g) .
   ```

2. **X11 Display Issues**

   ```bash
   xhost +local:docker
   echo $DISPLAY
   ```

3. **Build Failures**

   ```bash
   flutter clean
   flutter pub get
   ```

4. **Container Health Check Fails**

   ```bash
   docker compose -f docker-compose.dev.yml exec flutter flutter-health
   ```

### Validation

Run the comprehensive validation script:

```bash
./scripts/docker/validate_dev_environment.sh
```

This will:

- ✅ Build the Docker image
- ✅ Test Flutter configuration
- ✅ Verify system dependencies
- ✅ Test CloudToLocalLLM build
- ✅ Validate Docker Compose setup
- ✅ Generate validation report

## Performance Tips

1. **Use Build Cache**: The container preserves Flutter build cache
2. **Persistent Volumes**: Package cache is preserved between runs
3. **Memory Allocation**: Ensure Docker has 4GB+ RAM allocated
4. **SSD Storage**: Use SSD for better build performance

## IDE Integration

### VS Code Remote Containers

1. Install "Remote - Containers" extension
2. Open project in VS Code
3. Command Palette → "Remote-Containers: Reopen in Container"
4. VS Code will use the development container automatically

### IntelliJ/Android Studio

1. Configure Docker as remote interpreter
2. Set Flutter SDK path to `/opt/flutter`
3. Configure remote development settings

## Security

- Container runs as non-root user (`flutter:1000`)
- Limited sudo access for development needs
- Isolated network environment
- Source code mounted read-write only in workspace

## Documentation

- [Docker Deployment Guide](DOCKER_DEPLOYMENT.md)
- [CloudToLocalLLM Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Development Workflow](../development/DEVELOPMENT_WORKFLOW.md)
- [Docker Scripts](../development/scripts/docker/README.md)

## Support

For Docker environment issues:

1. Run validation: `./scripts/docker/validate_dev_environment.sh`
2. Check health: `flutter-health`
3. Review logs: `docker compose logs flutter`
4. Consult [Docker Scripts](../development/scripts/docker/README.md)
