# Architecture Documentation

This directory contains comprehensive system architecture documentation for CloudToLocalLLM.

## 📚 Contents

### Core Architecture

- **[System Architecture](SYSTEM_ARCHITECTURE.md)** - Overall system design and components
- **[Secure Tunnel & Web Interface Design](SECURE_TUNNEL_WEB_INTERFACE_DESIGN.md)** - Core infrastructure design
- **[Tunnel System](TUNNEL_SYSTEM.md)** - Secure tunnel management architecture
- **[Service Lifecycle](service_lifecycle.md)** - Service management and lifecycle

### Platform Integration

- **[Unified Flutter Native System Tray](UNIFIED_FLUTTER_NATIVE_SYSTEM_TRAY.md)** - Desktop integration architecture
- **[Unified Flutter Web](UNIFIED_FLUTTER_WEB.md)** - Web platform architecture

### System Analysis & Codemap

- **[Architecture Codemap](architecture-codemap.md)** - Code organization and structure
- **[User Flow](user-flow.json)** - User interaction flows and patterns
- **[Tunnel Feature Analysis](TUNNEL_FEATURE_ANALYSIS.md)** - Tunnel system capabilities analysis

## 🔗 Related Documentation

- **[API Documentation](../API/README.md)** - API design and endpoints
- **[Development Documentation](../DEVELOPMENT/README.md)** - Development architecture patterns
- **[Operations Documentation](../OPERATIONS/README.md)** - Operational architecture considerations

## 📖 Architecture Overview

CloudToLocalLLM follows a hybrid architecture that bridges cloud-based AI services with local AI models:

### Key Components

1. **Flutter Frontend** - Cross-platform desktop and web application
2. **Node.js Backend** - API services and authentication
3. **Tunnel System** - Secure WebSocket tunneling for real-time communication
4. **Streaming Proxy** - Multi-tenant proxy for WebSocket connections

### Design Principles

- **Privacy-first** - Sensitive data stays local when possible
- **Cross-platform** - Consistent experience across Windows, Linux, and Web
- **Secure** - End-to-end encryption and secure tunneling
- **Scalable** - Multi-tenant architecture with user tier system
