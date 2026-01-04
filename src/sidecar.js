#!/usr/bin/env node

/**
 * Kilocode GitOps Controller Sidecar
 *
 * This sidecar implements the dual-trigger mechanism for GitOps operations:
 * - REST/Webhook endpoint for immediate sync triggers
 * - Periodic polling for drift detection
 * - JSONL audit logging for all operations
 * - Orchestration of kilocode/cli execution
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

// Environment variables
const KILOCODE_EXEC_PATH = process.env.KILOCODE_EXEC_PATH || '/usr/local/bin/kilocode';
const LOG_PATH = process.env.LOG_PATH || '/logs/audit.jsonl';
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL) || 300000; // 5 minutes default

// Ensure log directory exists
const logDir = path.dirname(LOG_PATH);
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

/**
 * Log audit event to JSONL file
 */
function logAuditEvent(event) {
    const auditEntry = {
        timestamp: new Date().toISOString(),
        ...event
    };

    const logLine = JSON.stringify(auditEntry) + '\n';

    try {
        fs.appendFileSync(LOG_PATH, logLine);
        console.log('Audit logged:', auditEntry);
    } catch (error) {
        console.error('Failed to write audit log:', error);
    }
}

/**
 * Execute kilocode sync operation
 */
function executeKilocodeSync(triggerType, triggerData = {}) {
    const startTime = Date.now();

    logAuditEvent({
        event: 'sync_started',
        trigger: triggerType,
        triggerData
    });

    // Execute kilocode sync in the shared workspace
    const command = `${KILOCODE_EXEC_PATH} --auto --sync`;

    exec(command, { cwd: '/workspace' }, (error, stdout, stderr) => {
        const duration = Date.now() - startTime;

        const result = {
            event: 'sync_completed',
            trigger: triggerType,
            duration,
            success: !error,
            stdout: stdout.trim(),
            stderr: stderr.trim()
        };

        if (error) {
            result.error = error.message;
            console.error('Kilocode sync failed:', error);
        } else {
            console.log('Kilocode sync completed successfully');
        }

        logAuditEvent(result);
    });
}

/**
 * Handle webhook trigger
 */
function handleWebhook(req, res) {
    let body = '';

    req.on('data', chunk => {
        body += chunk.toString();
    });

    req.on('end', () => {
        try {
            const payload = body ? JSON.parse(body) : {};

            logAuditEvent({
                event: 'webhook_received',
                method: req.method,
                url: req.url,
                headers: req.headers,
                payload
            });

            // Trigger kilocode sync
            executeKilocodeSync('webhook', {
                method: req.method,
                url: req.url,
                userAgent: req.headers['user-agent'],
                sourceIp: req.socket.remoteAddress
            });

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'accepted', message: 'Sync triggered' }));

        } catch (error) {
            console.error('Webhook processing error:', error);
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Invalid JSON payload' }));
        }
    });
}

/**
 * Handle health check
 */
function handleHealth(req, res) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'kilocode-gitops-sidecar'
    }));
}

/**
 * HTTP request handler
 */
function requestHandler(req, res) {
    // Enable CORS for webhook endpoints
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    if (req.url === '/health') {
        handleHealth(req, res);
    } else if (req.url === '/webhook' && req.method === 'POST') {
        handleWebhook(req, res);
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
    }
}

// Create HTTP server
const server = http.createServer(requestHandler);

// Start periodic polling
function startPeriodicPolling() {
    console.log(`Starting periodic polling every ${POLL_INTERVAL / 1000} seconds`);

    setInterval(() => {
        logAuditEvent({
            event: 'polling_trigger',
            interval: POLL_INTERVAL
        });

        executeKilocodeSync('polling');
    }, POLL_INTERVAL);
}

// Start the server
const PORT = 8080;
server.listen(PORT, () => {
    console.log(`Kilocode GitOps Sidecar listening on port ${PORT}`);
    console.log(`Audit logs will be written to: ${LOG_PATH}`);

    // Log startup
    logAuditEvent({
        event: 'sidecar_started',
        port: PORT,
        pollInterval: POLL_INTERVAL,
        kilocodePath: KILOCODE_EXEC_PATH
    });

    // Start periodic polling
    startPeriodicPolling();
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully');
    logAuditEvent({
        event: 'sidecar_shutdown',
        reason: 'SIGTERM'
    });
    server.close(() => {
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully');
    logAuditEvent({
        event: 'sidecar_shutdown',
        reason: 'SIGINT'
    });
    server.close(() => {
        process.exit(0);
    });
});