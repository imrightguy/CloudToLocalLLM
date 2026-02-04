# Secure Tunnel and Web Interface Design Specification

## 📋 Overview

This document provides comprehensive design specifications for implementing the "Secure Tunnel" and "Web Interface" components mentioned in the Zoidbot README.md, integrating with the existing autonomous VPS deployment system and cross-platform CI/CD pipeline.

**Document Version**: 1.0.0  
**Last Updated**: 2025-01-29  
**Status**: Design Phase  

---

## 🎯 **Design Objectives**

### **Primary Goals**

- **Secure Remote Access**: Enable users to access local AI models from anywhere through encrypted tunnels
- **Seamless Web Interface**: Provide intuitive browser-based access to local LLM capabilities
- **Cross-Platform Compatibility**: Support Windows, Linux, and macOS desktop clients
- **Enterprise Security**: Implement zero-trust security with comprehensive authentication
- **CI/CD Integration**: Align with existing autonomous deployment and quality gates

### **Key Requirements**

- **Zero-Configuration Setup**: Automatic tunnel establishment and management
- **High Availability**: 99.9% uptime with automatic failover mechanisms
- **Scalable Architecture**: Support for thousands of concurrent users
- **Real-Time Communication**: WebSocket-based streaming for responsive interactions
- **Audit Trail**: Comprehensive logging and monitoring for security compliance

---

## 🏗️ **Architecture Overview**

### **System Components**

```mermaid
graph TB
    subgraph "User Environment"
        A[Web Browser] --> B[Web Interface]
        C[Desktop Client] --> D[Local Ollama]
    end
    
    subgraph "Cloud Infrastructure"
        B --> E[API Gateway]
        E --> F[Tunnel Manager]
        F --> G[WebSocket Server]
        G --> H[Authentication Service]
    end
    
    subgraph "VPS Deployment"
        I[Autonomous Git Monitor] --> J[Deployment Scripts]
        J --> K[Docker Containers]
        K --> L[SSL/TLS Termination]
    end
    
    G -.->|Secure Tunnel| C
    H --> M[Auth0 JWT Validation]
    F --> N[Connection Pool Manager]
```

### **Core Components**

#### **1. Secure Tunnel System**

- **WebSocket-based Communication**: Persistent, bidirectional connections
- **JWT Authentication**: Auth0 integration with role-based access control
- **Connection Multiplexing**: Multiple requests over single tunnel connection
- **Automatic Reconnection**: Resilient connection management with exponential backoff

#### **2. Web Interface**

- **Flutter Web Application**: Unified codebase with desktop clients
- **Responsive Design**: Optimized for desktop and mobile browsers
- **Real-Time Streaming**: Live response streaming from local models
- **Session Management**: Persistent user sessions with secure token handling

#### **3. API Backend**

- **Express.js Server**: High-performance Node.js backend
- **Rate Limiting**: Per-user and global rate limiting with Redis
- **Request Correlation**: Unique IDs for request/response matching
- **Health Monitoring**: Comprehensive health checks and metrics

---

## 🔒 **Security Architecture**

### **Authentication Flow**

```mermaid
sequenceDiagram
    participant U as User
    participant W as Web Interface
    participant A as Auth0
    participant T as Tunnel Manager
    participant D as Desktop Client
    
    U->>W: Access Application
    W->>A: Redirect to Auth0
    A->>U: Authentication Challenge
    U->>A: Provide Credentials
    A->>W: JWT Token
    W->>T: Establish Tunnel (JWT)
    T->>T: Validate JWT
    T->>D: Secure WebSocket Connection
    D->>T: Connection Acknowledged
    T->>W: Tunnel Ready
```

### **Security Protocols**

#### **Transport Security**

- **TLS 1.3**: All communications encrypted with latest TLS standards
- **Certificate Pinning**: Prevent man-in-the-middle attacks
- **HSTS Headers**: Force HTTPS connections
- **WebSocket Secure (WSS)**: Encrypted WebSocket connections

#### **Authentication & Authorization**

- **Auth0 Integration**: Enterprise-grade identity management
- **JWT Tokens**: Stateless authentication with configurable expiration
- **Role-Based Access Control (RBAC)**: Fine-grained permission system
- **Multi-Factor Authentication (MFA)**: Optional 2FA for enhanced security

#### **Data Protection**

- **End-to-End Encryption**: Data encrypted from browser to local client
- **Zero-Knowledge Architecture**: Cloud infrastructure cannot access user data
- **Secure Key Exchange**: Ephemeral keys for session encryption
- **Data Isolation**: Complete separation between user sessions

---

## 🔧 **Technical Specifications**

### **Secure Tunnel Implementation**

#### **WebSocket Protocol**

```javascript
// Message Protocol Definition
const MESSAGE_TYPES = {
  HTTP_REQUEST: 'http_request',
  HTTP_RESPONSE: 'http_response',
  STREAM_START: 'stream_start',
  STREAM_DATA: 'stream_data',
  STREAM_END: 'stream_end',
  PING: 'ping',
  PONG: 'pong',
  ERROR: 'error',
  AUTH_CHALLENGE: 'auth_challenge',
  AUTH_RESPONSE: 'auth_response'
};

// Connection Configuration
const TUNNEL_CONFIG = {
  maxConnections: 1000,
  heartbeatInterval: 30000,
  reconnectDelay: 5000,
  maxReconnectAttempts: 10,
  requestTimeout: 30000,
  compressionEnabled: true
};
```

