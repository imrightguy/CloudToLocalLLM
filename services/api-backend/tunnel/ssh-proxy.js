/**
 * @fileoverview SSHProxy manages tunnel connections through SSH over WebSocket
 * Handles user connections, request forwarding, and connection lifecycle
 */

import { WebSocketServer, createWebSocketStream } from 'ws';

// import ssh2 from 'ssh2'; // Lazy loaded
// const { Server: SSHServer } = ssh2;

/**
 * Manages SSH tunnel connections for tunneling HTTP requests
 */
export class SSHProxy {
  /**
   * @param {Object} config - Configuration object
   * @param {winston.Logger} logger - Logger instance
   * @param {AuthService} authService - AuthService for JWT validation
   */
  constructor(logger, config, authService) {
    this.logger = logger;
    this.config = config;
    this.authService = authService;

    // WebSocket server for handling upgrades
    this.wss = new WebSocketServer({ noServer: true });
    this._setupWebSocketServer();

    // SSH server instance
    this.sshServer = null;

    // User connections: userId -> { port, localPort, timestamp, sshStream }
    // When an SSH client connects, it registers a reverse tunnel
    // The server assigns a port that forwards to the client's local port
    this.userConnections = new Map();

    // Track registered tunnels: tunnelId -> userId
    this.tunnelRegistry = new Map();

    // Pending responses: requestId -> { resolve, reject, timeout }
    this.pendingResponses = new Map();

    // Metrics
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      timeoutRequests: 0,
      connectionCount: 0,
      reconnectionCount: 0,
    };

