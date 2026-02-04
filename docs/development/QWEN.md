# Zoidbot - Qwen Context

## Project Overview

Zoidbot is a revolutionary Flutter-based application that bridges the gap between cloud-based AI services and local AI models. It provides a seamless, secure, and efficient way to interact with various AI models while maintaining complete control over your data and privacy.

The project uses a hybrid architecture supporting both cloud-based (OpenAI, Anthropic) and local AI models (via Ollama). It's built with Flutter for cross-platform support (Windows, Linux, Web) and incorporates secure authentication, real-time communication via WebSockets, and end-to-end encryption.

### Key Technologies

- **Flutter 3.8+** - Cross-platform UI framework
- **Dart** - Primary programming language
- **Node.js** - Development and testing environment
- **Ollama** - Local AI model support
- **WebSocket** - Real-time communication
- **OAuth2** - Secure authentication

## Project Structure

```
├── android/              # Android-specific code
├── assets/               # Application assets (images, version.json)
├── config/               # Configuration files
├── docs/                 # Documentation
├── lib/                  # Main Flutter application source code
│   ├── shared/           # Shared library code
│   └── config/           # App configuration
├── scripts/              # Automation scripts (PowerShell, Bash)
├── services/             # Backend services
├── test/                 # Unit tests
├── web/                  # Web-specific files
├── windows/              # Windows-specific code
├── package.json          # Node.js dependencies and scripts
├── pubspec.yaml          # Flutter/Dart dependencies
├── README.md             # Main documentation

```

## Building and Running

### Prerequisites

- Flutter SDK (3.8 or higher)
- Node.js (for development and testing)
- Git (for version control)
- Ollama (optional, for local AI models)

### Installation

```bash
# Clone the repository
git clone https://github.com/Zoidbot-online/Zoidbot.git
cd Zoidbot

# Install dependencies
flutter pub get
npm install
```

### Running the Application

```bash
# For desktop (Windows/Linux)
flutter run -d windows
flutter run -d linux

# For web
flutter run -d chrome
```

### Building

```bash
# Build for Windows
flutter build windows --release

# Build for Linux
flutter build linux --release

# Build for Web
flutter build web --release
```

### Testing

```bash
# Run Flutter tests
flutter test

# Run e2e tests
npm test
```

## Development Conventions

### Version Management

Zoidbot uses a sophisticated version management system with automated updates across all relevant files:

- **Version Format**: `MAJOR.MINOR.PATCH+BUILD_NUMBER` (e.g., `4.1.1+202508071645`)
- **Build Numbers**: Timestamp format `YYYYMMDDHHMM`
- **Version Script**: `scripts/version_manager.sh` handles version increments and updates

Semantic Versioning Strategy:

- **PATCH** (`0.0.X`): Hotfixes, security updates, critical bug fixes
- **MINOR** (`0.X.0`): Feature additions, UI enhancements, planned functionality
- **MAJOR** (`X.0.0`): Breaking changes, architectural overhauls

### Code Style

- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure all tests pass

### Automated Deployment

The project uses a comprehensive CI/CD pipeline:

- Desktop applications built via PowerShell scripts
- Cloud deployment to Google Cloud Run via GitHub Actions
- Keyless authentication using GitHub OIDC and Google Cloud Workload Identity Federation

## Key Features

1. **Hybrid AI Architecture**: Seamlessly switch between cloud-based and local AI models
2. **Privacy-First Design**: Keep sensitive data local while leveraging cloud AI when needed
3. **Cross-Platform Support**: Available on Windows, Linux, and Web platforms
4. **Secure Authentication**: OAuth2-based authentication with encrypted token storage
5. **Real-Time Communication**: WebSocket-based tunneling for instant AI responses
6. **Model Flexibility**: Support for OpenAI, Anthropic, and local Ollama models
7. **User-Friendly Interface**: Intuitive Flutter-based UI with responsive design

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# API Configuration
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key

# Server Configuration
SERVER_HOST=localhost
SERVER_PORT=3000

# Database Configuration
DATABASE_URL=your_database_url

# OAuth Configuration
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
```

### Local AI Models

To use local AI models with Ollama:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Download models
ollama pull llama3.2:1b
ollama pull codellama:7b
ollama pull mistral:7b
```

## Current Version Information

- **Main Version**: 4.1.1
- **Build Number**: 202508071645
- **Build Date**: 2025-08-07T20:45:24Z
- **Git Commit**: af642615e

Version information is maintained in multiple files:

- `pubspec.yaml` - Main Flutter project version
- `lib/shared/lib/version.dart` - Shared version constants
- `assets/version.json` - Runtime version information
- `README.md` - Version badge
- `package.json` - Node.js package version