#### **Connection Management**

- **Connection Pooling**: Efficient resource utilization
- **Load Balancing**: Distribute connections across multiple servers
- **Circuit Breaker**: Automatic failure detection and recovery
- **Graceful Degradation**: Fallback mechanisms for service disruptions

### **Web Interface Specifications**

#### **Flutter Web Architecture**

```dart
// Core Web Interface Components
class SecureTunnelWebApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zoidbot',
      routerConfig: AppRouter.createWebRouter(),
      theme: AppTheme.webTheme,
      builder: (context, child) => WebSecurityWrapper(
        child: TunnelConnectionProvider(
          child: child!,
        ),
      ),
    );
  }
}

// Tunnel Connection Provider
class TunnelConnectionProvider extends StatefulWidget {
  // Manages WebSocket connections and state
}
```

#### **User Interface Components**

- **Chat Interface**: Real-time conversation with local models
- **Model Selection**: Dynamic model discovery and selection
- **Settings Panel**: Connection and preference management
- **Status Dashboard**: Connection health and performance metrics
- **File Upload**: Secure document processing capabilities

### **API Backend Architecture**

#### **Express.js Server Structure**

```javascript
// Main Server Configuration
const app = express();

// Security Middleware
app.use(helmet());
app.use(cors(corsOptions));
app.use(rateLimit(rateLimitConfig));

// Authentication Middleware
app.use('/api', authenticateJWT);

// Tunnel Routes
app.use('/api/tunnel', tunnelRoutes);
app.use('/ws/tunnel', tunnelWebSocketHandler);

// Health Check Endpoints
app.use('/health', healthCheckRoutes);
```

#### **Database Schema**

```sql
-- User Sessions
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  jwt_token_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tunnel Connections
CREATE TABLE tunnel_connections (
  id UUID PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  connection_id VARCHAR(255) UNIQUE NOT NULL,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_ping TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  user_id VARCHAR(255),
  action VARCHAR(100) NOT NULL,
  resource VARCHAR(255),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address INET,
  user_agent TEXT
);
```

---

## 🚀 **Implementation Tasks**

### **Phase 1: Core Infrastructure (Weeks 1-4)**

#### **Task 1.1: Secure Tunnel Backend**

- **Description**: Implement WebSocket-based tunnel server with JWT authentication
- **Acceptance Criteria**:
  - WebSocket server handles 1000+ concurrent connections
  - JWT validation with Auth0 integration
  - Message protocol implementation with correlation IDs
  - Connection health monitoring and automatic reconnection
- **Dependencies**: None
- **Effort**: High (3-4 weeks)
- **Files**: `services/api-backend/tunnel/`

#### **Task 1.2: Database Schema Setup**

- **Description**: Create database tables for user sessions, connections, and audit logs
- **Acceptance Criteria**:
  - PostgreSQL schema with proper indexing
  - Migration scripts for schema updates
  - Connection pooling configuration
  - Backup and recovery procedures
- **Dependencies**: Task 1.1
- **Effort**: Medium (1-2 weeks)
- **Files**: `config/database/`

#### **Task 1.3: Authentication Service**

- **Description**: Integrate Auth0 JWT validation with role-based access control
- **Acceptance Criteria**:
  - Auth0 configuration and integration
  - JWT token validation middleware
  - Role-based permission system
  - Session management with secure cookies
- **Dependencies**: Task 1.1
- **Effort**: Medium (2-3 weeks)
- **Files**: `services/api-backend/auth/`

### **Phase 2: Web Interface Development (Weeks 5-8)**

#### **Task 2.1: Flutter Web Application**

- **Description**: Develop responsive web interface using Flutter
- **Acceptance Criteria**:
  - Responsive design for desktop and mobile
  - Real-time chat interface with streaming
  - Model selection and configuration
  - Settings and preferences management
- **Dependencies**: Task 1.1, Task 1.3
- **Effort**: High (4-5 weeks)
- **Files**: `lib/web/`, `web/`

#### **Task 2.2: WebSocket Client Integration**

- **Description**: Implement client-side WebSocket handling for tunnel communication
- **Acceptance Criteria**:
  - Automatic connection establishment
  - Message correlation and response handling
  - Reconnection logic with exponential backoff
  - Error handling and user feedback
- **Dependencies**: Task 2.1
- **Effort**: Medium (2-3 weeks)
- **Files**: `lib/services/tunnel/`

#### **Task 2.3: Security Implementation**

- **Description**: Implement client-side security measures and data protection
- **Acceptance Criteria**:
  - Secure token storage and management
  - Input validation and sanitization
  - XSS and CSRF protection
  - Content Security Policy implementation
- **Dependencies**: Task 2.1, Task 2.2
- **Effort**: Medium (2-3 weeks)
- **Files**: `lib/security/`

### **Phase 3: Desktop Client Integration (Weeks 9-12)**

#### **Task 3.1: Desktop Tunnel Client**

- **Description**: Implement desktop client for tunnel connections to local Ollama
- **Acceptance Criteria**:
  - Cross-platform compatibility (Windows, Linux, macOS)
  - Automatic Ollama discovery and connection
  - System tray integration with status indicators
  - Configuration management and persistence
- **Dependencies**: Task 1.1
- **Effort**: High (4-5 weeks)
- **Files**: `lib/desktop/tunnel/`

#### **Task 3.2: Local Model Management**

