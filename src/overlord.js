const express = require('express');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const port = 8080;
const STATE_DIR = '/state';
const AUDIT_LOG = path.join(STATE_DIR, 'audit.jsonl');
const GHOST_MANIFEST = path.join(STATE_DIR, 'ghost-manifest.yaml');

app.use(express.json());

// Ensure state directory exists
if (!fs.existsSync(STATE_DIR)) {
    fs.mkdirSync(STATE_DIR, { recursive: true });
}

// Log deployment to audit trail
function auditLog(event, data) {
    const entry = JSON.stringify({ timestamp: new Date().toISOString(), event, ...data }) + '\n';
    fs.appendFileSync(AUDIT_LOG, entry);
}

/**
 * Mirroring the sacred main-orchestrator workflow logic.
 * Performs robust synchronization with retries, health checks, and static analysis.
 */
async function synchronize(source = 'periodic-polling') {
    console.log(`[Overlord] Commencing synchronization triggered by ${source}...`);
    
    const MAX_RETRIES = 3;
    let retryCount = 0;
    let success = false;
    let currentSha = 'unknown';

    try {
        currentSha = execSync('git rev-parse HEAD', { cwd: '/workspace' }).toString().trim();
    } catch (e) {
        console.warn('[Overlord] Warning: Could not capture current SHA.');
    }

    const prompt = "Analyze the latest changes and decide if a release is needed. IMPORTANT: Perform STATIC ANALYSIS ONLY. Respond ONLY with a JSON object.";

    while (retryCount < MAX_RETRIES) {
        console.log(`[Overlord] Sync Attempt ${retryCount + 1} of ${MAX_RETRIES}...`);
        
        try {
            // 1. Health Check (Mirroring workflow line 182)
            console.log('[Overlord] Performing Kilocode API health check...');
            execSync('kilocode --auto "Health check: Respond with OK"', {
                cwd: '/workspace',
                env: { 
                    ...process.env, 
                    CI: 'true', 
                    TERM: 'dumb',
                    KILO_PROVIDER_TYPE: 'kilocode',
                    KILO_TELEMETRY: 'false',
                    KILO_AUTO_APPROVAL_ENABLED: 'true'
                },
                stdio: 'ignore'
            });
            console.log('[Overlord] API health check passed.');

            // 2. Execution Logic (Mirroring workflow line 202)
            console.log('[Overlord] Attempting Kilocode analysis...');
            const output = execSync(`kilocode --auto --json "${prompt}"`, {
                cwd: '/workspace',
                encoding: 'utf8',
                env: { 
                    ...process.env, 
                    CI: 'true', 
                    TERM: 'dumb',
                    KILO_PROVIDER_TYPE: 'kilocode',
                    KILO_TELEMETRY: 'false',
                    KILO_AUTO_APPROVAL_ENABLED: 'true'
                }
            });

            // Persistence Ritual
            fs.writeFileSync(GHOST_MANIFEST, output);
            auditLog('sync-success', { source, sha: currentSha });
            console.log('[Overlord] Synchronization complete. Dominion secured.');
            success = true;
            break;

        } catch (error) {
            console.error(`[Overlord] Attempt ${retryCount + 1} failed: ${error.message}`);
            retryCount++;
            if (retryCount < MAX_RETRIES) {
                const delay = 15000;
                console.log(`[Overlord] Retrying in ${delay}ms...`);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }

    if (!success) {
        console.error('[Overlord] Total synchronization failure after all attempts.');
        auditLog('sync-failure', { source, sha: currentSha });
        
        // Resurrection Ritual
        if (fs.existsSync(GHOST_MANIFEST)) {
            console.log('[Overlord] Failed to manifest new state. Resurrecting from Ghost Manifest...');
            try {
                // In a production Overlord, this would apply the last known good manifest via kubectl
                // execSync('kubectl apply -f ' + GHOST_MANIFEST);
                auditLog('resurrection-triggered', { source });
            } catch (resError) {
                console.error(`[Overlord] Resurrection failed: ${resError.message}`);
            }
        }
    }
}

// Webhook Hellmouth
app.post('/webhook', (req, res) => {
    console.log('[Overlord] Webhook summons received from GitHub Actions.');
    synchronize('webhook-summons');
    res.status(202).send({ status: 'summoned' });
});

// Polling Purgatory
const POLL_INTERVAL = process.env.POLL_INTERVAL_MS || 180000;
setInterval(() => {
    synchronize('polling-purgatory');
}, POLL_INTERVAL);

app.listen(port, () => {
    console.log(`[Overlord] GitOps Overlord listening on port ${port}. Dominion established.`);
    synchronize('boot-sequence');
});
