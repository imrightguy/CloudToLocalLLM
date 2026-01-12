# CloudToLocalLLM System Architecture

## 📋 Overview

CloudToLocalLLM implements a comprehensive multi-component architecture designed for reliability, scalability, and user experience. This document consolidates all architectural information into a single authoritative reference.

**Key Architectural Principles:**
- **Unified Flutter-Native Application**: A single Flutter application for the desktop client, including system tray functionality.
- **Simplified Tunnel System**: A streamlined, single WebSocket connection for communication between the web UI and the desktop client.
- **Tier-Based Functionality**: A flexible architecture that supports both free and premium user tiers with different features.
- **Zero-Storage Design**: No persistent user data in the cloud infrastructure.

---

## 🏗️ 1. Unified Flutter-Native Architecture

### **Overview**
CloudToLocalLLM v3.10.3+ implements a Unified Flutter-Native Architecture that integrates system tray functionality directly into the main Flutter application using the `tray_manager` package. This modern approach eliminates external dependencies while providing robust cross-platform system tray support.

### **Core Components**

#### **1.1 Native Tray Service**
- **Technology**: Flutter-native with `tray_manager` package
- **Location**: `lib/services/native_tray_service.dart`
- **Operation**: Integrated within the main Flutter application
- **Responsibilities**:
  - Cross-platform system tray integration (Linux/Windows/macOS)
  - Real-time connection status display with visual indicators
  - Context menu management (Show/Hide/Settings/Quit)
  - Integration with the tunnel manager service for live updates

#### **1.2 Tunnel Manager Service Integration**
- **Purpose**: Centralized connection and status management
- **Location**: `lib/services/tunnel_manager_service.dart`
- **Features**:
  - Local Ollama connection monitoring
  - Cloud proxy connection management
  - Health checks and automatic reconnection
  - WebSocket support for real-time updates
  - Status broadcasting to the system tray

#### **1.3 Unified Application Architecture**
- **Role**: A single Flutter application handling all functionality
- **Integration**: System tray, UI, chat, and connection management in one process
- **Benefits**: Simplified deployment, reduced complexity, and a single executable

### **Architecture Benefits**
- **Unified Codebase**: All functionality in a single Flutter application
- **Native Performance**: Direct Flutter integration without IPC overhead
- **Cross-Platform Consistency**: The same implementation across all platforms
- **Simplified Deployment**: A single executable with no external dependencies
- **Real-Time Updates**: Direct service integration for instant status updates

---

## 🌐 2. Simplified Tunnel System

### **Overview**
The Simplified Tunnel System replaces the complex multi-layered tunnel architecture with a streamlined design that reduces codebase complexity while maintaining security and reliability.

### **Key Features**
- **Single WebSocket Connection**: One persistent connection per desktop client.
- **Standard HTTP Proxy Patterns**: No custom tunnel-aware code is required.
- **JWT Authentication**: Simple token-based user identification.
- **Request Correlation**: Unique IDs for matching requests with responses.
- **No Custom Encryption**: Relies on HTTPS/WSS for transport security.

### **Architecture Flow**
```
[Web User] → [Cloud Proxy] → [WebSocket] → [Desktop Client] → [Local Ollama]
```

For complete technical details, see .

---

## 🔒 3. Security Architecture

### **Authentication & Authorization**
- **JWT Tokens**: Secure token-based authentication.
- **Auth0 Integration**: Enterprise-grade authentication provider.
- **Token Management**: Automatic refresh and secure storage.

### **Network Security**
- **TLS Encryption**: End-to-end encryption for all connections.
- **Network Isolation**: Per-user Docker networks for premium tiers.
- **Firewall Rules**: Restrictive ingress/egress policies.
- **Rate Limiting**: Protection against abuse.

### **Data Protection**
- **Zero Persistence**: No user data is stored in the cloud.
- **Local Encryption**: Sensitive data is encrypted at rest on the user's machine.
- **Audit Logging**: Comprehensive security event logging.

---

This consolidated architecture document provides the complete technical foundation for understanding CloudToLocalLLM's unified Flutter-native system design, accurately reflecting the current implementation that eliminates Python dependencies and multi-process complexity.