- **Description**: Implement model discovery, selection, and management
- **Acceptance Criteria**:
  - Automatic model detection from Ollama
  - Model metadata and capability reporting
  - Performance monitoring and optimization
  - Error handling for model unavailability
- **Dependencies**: Task 3.1
- **Effort**: Medium (2-3 weeks)
- **Files**: `lib/services/models/`

#### **Task 3.3: Cross-Platform Packaging**

- **Description**: Create installation packages for all supported platforms
- **Acceptance Criteria**:
  - Windows MSI installer with auto-update
  - Linux AppImage and Debian packages
  - macOS DMG with notarization
  - Automated build pipeline integration
- **Dependencies**: Task 3.1, Task 3.2
- **Effort**: Medium (2-3 weeks)
- **Files**: `build-tools/`, `scripts/packaging/`

---

## 🔄 **CI/CD Integration**

### **Autonomous Deployment Integration**

#### **VPS Deployment Scripts**

```bash
# Enhanced deployment script for tunnel components
#!/bin/bash
# scripts/deploy/deploy_tunnel_system.sh

deploy_tunnel_backend() {
    log_info "Deploying tunnel backend services..."
    
    # Build and deploy API backend
    docker-compose build api-backend
    docker-compose up -d api-backend
    
    # Verify tunnel endpoints
    verify_tunnel_endpoints
    
    # Run tunnel-specific health checks
    run_tunnel_health_checks
}

verify_tunnel_endpoints() {
    local endpoints=(
        "/api/tunnel/health"
        "/ws/tunnel"
        "/api/auth/validate"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if ! curl -f "https://app.zoidbot.online$endpoint"; then
            log_error "Tunnel endpoint verification failed: $endpoint"
            return 1
        fi
    done
}
```

#### **PowerShell Integration**

```powershell
# Enhanced PowerShell deployment for tunnel components
# scripts/powershell/Deploy-TunnelSystem.ps1

function Deploy-TunnelSystem {
    param(
        [switch]$SkipTests,
        [switch]$Force
    )
    
    # Build Flutter web with tunnel features
    Build-FlutterWebWithTunnel
    
    # Run tunnel-specific tests
    if (-not $SkipTests) {
        Test-TunnelSecurity
        Test-WebSocketConnections
        Test-AuthenticationFlow
    }
    
    # Deploy to VPS with tunnel verification
    Deploy-ToVPSWithTunnelVerification
}
```

### **GitHub Actions Workflow**

```yaml
# .github/workflows/tunnel-deployment.yml
name: Tunnel System Deployment

on:
  push:
    paths:
      - 'services/api-backend/tunnel/**'
      - 'lib/services/tunnel/**'
      - 'web/**'

jobs:
  tunnel-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Run Tunnel Security Tests
        run: npm run test:tunnel:security
      
      - name: Run WebSocket Integration Tests
        run: npm run test:tunnel:websocket
      
      - name: Run Authentication Tests
        run: npm run test:tunnel:auth

  deploy-tunnel:
    needs: tunnel-tests
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/master'
    steps:
      - name: Deploy Tunnel Backend
        env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
          VPS_HOST: ${{ secrets.VPS_HOST }}
        run: |
          ssh $VPS_HOST "./scripts/deploy/deploy_tunnel_system.sh --force"
```

---

## 📊 **Testing and Validation**

### **Security Testing Requirements**

#### **Penetration Testing**

- **Authentication Bypass**: Attempt to bypass Auth0 JWT validation
- **Session Hijacking**: Test for session token vulnerabilities
- **WebSocket Security**: Validate WSS connection security
- **Input Validation**: Test for injection attacks and XSS

#### **Performance Testing**

- **Load Testing**: 1000+ concurrent WebSocket connections
- **Stress Testing**: Peak load scenarios with graceful degradation
- **Latency Testing**: Sub-100ms response times for tunnel communication
- **Scalability Testing**: Horizontal scaling validation

#### **Integration Testing**

- **Cross-Platform**: Test on Windows, Linux, and macOS
- **Browser Compatibility**: Chrome, Firefox, Safari, Edge
- **Network Conditions**: Various network speeds and reliability
- **Failover Testing**: Automatic reconnection and error recovery

### **Quality Gates Integration**

#### **Zero-Tolerance Security Gates**

```bash
# Security validation script
#!/bin/bash
# scripts/deploy/validate_tunnel_security.sh

validate_tunnel_security() {
    # SSL/TLS validation
    check_ssl_configuration
    
    # Authentication validation
    validate_jwt_implementation
    
    # WebSocket security validation
    check_websocket_security
    
    # Rate limiting validation
    test_rate_limiting
    
    # Input validation testing
    test_input_sanitization
}
```

#### **Performance Quality Gates**

```javascript
// Performance validation
const PERFORMANCE_THRESHOLDS = {
  maxResponseTime: 100, // milliseconds
  maxConnectionTime: 5000, // milliseconds
  minThroughput: 1000, // requests per second
  maxMemoryUsage: 512, // MB
  maxCpuUsage: 80 // percentage
};
```

---

## 📚 **Documentation Integration**

### **Cross-References**

- **** - Current tunnel implementation
- **[System Architecture](SYSTEM_ARCHITECTURE.md)** - Overall system design
- **** - Deployment procedures
- **** - Security guidelines

### **API Documentation**

- **** - WebSocket API specification
- **** - Auth0 integration details
- **** - Frontend API documentation

---

