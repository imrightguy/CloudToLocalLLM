# Chisel Deployment Guide

## Automatic Installation

Chisel is now automatically installed as part of the deployment process. No manual installation required!

## Server-Side Installation

### Docker Deployment

Chisel binary is automatically copied from the official `jpillora/chisel:latest` Docker image during the Docker build process.

**Files Updated:**

- `services/api-backend/Dockerfile.prod` - Uses multi-stage build to copy Chisel binary
- `config/docker/Dockerfile.api-backend` - Uses official Chisel image

**How it works:**

```dockerfile
# Copy Chisel binary from official Docker image
COPY --from=jpillora/chisel:latest /app/chisel /usr/local/bin/chisel
RUN chmod +x /usr/local/bin/chisel
```

**Environment Variables:**

- `CHISEL_BINARY` - Path to Chisel binary (default: `/usr/local/bin/chisel`)
- `CHISEL_PORT` - Chisel server port (default: `8080`)

### Docker Compose

The `docker-compose.production.yml` automatically:

- Builds the API backend with Chisel included
- Exposes Chisel port (8080)
- Sets environment variables

**No additional configuration needed!**

## Client-Side Installation (Flutter App)

### Automatic Binary Bundling

Chisel binaries are bundled with the Flutter app as assets. Use the provided scripts to download them before building:

**For Linux/macOS:**

```bash
bash scripts/download-chisel-binaries.sh
```

**For Windows (PowerShell):**

```powershell
.\scripts\setup-chisel-flutter-assets.ps1
```

**What it does:**

- Downloads Chisel binaries for Windows, macOS, and Linux (amd64 and arm64)
- Places them in `assets/chisel/` directory
- Flutter automatically bundles them with the app

**pubspec.yaml:**

```yaml
assets:
  - assets/chisel/  # Automatically includes all Chisel binaries
```

### Build-Time Download

You can also integrate this into your CI/CD pipeline:

```bash
# Before Flutter build
bash scripts/download-chisel-binaries.sh
flutter build windows
flutter build macos
flutter build linux
```

## Deployment Scripts

### Option 1: Use Official Docker Image (Recommended)

The Dockerfiles now use the official `jpillora/chisel` image - **no manual installation needed!**

### Option 2: Manual Binary Installation

If you need to install Chisel manually on a server:

**Linux/macOS:**

```bash
bash scripts/install-chisel.sh
```

**Or use official Chisel Docker image:**

```bash
docker pull jpillora/chisel:latest
docker run --rm jpillora/chisel:latest --version
```

## Verification

### Server

```bash
# Inside Docker container or on server
chisel --version
# Should output: chisel version 1.9.1 (or similar)
```

### Client

```bash
# Check Flutter assets include Chisel binaries
ls -la assets/chisel/
# Should show: chisel-windows.exe, chisel-darwin, chisel-linux, etc.
```

## CI/CD Integration

### GitHub Actions / GitLab CI

Add to your build pipeline:

```yaml
# Download Chisel binaries for Flutter app
- name: Download Chisel binaries
  run: bash scripts/download-chisel-binaries.sh

# Build Flutter app (binaries automatically included)
- name: Build Flutter app
  run: flutter build windows --release
```

### Docker Build

Chisel is automatically included - just build normally:

```bash
docker build -f services/api-backend/Dockerfile.prod -t api-backend .
```

## Troubleshooting

### Chisel not found on server

1. Check Dockerfile includes Chisel copy step
2. Verify build completed successfully
3. Check environment variable `CHISEL_BINARY` points to correct path

### Chisel not found in Flutter app

1. Run download script: `bash scripts/download-chisel-binaries.sh`
2. Verify `pubspec.yaml` includes `assets/chisel/`
3. Run `flutter pub get`
4. Rebuild app

### Version Issues

Update version in:

- Dockerfile build args: `ARG CHISEL_VERSION=1.9.1`
- Download scripts: `CHISEL_VERSION="${CHISEL_VERSION:-1.9.1}"`

## Official Docker Image

The official Chisel Docker image is available at:

- **Docker Hub**: `jpillora/chisel:latest`
- **GitHub**: https://github.com/jpillora/chisel

We use multi-stage builds to copy the binary from the official image, ensuring compatibility and easy updates.
