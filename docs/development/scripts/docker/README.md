# CloudToLocalLLM Docker Scripts

**⚠️ NOTICE: AUR Docker Building Temporarily Removed**

The Docker-based AUR building system has been temporarily removed as part of the v3.10.3 Unified Flutter-Native Architecture transition. See [AUR Status Documentation](../../docs/DEPLOYMENT/AUR_STATUS.md) for complete details.

## 📋 Current Status

**TEMPORARILY REMOVED**: All AUR-related Docker infrastructure

- Docker-based AUR building scripts
- Arch Linux container configurations
- AUR package automation tools

**REASON**: Streamlining build processes during architecture transition

**TIMELINE**: Reintegration planned for Q3-Q4 2025

## 📖 Documentation

For complete details about the AUR removal and planned reintegration:

- **[AUR Status Documentation](../../docs/DEPLOYMENT/AUR_STATUS.md)**

## 🔄 Current Docker Usage

This directory currently contains:

- **validate_dev_environment.sh** - Development environment validation script

## 📁 Directory Structure

```
scripts/docker/
├── README.md                    # This documentation
└── validate_dev_environment.sh # Development environment validation
```

## 🔧 Available Scripts

### Development Environment Validation

**`validate_dev_environment.sh`** - Validates development environment setup:

```bash
# Validate development environment
./scripts/docker/validate_dev_environment.sh

# Check Docker installation and configuration
./scripts/docker/validate_dev_environment.sh --docker-check

# Validate Flutter development setup
./scripts/docker/validate_dev_environment.sh --flutter-check
```

## 🏗️ Future Docker Usage

When AUR support is reintegrated, this directory will contain:

- Docker-based AUR building infrastructure
- Arch Linux container configurations
- Universal build wrapper scripts
- Cross-platform development containers

## 🔗 Related Documentation

- **[AUR Status Documentation](../../docs/DEPLOYMENT/AUR_STATUS.md)** - Complete AUR removal and reintegration details
- [Deployment Workflow](../deploy/README.md) - Current deployment processes
- [Package Building](../packaging/README.md) - Available package formats
- [Version Management](../version_manager.sh) - Version management tools