## 🎯 **Success Criteria**

### **Functional Requirements**

- ✅ Users can access local models through web browser
- ✅ Secure tunnel establishment within 5 seconds
- ✅ Real-time streaming with <100ms latency
- ✅ Cross-platform desktop client compatibility
- ✅ 99.9% uptime with automatic failover

### **Security Requirements**

- ✅ Zero-trust security architecture
- ✅ End-to-end encryption for all communications
- ✅ Comprehensive audit logging
- ✅ Penetration testing validation
- ✅ Compliance with security best practices

### **Performance Requirements**

- ✅ Support 1000+ concurrent users
- ✅ Sub-100ms response times
- ✅ Automatic scaling based on demand
- ✅ Graceful degradation under load
- ✅ 99.9% availability SLA

---

## 🔧 **Detailed Implementation Specifications**

### **File Structure and Organization**

```
Zoidbot/
├── services/
│   └── api-backend/
│       ├── tunnel/
│       │   ├── tunnel-server.js          # Main WebSocket server
│       │   ├── tunnel-routes.js          # HTTP API routes
│       │   ├── message-protocol.js       # Protocol definitions
│       │   ├── connection-manager.js     # Connection pooling
│       │   └── security-middleware.js    # Security validation
│       ├── auth/
│       │   ├── auth0-integration.js      # Auth0 JWT validation
│       │   ├── session-manager.js        # Session handling
│       │   └── rbac-middleware.js        # Role-based access
│       └── database/
│           ├── models/                   # Database models
│           ├── migrations/               # Schema migrations
│           └── seeds/                    # Test data
├── lib/
│   ├── services/
│   │   ├── tunnel/
│   │   │   ├── tunnel_client.dart        # Desktop tunnel client
│   │   │   ├── web_tunnel_client.dart    # Web tunnel client
│   │   │   ├── message_handler.dart      # Message processing
│   │   │   └── connection_manager.dart   # Connection management
│   │   └── auth/
│   │       ├── auth_service.dart         # Authentication service
│   │       ├── token_manager.dart        # JWT token handling
│   │       └── session_provider.dart     # Session state management
│   └── web/
│       ├── pages/
│       │   ├── chat_page.dart           # Main chat interface
│       │   ├── settings_page.dart       # Configuration page
│       │   └── dashboard_page.dart      # Status dashboard
│       └── widgets/
│           ├── tunnel_status_widget.dart # Connection status
│           ├── model_selector.dart      # Model selection
│           └── security_indicator.dart  # Security status
├── scripts/
│   ├── deploy/
│   │   ├── deploy_tunnel_system.sh      # Tunnel deployment
│   │   ├── validate_tunnel_security.sh  # Security validation
│   │   └── tunnel_health_checks.sh      # Health monitoring
│   └── powershell/
│       ├── Deploy-TunnelSystem.ps1      # PowerShell deployment
│       ├── Test-TunnelSecurity.ps1      # Security testing
│       └── Build-TunnelComponents.ps1   # Build automation
└── test/
    ├── tunnel/
    │   ├── security_tests.js            # Security test suite
    │   ├── performance_tests.js         # Performance testing
    │   └── integration_tests.js         # Integration testing
    └── e2e/
        ├── tunnel_e2e_tests.dart       # End-to-end tests
        └── security_e2e_tests.dart     # Security E2E tests
```

### **Configuration Management**

#### **Environment Configuration**

```yaml
# config/tunnel/production.yml
tunnel:
  websocket:
    port: 8080
    path: "/ws/tunnel"
    maxConnections: 1000
    heartbeatInterval: 30000
    compressionEnabled: true

  security:
    jwtSecret: "${JWT_SECRET}"
    auth0Domain: "${JWT_ISSUER_DOMAIN}"
    auth0Audience: "${JWT_AUDIENCE}"
    corsOrigins:
      - "https://app.zoidbot.online"
      - "https://zoidbot.online"

  database:
    host: "${DB_HOST}"
    port: 5432
    database: "zoidbot"
    ssl: true
    poolSize: 20

  monitoring:
    metricsEnabled: true
    healthCheckInterval: 30000
    alertThresholds:
      responseTime: 100
      errorRate: 0.01
      connectionCount: 900
```

#### **Docker Configuration**

```dockerfile
# config/docker/Dockerfile.tunnel-backend
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY services/api-backend/package*.json ./
RUN npm ci --only=production

# Copy application code
COPY services/api-backend/ ./

# Security hardening
RUN addgroup -g 1001 -S nodejs && \
    adduser -S tunnel -u 1001 -G nodejs && \
    chown -R tunnel:nodejs /app

USER tunnel

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["node", "tunnel/tunnel-server.js"]
```

### **Monitoring and Observability**

#### **Metrics Collection**

```javascript
// services/api-backend/monitoring/metrics.js
const prometheus = require('prom-client');

// Custom metrics for tunnel system
const tunnelMetrics = {
  activeConnections: new prometheus.Gauge({
    name: 'tunnel_active_connections',
    help: 'Number of active tunnel connections'
  }),

  messageLatency: new prometheus.Histogram({
    name: 'tunnel_message_latency_seconds',
    help: 'Latency of tunnel messages',
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1]
  }),

  authenticationAttempts: new prometheus.Counter({
    name: 'tunnel_auth_attempts_total',
    help: 'Total authentication attempts',
    labelNames: ['status', 'method']
  }),

  securityEvents: new prometheus.Counter({
    name: 'tunnel_security_events_total',
    help: 'Security events detected',
    labelNames: ['type', 'severity']
  })
};
```

