# Zoidbot Features Guide

## 📋 Overview

Zoidbot provides a comprehensive suite of features for local and cloud LLM management. This guide covers all features, integrations, and premium capabilities in a single authoritative reference.

---

## 🎯 **Core Features**

### **Local LLM Integration**

- **Ollama Support**: Native integration with Ollama for local model management
- **Model Management**: Download, update, and manage multiple LLM models
- **Hardware Detection**: Automatic GPU detection and optimization
- **Performance Optimization**: Efficient resource utilization and memory management

### **Chat Interface**

- **Modern UI**: Clean, intuitive chat interface with Material Design 3
- **Dark/Light Themes**: Automatic theme switching based on system preferences
- **Conversation Management**: Create, save, and organize multiple conversations
- **Message History**: Persistent conversation history with search capabilities

### **System Integration**

- **System Tray**: Enhanced system tray with independent daemon architecture
- **Desktop Integration**: Native desktop experience with proper window management
- **Startup Options**: Configurable startup behavior and system integration
- **Cross-Platform**: Consistent experience across Linux, Windows, and web platforms

---

## 🌟 **Premium Features**

### **Cloud Connectivity**

- **Secure Tunneling**: Encrypted connection to cloud-hosted LLMs
- **Multi-Tenant Architecture**: Isolated user sessions with zero data persistence
- **Automatic Failover**: Seamless switching between local and cloud connections
- **Load Balancing**: Intelligent routing for optimal performance

### **Advanced Authentication**

- **Auth0 Integration**: Enterprise-grade authentication with SSO support
- **JWT Token Management**: Secure token handling with automatic refresh
- **Multi-Factor Authentication**: Enhanced security with MFA support
- **Session Management**: Persistent authentication across application restarts

### **Enhanced Streaming**

- **Real-Time Streaming**: Low-latency streaming for responsive interactions
- **Connection Pooling**: Efficient connection management and reuse
- **Health Monitoring**: Continuous connection health checks and recovery
- **Bandwidth Optimization**: Adaptive streaming based on connection quality

### **Enterprise Features**

- **User Management**: Multi-user support with role-based access control
- **Audit Logging**: Comprehensive logging for compliance and monitoring
- **API Access**: RESTful API for integration with external systems
- **Custom Branding**: White-label options for enterprise deployments

---

## 🔌 **Integrations**

### **Ollama Integration**

#### **Setup and Configuration**

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
systemctl --user enable --now ollama

# Pull models
ollama pull llama2
ollama pull codellama
ollama pull mistral
```

#### **Model Management**

- **Automatic Discovery**: Zoidbot automatically detects available Ollama models
- **Model Information**: Display model details, size, and capabilities
- **Performance Metrics**: Real-time performance monitoring and optimization
- **Custom Models**: Support for custom and fine-tuned models

#### **Hardware Optimization**

- **GPU Detection**: Automatic NVIDIA GPU detection and utilization
- **Memory Management**: Intelligent memory allocation and cleanup
- **CPU Optimization**: Multi-core processing for improved performance
- **Resource Monitoring**: Real-time resource usage tracking

### **Context7 MCP Integration**

#### **Installation**

```bash
# Install Context7 MCP server
npm install -g @context7/mcp-server

# Configure Zoidbot integration
zoidbot-settings --enable-context7

# Test integration
context7-mcp --test-connection
```

#### **Features**

- **Code Context**: Enhanced code understanding and generation
- **Documentation Access**: Real-time access to library documentation
- **API Integration**: Seamless integration with development workflows
- **Multi-Language Support**: Support for multiple programming languages

#### **Configuration**

```json
{
  "context7": {
    "enabled": true,
    "server_url": "http://localhost:3000",
    "api_key": "your-api-key",
    "features": {
      "code_completion": true,
      "documentation_lookup": true,
      "api_integration": true
    }
  }
}
```

### **Authentication Architecture**

#### **Auth0 Direct Login Implementation**

**Configuration Setup:**

```javascript
// Auth0 Configuration
const authConfig = {
  domain: 'dev-vivn1fcgzi0c2czy.us.auth0.com',
  clientId: 'mm7lIRm33LGyoQ0FKCy04x88fsgnbvr1',
  audience: 'https://api.zoidbot.online',
  redirectUri: {
    web: 'https://app.zoidbot.online/callback',
    desktop: 'zoidbot://callback'
  }
};
```

**PKCE Flow Implementation:**

```dart
// Flutter PKCE implementation
class AuthService {
  static const String domain = 'dev-vivn1fcgzi0c2czy.us.auth0.com';
  static const String clientId = 'mm7lIRm33LGyoQ0FKCy04x88fsgnbvr1';
  