    // Connection timeout cleanup
    this.connectionTimeouts = new Map();
  }

  /**
   * Setup WebSocket server handlers
   */
  _setupWebSocketServer() {
    this.wss.on('connection', (ws, _request) => {
      this.logger.info('WebSocket connection established for SSH tunnel');

      // Handle WebSocket as SSH connection directly
      // Create a stream from the WebSocket that can be used by SSH server
      const wsStream = createWebSocketStream(ws);

      // Emit the connection to the SSH server if it exists
      if (this.sshServer) {
        this.sshServer.emit('connection', wsStream);
      } else {
        this.logger.warn('SSH server not available, closing WebSocket');
        ws.close();
      }

      ws.on('error', (err) => {
        this.logger.error('WebSocket error', { error: err.message });
      });

      ws.on('close', () => {
        this.logger.info('WebSocket connection closed');
      });
    });
  }

  /**
   * Handle WebSocket upgrade request
   * @param {http.IncomingMessage} request
   * @param {net.Socket} socket
   * @param {Buffer} head
   */
  handleUpgrade(request, socket, head) {
    this.wss.handleUpgrade(request, socket, head, (ws) => {
      this.wss.emit('connection', ws, request);
    });
  }

  /**
   * Check if SSH server is running
   * @returns {boolean} True if running
   */
  get isRunning() {
    return !!this.sshServer;
  }

  /**
   * Start SSH server
   * @returns {Promise<void>}
   */
  async start() {
    try {
      // Lazy load ssh2
      let ssh2;
      try {
        ssh2 = await import('ssh2');
      } catch (err) {
        this.logger.error('Failed to load ssh2 module', { error: err.message });
        throw err;
      }
      const { Server: SSHServer } = ssh2.default || ssh2;

      // Create SSH server (no listening port - WebSocket connections will be handled directly)
      this.sshServer = new SSHServer(
        {
          hostKeys: [], // We'll handle auth via JWT, not host keys
        },
        (client) => {
          this._handleSSHClient(client);
        },
      );

      this.logger.info('SSHProxy started successfully', {
        type: 'SSH server (WebSocket mode)',
      });
    } catch (error) {
      this.logger.error('Failed to start SSHProxy', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Stop SSH server and cleanup
   * @returns {Promise<void>}
   */
  async stop() {
    // Close SSH server
    if (this.sshServer) {
      this.sshServer.close();
    }

    // Clear all connections and timeouts
    this.userConnections.clear();
    this.tunnelRegistry.clear();
    this.pendingResponses.clear();

    // Clear all timeouts
    for (const timeout of this.connectionTimeouts.values()) {
      clearTimeout(timeout);
    }
    this.connectionTimeouts.clear();

    this.logger.info('SSHProxy stopped');
  }

  /**
   * Handle SSH client connection
   * @param {SSH2Client} client - SSH client
   */
  _handleSSHClient(client) {
    let userId = null;
    let authenticated = false;

    client.on('authentication', async (ctx) => {
      try {
        // Only accept password authentication (JWT as password)
        if (ctx.method !== 'password') {
          this.logger.debug('SSH auth method not supported', {
            method: ctx.method,
            username: ctx.username,
          });
          return ctx.reject(['password']);
        }

        const token = ctx.password;

        if (!token) {
          this.logger.warn('SSH auth missing password (JWT token)');
          return ctx.reject(['password']);
        }

        // Verify token with AuthService
        const result = await this.authService.validateToken(token);

        if (!result.valid) {
          this.logger.warn('SSH auth invalid JWT token', {
            username: ctx.username,
            error: result.error,
          });
          return ctx.reject(['password']);
        }

        const decoded = result.payload;

        // Store user info
        userId = decoded.sub;
        authenticated = true;

        this.logger.info('SSH authentication successful', {
          userId,
          username: ctx.username,
        });

        ctx.accept();
      } catch (error) {
        this.logger.error('SSH authentication error', {
          error: error.message,
          username: ctx.username,
        });
        ctx.reject(['password']);
      }
    });

    client.on('ready', () => {
      if (!authenticated || !userId) {
        return;
      }

      this.logger.info('SSH client ready', { userId });

      // Handle SSH channels (for port forwarding and data transfer)
      client.on('session', (accept) => {
        const session = accept();

        // Handle shell requests (not needed for tunneling)
        session.on('shell', (_accept, reject) => {
          reject();
        });

        // Handle exec requests (not needed for tunneling)
        session.on('exec', (_accept, reject, _info) => {
          reject();
        });
      });

      // Handle TCP/IP forwarding requests
      client.on('tcpip-forward', (accept, reject, info) => {
        this._handleTCPForward(accept, reject, info, userId);
      });

      // Handle direct TCP connections (for forwarded traffic)
      client.on('tcpip', (accept, reject, info) => {
        this._handleTCPConnection(accept, reject, info, userId);
      });
    });

    client.on('end', () => {
      if (userId) {
        this.logger.info('SSH client disconnected', { userId });
        this._cleanupConnection(userId);
      }
    });

    client.on('error', (error) => {
      this.logger.error('SSH client error', {
        error: error.message,
        userId,
      });
      if (userId) {
        this._cleanupConnection(userId);
      }
    });
  }

  /**
   * Handle TCP/IP forwarding requests (reverse tunnels)
   * @param {Function} accept - Accept function
   * @param {Function} reject - Reject function
   * @param {Object} info - Forward info
   * @param {string} userId - User ID
   */
  _handleTCPForward(accept, reject, info, userId) {
    try {
      // Accept the forward request
      const stream = accept();

      // Assign a server port for this tunnel
      const serverPort = this._assignServerPort();

      // Register the tunnel
      const tunnelId = `ssh_tunnel_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      this.userConnections.set(userId, {
        userId,
        tunnelId,
        localPort: info.bindPort, // Client's local port
        port: serverPort, // Server's assigned port
        timestamp: new Date(),
        sshStream: stream,
      });

      this.tunnelRegistry.set(tunnelId, userId);
      this.metrics.connectionCount++;

      // Set connection timeout
      this._setConnectionTimeout(userId);

      this.logger.info('SSH reverse tunnel established', {
        userId,
        tunnelId,
        localPort: info.bindPort,
        serverPort,
      });

      // Handle data forwarding through SSH
      stream.on('data', (data) => {
        this._handleSSHData(userId, data);
      });
    } catch (error) {
      this.logger.error('TCP forward error', {
        error: error.message,
        userId,
      });
      reject();
    }
  }

  /**
   * Handle direct TCP connections (forwarded traffic)
   * @param {Function} accept - Accept function
   * @param {Function} reject - Reject function
   * @param {Object} info - Connection info
   * @param {string} userId - User ID
   */
  _handleTCPConnection(accept, reject, info, userId) {
    try {
      const connection = this.userConnections.get(userId);
      if (!connection) {
        this.logger.warn('TCP connection for unknown user', { userId });
        return reject();
      }

      const stream = accept();

      // Forward data between SSH stream and TCP connection
      stream.on('data', (data) => {
        if (connection.sshStream) {
          connection.sshStream.write(data);
        }
      });

      // Handle connection close
      stream.on('close', () => {
        this.logger.debug('TCP connection closed', { userId });
      });

      this.logger.debug('TCP connection established', {
        userId,
        destPort: info.destPort,
      });
    } catch (error) {
      this.logger.error('TCP connection error', {
        error: error.message,
        userId,
      });
      reject();
    }
  }

  /**
   * Handle SSH data for tunneling
   * @param {string} userId - User ID
   * @param {Buffer} data - SSH data
   */
  _handleSSHData(userId, data) {
    try {
      const connection = this.userConnections.get(userId);
      if (!connection) {
        return;
      }

      // For HTTP tunneling, we expect JSON-encoded HTTP requests
      const dataStr = data.toString();

      try {
        const httpRequest = JSON.parse(dataStr);

        // Process the HTTP request
        this._processHTTPTunnelRequest(userId, httpRequest)
          .then((response) => {
            // Send response back through SSH
            if (connection.sshStream) {
              const responseData = JSON.stringify(response);
              connection.sshStream.write(Buffer.from(responseData));
            }
          })
          .catch((error) => {
            this.logger.error('HTTP tunnel request error', {
              userId,
              error: error.message,
            });
          });
      } catch {
        // Not JSON, might be raw data - log for debugging
        this.logger.debug('Received non-JSON data through SSH tunnel', {
          userId,
          length: data.length,
        });
      }
    } catch (error) {
      this.logger.error('Error handling SSH data', {
        userId,
        error: error.message,
      });
    }
  }

  /**
   * Process HTTP tunnel request
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @returns {Promise<Object>} HTTP response
   */
  async _processHTTPTunnelRequest(userId, httpRequest) {
    try {
      // For now, simulate Ollama API response
      // In production, this would forward to actual Ollama instance

      this.metrics.totalRequests++;

      // Simulate processing time
      await new Promise((resolve) => setTimeout(resolve, 100));

      this.metrics.successfulRequests++;

      return {
        id: httpRequest.id,
        status: 200,
        headers: {
          'content-type': 'application/json',
          'access-control-allow-origin': '*',
        },
        body: JSON.stringify({
          message: {
            role: 'assistant',
            content:
              'Hello! This response is coming through the SSH tunnel. The tunneling system is working correctly!',
          },
          done: true,
        }),
      };
    } catch (error) {
      this.metrics.failedRequests++;
      this.logger.error('HTTP tunnel request processing error', {
        userId,
        error: error.message,
      });

      return {
        id: httpRequest.id,
        status: 500,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          error: 'Internal server error',
          message: error.message,
        }),
      };
    }
  }

  /**
   * Assign a server port for tunnel
   * @returns {number} Assigned port
   */
  _assignServerPort() {
    // Simple port assignment - find next available port
    const basePort = 9000; // Start from 9000
    let port = basePort;

    while (
      Array.from(this.userConnections.values()).some(
        (conn) => conn.port === port,
      )
    ) {
      port++;
    }

    return port;
  }

  /**
   * Set connection timeout for cleanup
   * @param {string} userId - User ID
   */
  _setConnectionTimeout(userId) {
    // Clear existing timeout
    if (this.connectionTimeouts.has(userId)) {
      clearTimeout(this.connectionTimeouts.get(userId));
    }

    // Set new timeout (5 minutes)
    const timeout = setTimeout(
      () => {
        this.logger.info('Connection timeout, cleaning up', { userId });
        this._cleanupConnection(userId);
      },
      5 * 60 * 1000,
    );

    this.connectionTimeouts.set(userId, timeout);
  }

  /**
   * Clean up connection
   * @param {string} userId - User ID
   */
  _cleanupConnection(userId) {
    const connection = this.userConnections.get(userId);
    if (connection) {
      try {
        if (connection.sshStream) {
          connection.sshStream.end();
        }
      } catch {
        // Ignore cleanup errors
      }

      this.userConnections.delete(userId);
      this.metrics.connectionCount--;

      // Clean up tunnel registry
      for (const [tunnelId, connUserId] of this.tunnelRegistry.entries()) {
        if (connUserId === userId) {
          this.tunnelRegistry.delete(tunnelId);
          break;
        }
      }
    }

    // Clear timeout
    if (this.connectionTimeouts.has(userId)) {
      clearTimeout(this.connectionTimeouts.get(userId));
      this.connectionTimeouts.delete(userId);
    }
  }

  /**
   * Register a client connection
   * Called when a client registers via the API
   *
   * @param {string} userId - User ID from JWT
   * @param {string} tunnelId - SSH tunnel identifier
   * @param {number} localPort - Local port on client (typically 11434 for Ollama)
   * @param {number} [serverPort] - Server-assigned port (if provided)
   * @returns {number} Server port assigned to this tunnel
   */
  registerClient(userId, tunnelId, localPort = 11434, serverPort = null) {
    // Clean up old connection if exists
    if (this.userConnections.has(userId)) {
      const oldConnection = this.userConnections.get(userId);
      this.logger.info('User reconnected, cleaning up old connection', {
        userId,
        oldPort: oldConnection.port,
      });
      this.metrics.reconnectionCount++;
    }

    // Assign port if not provided
    const assignedPort = serverPort || this._assignServerPort();

    const connection = {
      userId,
      tunnelId,
      localPort,
      port: assignedPort,
      timestamp: new Date(),
    };

    this.userConnections.set(userId, connection);
    this.tunnelRegistry.set(tunnelId, userId);
    this.metrics.connectionCount++;

    // Set connection timeout (cleanup after 5 minutes of inactivity)
    this._setConnectionTimeout(userId);

    this.logger.info('SSH client registered', {
      userId,
      tunnelId,
      localPort,
      serverPort: assignedPort,
      totalConnections: this.userConnections.size,
    });

    return assignedPort;
  }

  /**
   * Unregister a client connection
   * @param {string} userId - User ID
   */
  unregisterClient(userId) {
    this._cleanupConnection(userId);
    this.logger.info('SSH client unregistered', { userId });
  }

  /**
   * Check if user is connected
   * @param {string} userId - User ID
   * @returns {boolean} True if connected
   */
  isUserConnected(userId) {
    return this.userConnections.has(userId);
  }

  /**
   * Get user connection info
   * @param {string} userId - User ID
   * @returns {Object|null} Connection info or null
   */
  getUserConnection(userId) {
    return this.userConnections.get(userId) || null;
  }

  /**
   * Forward HTTP request through tunnel
   * @param {string} userId - User ID
   * @param {Object} httpRequest - HTTP request object
   * @returns {Promise<Object>} HTTP response
   */
  async forwardRequest(userId, httpRequest) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      throw new Error(`No tunnel connection found for user ${userId}`);
    }

    // Process the HTTP request through the tunnel
    return this._processHTTPTunnelRequest(userId, httpRequest);
  }

  /**
   * Get metrics
   * @returns {Object} Metrics object
   */
  getMetrics() {
    return { ...this.metrics };
  }
}