#### **Health Check Implementation**

```javascript
// services/api-backend/health/tunnel-health.js
class TunnelHealthChecker {
  async checkHealth() {
    const checks = {
      websocket: await this.checkWebSocketServer(),
      database: await this.checkDatabaseConnection(),
      auth: await this.checkAuth0Connection(),
      memory: await this.checkMemoryUsage(),
      connections: await this.checkConnectionLimits()
    };

    const isHealthy = Object.values(checks).every(check => check.status === 'healthy');

    return {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      checks
    };
  }
}
```

### **Security Implementation Details**

#### **JWT Validation Middleware**

```javascript
// services/api-backend/auth/jwt-middleware.js
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

class JWTValidator {
  constructor(auth0Domain, audience) {
    this.client = jwksClient({
      jwksUri: `https://${auth0Domain}/.well-known/jwks.json`,
      cache: true,
      cacheMaxEntries: 5,
      cacheMaxAge: 600000 // 10 minutes
    });
    this.audience = audience;
    this.issuer = `https://${auth0Domain}/`;
  }

  async validateToken(token) {
    try {
      const decoded = jwt.decode(token, { complete: true });
      const key = await this.getSigningKey(decoded.header.kid);

      const verified = jwt.verify(token, key, {
        audience: this.audience,
        issuer: this.issuer,
        algorithms: ['RS256']
      });

      return { valid: true, payload: verified };
    } catch (error) {
      return { valid: false, error: error.message };
    }
  }
}
```

#### **Rate Limiting Implementation**

```javascript
// services/api-backend/security/rate-limiter.js
const Redis = require('redis');

class TunnelRateLimiter {
  constructor(redisClient) {
    this.redis = redisClient;
    this.limits = {
      perUser: { requests: 1000, window: 900 }, // 1000 requests per 15 minutes
      perIP: { requests: 100, window: 60 },     // 100 requests per minute
      global: { requests: 10000, window: 60 }   // 10k requests per minute globally
    };
  }