  Future<AuthResult> login() async {
    final auth0 = Auth0(domain, clientId);
    return await auth0.webAuthentication().login(
      audience: 'https://api.zoidbot.online',
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }
}
```

#### **Token Management**

- **Secure Storage**: Encrypted token storage using platform-specific secure storage
- **Automatic Refresh**: Background token refresh with retry logic
- **Cross-Platform Sync**: Token synchronization across multiple devices
- **Revocation Support**: Secure token revocation and cleanup

#### **Security Features**

- **PKCE Support**: Proof Key for Code Exchange for enhanced security
- **State Validation**: CSRF protection with state parameter validation
- **Secure Redirect**: Validated redirect URIs for callback handling
- **Session Security**: Secure session management with proper cleanup

---

## ⚙️ **Configuration**

### **Feature Toggles**

```json
{
  "features": {
    "cloud_connectivity": true,
    "premium_features": true,
    "context7_integration": false,
    "advanced_auth": true,
    "enterprise_features": false
  }
}
```

### **Performance Settings**

```json
{
  "performance": {
    "max_concurrent_connections": 10,
    "connection_timeout": 30000,
    "retry_attempts": 3,
    "cache_size": "1GB",
    "gpu_acceleration": true
  }
}
```

### **UI Customization**

```json
{
  "ui": {
    "theme": "auto",
    "compact_mode": false,
    "show_system_tray": true,
    "startup_minimized": true,
    "custom_branding": {
      "enabled": false,
      "logo_url": "",
      "primary_color": "#1976d2"
    }
  }
}
```

---

## 🔧 **Advanced Usage**

### **API Integration**

```bash
# Get authentication token
curl -X POST https://api.zoidbot.online/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "pass"}'

# Send chat message
curl -X POST https://api.zoidbot.online/api/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, world!", "model": "llama2"}'
```

### **Custom Model Integration**

```python
# Custom model configuration
model_config = {
    "name": "custom-model",
    "type": "ollama",
    "endpoint": "http://localhost:11434",
    "parameters": {
        "temperature": 0.7,
        "max_tokens": 2048,
        "top_p": 0.9
    }
}
```

### **Webhook Integration**

```javascript
// Webhook configuration for external integrations
const webhookConfig = {
  url: 'https://your-webhook-endpoint.com/zoidbot',
  events: ['message_sent', 'model_changed', 'connection_status'],
  authentication: {
    type: 'bearer',
    token: 'your-webhook-token'
  }
};
```

---

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Authentication Problems**

```bash
# Clear authentication cache
rm -rf ~/.zoidbot/auth_cache

# Reset Auth0 configuration
zoidbot-settings --reset-auth

# Test authentication
zoidbot --test-auth
```

#### **Integration Issues**

```bash
# Test Ollama connection
curl http://localhost:11434/api/version

# Test Context7 integration
context7-mcp --health-check

# Verify system tray
zoidbot-tray --debug
```

#### **Performance Issues**

```bash
# Check resource usage
zoidbot --performance-report

# Clear cache
zoidbot --clear-cache

# Reset configuration
zoidbot-settings --reset-performance
```

### **Log Analysis**

- **Application Logs**: `~/.zoidbot/app.log`
- **Authentication Logs**: `~/.zoidbot/auth.log`
- **Integration Logs**: `~/.zoidbot/integrations.log`
- **Performance Logs**: `~/.zoidbot/performance.log`

---

## 📚 **Additional Resources**

### **Documentation Links**

- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md) - Technical architecture details
- [Installation Guide](../INSTALLATION/README.md) - Platform-specific installation
- [Self-Hosting Guide](../OPERATIONS/SELF_HOSTING.md) - VPS deployment instructions

### **Community Resources**

- **GitHub Repository**: [Zoidbot](https://github.com/Zoidbot-online/Zoidbot)
- **Issue Tracker**: Report bugs and request features
- **Discussions**: Community support and tips
- **Wiki**: Additional documentation and tutorials

### **Support Channels**

- **Documentation**: Comprehensive guides and references
- **Community Forum**: Peer support and discussions
- **GitHub Issues**: Bug reports and feature requests
- **Email Support**: Premium support for enterprise users

---

This comprehensive features guide consolidates all Zoidbot capabilities, integrations, and premium features into a single authoritative reference, replacing the scattered feature documentation with clear, organized information.
