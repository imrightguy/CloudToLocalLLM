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

if (!fs.existsSync(STATE_DIR)) {
    fs.mkdirSync(STATE_DIR, { recursive: true });
}

function auditLog(event, data) {
    const entry = JSON.stringify({ timestamp: new Date().toISOString(), event, ...data }) + '\n';
    fs.appendFileSync(AUDIT_LOG, entry);
}

/**
 * Detects changes by mirroring the sacred static analysis logic.
 * Ensures the Overlord knows exactly what rot requires purging.
 */
function detectChanges() {
    console.log('[Overlord] Detecting changes in the upstream void...');
    try {
        const diff = execSync('git diff HEAD^ HEAD', { cwd: '/workspace' }).toString();
        return diff;
    } catch (e) {
        console.warn('[Overlord] Warning: Could not detect changes. Forcing full sync.');
        return 'forced-sync';
    }
}

async function synchronize(source = 'periodic-polling') {
    console.log(`[Overlord] Commencing synchronization triggered by ${source}...`);
    
    const MAX_RETRIES = 3;
    let retryCount = 0;
    let success = false;
    let currentSha = 'unknown';

    try {
        currentSha = execSync('git rev-parse HEAD', { cwd: '/workspace' }).toString().trim();
    } catch (e) {}

    // Manifest detection logic: The Overlord must know its targets.
    const changes = detectChanges();
    // Using the official CLI with explicit environment variable propagation
    const prompt = `Analyze these changes and identify components for deployment: ${changes.substring(0, 2000)}. IMPORTANT: Perform STATIC ANALYSIS ONLY. Respond ONLY with JSON.`;

    while (retryCount < MAX_RETRIES) {
        console.log(`[Overlord] Sync Attempt ${retryCount + 1} of ${MAX_RETRIES}...`);
        
        try {
            // API Health check (Mandatory rite)
            execSync('kilocode --auto "Respond with OK"', {
                cwd: '/workspace',
                env: { 
                    ...process.env, 
                    CI: 'true', 
                    TERM: 'dumb', 
                    KILO_PROVIDER_TYPE: 'kilocode',
                    KILOCODE_MODEL: process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1'
                },
                stdio: 'ignore'
            });

            // Actual execution - Native CLI call with full environment propagation
            const output = execSync(`kilocode --auto --json "${prompt}"`, {
                cwd: '/workspace',
                encoding: 'utf8',
                env: { 
                    ...process.env, 
                    CI: 'true', 
                    TERM: 'dumb', 
                    KILO_PROVIDER_TYPE: 'kilocode',
                    KILOCODE_MODEL: process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1'
                }
            });

            fs.writeFileSync(GHOST_MANIFEST, output);
            auditLog('sync-success', { source, sha: currentSha });
            console.log('[Overlord] Synchronization complete.');
            success = true;
            break;

        } catch (error) {
            console.error(`[Overlord] Attempt ${retryCount + 1} failed: ${error.message}`);
            retryCount++;
            if (retryCount < MAX_RETRIES) await new Promise(r => setTimeout(r, 15000));
        }
    }

    if (!success && fs.existsSync(GHOST_MANIFEST)) {
        console.log('[Overlord] Resurrecting from Ghost Manifest...');
        auditLog('resurrection-triggered', { source });
    }
}

app.post('/webhook', (req, res) => {
    synchronize('webhook-summons');
    res.status(202).send({ status: 'summoned' });
});

setInterval(() => synchronize('polling-purgatory'), process.env.POLL_INTERVAL_MS || 180000);

app.listen(port, () => {
    console.log(`[Overlord] GitOps Overlord listening on port ${port}. Dominion established.`);
    synchronize('boot-sequence');
});