  async checkLimit(identifier, limitType) {
    const limit = this.limits[limitType];
    const key = `rate_limit:${limitType}:${identifier}`;

    const current = await this.redis.incr(key);
    if (current === 1) {
      await this.redis.expire(key, limit.window);
    }

    return {
      allowed: current <= limit.requests,
      remaining: Math.max(0, limit.requests - current),
      resetTime: Date.now() + (limit.window * 1000)
    };
  }
}
```

---

## 📋 **Detailed Task Breakdown**

### **Phase 1: Core Infrastructure (Weeks 1-4)**

#### **Task 1.1: Secure Tunnel Backend**

**Subtasks:**

1. **WebSocket Server Setup** (3 days)
   - Configure Express.js with WebSocket support
   - Implement connection handling and lifecycle management
   - Add compression and heartbeat mechanisms

2. **Message Protocol Implementation** (2 days)
   - Define message types and validation schemas
   - Implement correlation ID system
   - Add message serialization/deserialization

3. **Authentication Integration** (4 days)
   - Auth0 JWT validation setup
   - Session management implementation
   - Role-based access control middleware

4. **Connection Management** (3 days)
   - Connection pooling and load balancing
   - Automatic reconnection handling
   - Circuit breaker implementation

5. **Security Hardening** (3 days)
   - Rate limiting implementation
   - Input validation and sanitization
   - Security headers and CORS configuration

**Acceptance Criteria:**

- [ ] WebSocket server handles 1000+ concurrent connections
- [ ] JWT validation with Auth0 integration working
- [ ] Message protocol with correlation IDs implemented
- [ ] Connection health monitoring active
- [ ] Security middleware protecting all endpoints
- [ ] Comprehensive logging and metrics collection

#### **Task 1.2: Database Schema Setup**

**Subtasks:**

1. **Schema Design** (2 days)
   - Design tables for sessions, connections, audit logs
   - Create indexes for performance optimization
   - Define foreign key relationships

2. **Migration Scripts** (1 day)
   - Create database migration files
   - Implement rollback procedures
   - Add data validation constraints

3. **Connection Pooling** (1 day)
   - Configure PostgreSQL connection pool
   - Implement connection health checks
   - Add monitoring for connection usage

4. **Backup Strategy** (1 day)
   - Automated backup procedures
   - Point-in-time recovery setup
   - Disaster recovery documentation

**Acceptance Criteria:**

- [ ] PostgreSQL schema with proper indexing
- [ ] Migration scripts with rollback capability
- [ ] Connection pooling with health monitoring
- [ ] Automated backup and recovery procedures
- [ ] Performance benchmarks meeting requirements

#### **Task 1.3: Authentication Service**

**Subtasks:**

1. **Auth0 Configuration** (2 days)
   - Set up Auth0 application and APIs
   - Configure JWT token settings
   - Implement custom claims and scopes

2. **JWT Middleware** (2 days)
   - Token validation and verification
   - Key rotation handling
   - Error handling and logging

3. **Session Management** (2 days)
   - Secure session storage
   - Session timeout and renewal
   - Multi-device session handling

4. **RBAC Implementation** (2 days)
   - Role and permission definitions
   - Authorization middleware
   - Admin interface for role management

**Acceptance Criteria:**

- [ ] Auth0 integration with custom configuration
- [ ] JWT validation with proper error handling
- [ ] Secure session management with timeout
- [ ] Role-based access control working
- [ ] Admin interface for user management

### **Phase 2: Web Interface Development (Weeks 5-8)**

#### **Task 2.1: Flutter Web Application**

**Subtasks:**

1. **Project Structure Setup** (2 days)
   - Configure Flutter web project
   - Set up routing and navigation
   - Implement responsive layout system

2. **Chat Interface** (5 days)
   - Real-time chat UI with message bubbles
   - Streaming response display
   - Message history and persistence
   - File upload and attachment support

3. **Model Selection Interface** (3 days)
   - Dynamic model discovery from tunnel
   - Model capability display
   - Performance metrics and status

4. **Settings and Configuration** (3 days)
   - User preferences management
   - Connection settings interface
   - Theme and accessibility options

5. **Dashboard and Monitoring** (3 days)
   - Connection status display
   - Performance metrics visualization
   - Security status indicators

**Acceptance Criteria:**

- [ ] Responsive design working on all screen sizes
- [ ] Real-time chat with streaming responses
- [ ] Model selection with capability display
- [ ] Settings persistence and synchronization
- [ ] Dashboard with real-time status updates

#### **Task 2.2: WebSocket Client Integration**

**Subtasks:**

1. **Connection Management** (3 days)
   - WebSocket connection establishment
   - Automatic reconnection with exponential backoff
   - Connection state management

2. **Message Handling** (3 days)
   - Message correlation and routing
   - Response streaming implementation
   - Error handling and recovery

3. **Authentication Flow** (2 days)
   - Token-based authentication
   - Session renewal handling
   - Logout and cleanup procedures

4. **Performance Optimization** (2 days)
   - Message compression
   - Connection pooling
   - Latency optimization

**Acceptance Criteria:**

- [ ] Automatic connection with retry logic
- [ ] Message correlation working correctly
- [ ] Authentication flow integrated
- [ ] Performance meeting latency requirements
- [ ] Error handling with user feedback

#### **Task 2.3: Security Implementation**

**Subtasks:**

1. **Token Management** (2 days)
   - Secure token storage
   - Token refresh handling
   - Logout and token cleanup

2. **Input Validation** (2 days)
   - Client-side validation
   - XSS prevention measures
   - CSRF protection implementation

3. **Content Security Policy** (1 day)
   - CSP header configuration
   - Nonce-based script loading
   - Resource integrity validation

4. **Security Monitoring** (2 days)
   - Security event logging
   - Anomaly detection
   - User behavior monitoring

**Acceptance Criteria:**

- [ ] Secure token storage and management
- [ ] Input validation preventing attacks
- [ ] CSP implementation blocking malicious content
- [ ] Security monitoring with alerting
- [ ] Penetration testing validation

---

### **Phase 3: Desktop Client Integration (Weeks 9-12)**

#### **Task 3.1: Desktop Tunnel Client**

**Subtasks:**

1. **Cross-Platform Client** (4 days)
   - Flutter desktop implementation
   - Platform-specific optimizations
   - System tray integration

2. **Ollama Integration** (3 days)
   - Automatic Ollama discovery
   - Model enumeration and status
   - Health monitoring and reconnection

3. **Configuration Management** (2 days)
   - Settings persistence
   - Auto-configuration features
   - Manual configuration interface

4. **System Integration** (3 days)
   - Auto-start functionality
   - System notifications
   - Background operation mode

**Acceptance Criteria:**

- [ ] Cross-platform compatibility (Windows, Linux, macOS)
- [ ] Automatic Ollama discovery and connection
- [ ] System tray with status indicators
- [ ] Configuration persistence and management
- [ ] Background operation with minimal resource usage

#### **Task 3.2: Local Model Management**

**Subtasks:**

1. **Model Discovery** (2 days)
   - Automatic model detection
   - Model metadata extraction
   - Capability assessment

2. **Performance Monitoring** (2 days)
   - Resource usage tracking
   - Response time monitoring
   - Error rate tracking

3. **Model Optimization** (2 days)
   - Load balancing between models
   - Caching strategies
   - Memory management

4. **Error Handling** (2 days)
   - Model unavailability handling
   - Graceful degradation
   - User notification system

**Acceptance Criteria:**

- [ ] Automatic model detection and metadata
- [ ] Performance monitoring with metrics
- [ ] Optimization for resource efficiency
- [ ] Robust error handling and recovery
- [ ] User-friendly status reporting

#### **Task 3.3: Cross-Platform Packaging**

**Subtasks:**

1. **Windows Packaging** (3 days)
   - MSI installer creation
   - Auto-update mechanism
   - Windows Store preparation

2. **Linux Packaging** (3 days)
   - AppImage creation
   - Debian/Ubuntu packages
   - Flatpak preparation

3. **macOS Packaging** (3 days)
   - DMG creation and notarization
   - App Store preparation
   - Auto-update implementation

4. **CI/CD Integration** (2 days)
   - Automated build pipeline
   - Release automation
   - Quality gate integration

**Acceptance Criteria:**

- [ ] Windows MSI with auto-update
- [ ] Linux packages (AppImage, DEB)
- [ ] macOS DMG with notarization
- [ ] Automated build and release pipeline
- [ ] Integration with existing CI/CD system

---

## 🔄 **Advanced CI/CD Integration**

### **Enhanced Deployment Pipeline**

#### **Tunnel-Specific Quality Gates**

```bash
#!/bin/bash
# scripts/deploy/tunnel_quality_gates.sh

run_tunnel_quality_gates() {
    log_info "🔒 Running tunnel-specific quality gates..."

    # Security validation
    validate_tunnel_security || return 1

    # Performance benchmarks
    run_tunnel_performance_tests || return 1

    # Integration testing
    run_tunnel_integration_tests || return 1

    # Load testing
    run_tunnel_load_tests || return 1

    log_success "✅ All tunnel quality gates passed"
}

validate_tunnel_security() {
    log_step "Validating tunnel security..."

    # JWT validation testing
    test_jwt_validation || return 1

    # WebSocket security testing
    test_websocket_security || return 1

    # Rate limiting validation
    test_rate_limiting || return 1

    # Input sanitization testing
    test_input_sanitization || return 1

    return 0
}
```

#### **PowerShell Deployment Enhancement**

```powershell
# scripts/powershell/Deploy-TunnelSystem.ps1

function Deploy-TunnelSystem {
    [CmdletBinding()]
    param(
        [switch]$SkipTests,
        [switch]$Force,
        [switch]$SecurityValidation,
        [string]$Environment = "production"
    )

    Write-Host "🚀 Starting Tunnel System Deployment" -ForegroundColor Green

    try {
        # Pre-deployment validation
        if (-not $SkipTests) {
            Test-TunnelPrerequisites
            Test-SecurityConfiguration
            Test-DatabaseConnectivity
        }

        # Build tunnel components
        Build-TunnelBackend
        Build-TunnelWebInterface
        Build-TunnelDesktopClient

        # Security validation
        if ($SecurityValidation) {
            Invoke-SecurityValidation
        }

        # Deploy to VPS with tunnel verification
        Deploy-ToVPSWithTunnelVerification -Environment $Environment

        # Post-deployment validation
        Test-TunnelEndpoints
        Test-WebSocketConnections
        Test-AuthenticationFlow

        Write-Host "✅ Tunnel system deployment completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Tunnel deployment failed: $($_.Exception.Message)"
        Invoke-TunnelRollback
        throw
    }
}

function Test-TunnelPrerequisites {
    Write-Host "🔍 Validating tunnel prerequisites..." -ForegroundColor Yellow

    # Check Auth0 configuration
    if (-not $env:JWT_ISSUER_DOMAIN -or -not $env:JWT_AUDIENCE) {
        throw "Auth0 configuration missing"
    }

    # Check database connectivity
    Test-DatabaseConnection

    # Check SSL certificates
    Test-SSLCertificates

    Write-Host "✅ Prerequisites validation passed" -ForegroundColor Green
}
```

### **GitHub Actions Workflow Enhancement**

```yaml
# .github/workflows/tunnel-system-ci-cd.yml
name: Tunnel System CI/CD

on:
  push:
    branches: [ master, main ]
    paths:
      - 'services/api-backend/tunnel/**'
      - 'lib/services/tunnel/**'
      - 'lib/web/**'
      - 'scripts/deploy/tunnel_*'
  pull_request:
    branches: [ master, main ]
    paths:
      - 'services/api-backend/tunnel/**'
      - 'lib/services/tunnel/**'
      - 'lib/web/**'

env:
  TUNNEL_VERSION: '1.0.0'
  SECURITY_SCAN_ENABLED: true

jobs:
  tunnel-security-scan:
    name: Security Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Security Scan
        uses: securecodewarrior/github-action-add-sarif@v1
        with:
          sarif-file: 'security-scan-results.sarif'

      - name: Validate Dependencies
        run: |
          npm audit --audit-level high
          npm run security:check

  tunnel-backend-tests:
    name: Tunnel Backend Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:6
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: 'npm'
          cache-dependency-path: services/api-backend/package-lock.json

      - name: Install dependencies
        run: |
          cd services/api-backend
          npm ci

      - name: Run unit tests
        run: |
          cd services/api-backend
          npm run test:tunnel:unit

      - name: Run integration tests
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379
        run: |
          cd services/api-backend
          npm run test:tunnel:integration

      - name: Run security tests
        run: |
          cd services/api-backend
          npm run test:tunnel:security

  tunnel-web-tests:
    name: Tunnel Web Interface Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true

      - name: Get dependencies
        run: flutter pub get

      - name: Run Flutter tests
        run: flutter test test/tunnel/

      - name: Build web interface
        run: flutter build web --release

      - name: Upload web build
        uses: actions/upload-artifact@v4
        with:
          name: tunnel-web-build
          path: build/web/

  tunnel-desktop-tests:
    name: Tunnel Desktop Client Tests
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true

      - name: Get dependencies
        run: flutter pub get

      - name: Run desktop tests
        run: flutter test test/desktop/tunnel/

      - name: Build desktop application
        run: |
          flutter config --enable-linux-desktop
          flutter config --enable-windows-desktop
          flutter config --enable-macos-desktop
          flutter build ${{ matrix.os == 'ubuntu-latest' && 'linux' || matrix.os == 'windows-latest' && 'windows' || 'macos' }}

  tunnel-e2e-tests:
    name: End-to-End Tunnel Tests
    runs-on: ubuntu-latest
    needs: [tunnel-backend-tests, tunnel-web-tests]

    steps:
      - uses: actions/checkout@v4

      - name: Setup test environment
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30  # Wait for services to start

      - name: Run E2E tests
        run: |
          npm run test:e2e:tunnel

      - name: Cleanup test environment
        if: always()
        run: docker-compose -f docker-compose.test.yml down

  deploy-tunnel-system:
    name: Deploy Tunnel System
    runs-on: ubuntu-latest
    needs: [tunnel-security-scan, tunnel-backend-tests, tunnel-web-tests, tunnel-desktop-tests, tunnel-e2e-tests]
    if: github.ref == 'refs/heads/master'
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Download web build
        uses: actions/download-artifact@v4
        with:
          name: tunnel-web-build
          path: build/web/

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DEPLOY_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy tunnel backend
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
          VPS_USER: ${{ secrets.VPS_USER }}
        run: |
          ssh $VPS_USER@$VPS_HOST "cd /opt/zoidbot && ./scripts/deploy/deploy_tunnel_system.sh --force"

      - name: Verify deployment
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
          VPS_USER: ${{ secrets.VPS_USER }}
        run: |
          ssh $VPS_USER@$VPS_HOST "cd /opt/zoidbot && ./scripts/deploy/verify_tunnel_deployment.sh"

      - name: Run post-deployment tests
        run: |
          npm run test:tunnel:production
```

---

## 📊 **Monitoring and Alerting**

### **Comprehensive Monitoring Setup**

#### **Prometheus Metrics Configuration**

```yaml
# config/monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "tunnel_alerts.yml"

scrape_configs:
  - job_name: 'tunnel-backend'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'tunnel-websocket'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/ws/metrics'
    scrape_interval: 5s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

#### **Alert Rules**

```yaml
# config/monitoring/tunnel_alerts.yml
groups:
  - name: tunnel_system
    rules:
      - alert: TunnelHighLatency
        expr: tunnel_message_latency_seconds{quantile="0.95"} > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High tunnel message latency detected"
          description: "95th percentile latency is {{ $value }}s"

      - alert: TunnelConnectionLimit
        expr: tunnel_active_connections > 900
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Tunnel connection limit approaching"
          description: "Active connections: {{ $value }}/1000"

      - alert: TunnelAuthFailures
        expr: rate(tunnel_auth_attempts_total{status="failed"}[5m]) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High authentication failure rate"
          description: "{{ $value }} auth failures per second"

      - alert: TunnelSecurityEvent
        expr: rate(tunnel_security_events_total[1m]) > 0
        for: 0s
        labels:
          severity: critical
        annotations:
          summary: "Security event detected in tunnel system"
          description: "Security event: {{ $labels.type }}"
```

### **Logging and Audit Trail**

#### **Structured Logging Configuration**

```javascript
// services/api-backend/logging/tunnel-logger.js
const winston = require('winston');

const tunnelLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'tunnel-system' },
  transports: [
    new winston.transports.File({
      filename: '/var/log/zoidbot/tunnel-error.log',
      level: 'error'
    }),
    new winston.transports.File({
      filename: '/var/log/zoidbot/tunnel-combined.log'
    }),
    new winston.transports.File({
      filename: '/var/log/zoidbot/tunnel-security.log',
      level: 'warn'
    })
  ]
});

// Security event logging
tunnelLogger.logSecurity = (event, userId, metadata) => {
  tunnelLogger.warn('SECURITY_EVENT', {
    event,
    userId,
    timestamp: new Date().toISOString(),
    metadata,
    severity: 'HIGH'
  });
};
```

---

## 🎯 **Final Implementation Checklist**

### **Pre-Implementation Requirements**

- [ ] Auth0 tenant configured with appropriate settings
- [ ] PostgreSQL database provisioned with proper permissions
- [ ] Redis instance configured for rate limiting and caching
- [ ] SSL certificates obtained and configured
- [ ] VPS environment prepared with Docker and monitoring tools
- [ ] GitHub repository secrets configured for CI/CD

### **Phase 1 Completion Criteria**

- [ ] WebSocket server handling 1000+ concurrent connections
- [ ] JWT authentication with Auth0 integration
- [ ] Database schema with proper indexing and constraints
- [ ] Rate limiting and security middleware active
- [ ] Comprehensive monitoring and alerting configured
- [ ] All security tests passing with zero vulnerabilities

### **Phase 2 Completion Criteria**

- [ ] Flutter web interface with responsive design
- [ ] Real-time chat with streaming responses
- [ ] WebSocket client with automatic reconnection
- [ ] Security implementation with CSP and input validation
- [ ] Performance meeting sub-100ms latency requirements
- [ ] Cross-browser compatibility validated

### **Phase 3 Completion Criteria**

- [ ] Cross-platform desktop client (Windows, Linux, macOS)
- [ ] Automatic Ollama integration and model discovery
- [ ] System tray integration with status indicators
- [ ] Installation packages for all platforms
- [ ] Auto-update mechanism working
- [ ] CI/CD pipeline fully integrated

### **Production Readiness Checklist**

- [ ] Load testing with 1000+ concurrent users passed
- [ ] Security penetration testing completed
- [ ] Disaster recovery procedures tested
- [ ] Monitoring and alerting validated
- [ ] Documentation complete and up-to-date
- [ ] Support procedures established

---

**Next Steps**: Begin Phase 1 implementation with Task 1.1 (Secure Tunnel Backend) as the foundation for the entire system. Ensure all security requirements are met before proceeding to subsequent phases. Coordinate with the existing autonomous VPS deployment system to maintain zero-tolerance quality gates throughout the implementation process.
