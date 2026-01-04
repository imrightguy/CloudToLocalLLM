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
 * Detect changes logic.
 */
function detectChanges() {
    try {
        return execSync('git diff HEAD^ HEAD', { cwd: '/workspace' }).toString();
    } catch (e) {
        return 'forced-sync';
    }
}

/**
 * Mirroring the sacred main-orchestrator workflow logic.
 */
async function synchronize(source = 'periodic-polling') {
    const MAX_RETRIES = 3;
    let retryCount = 0;
    let success = false;

    const changes = detectChanges();
    const prompt = `Analyze these changes and identify components for deployment: ${changes.substring(0, 2000)}. IMPORTANT: Perform STATIC ANALYSIS ONLY. Respond ONLY with JSON.`;

    while (retryCount < MAX_RETRIES) {
        try {
            // API Health check
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

            // Actual execution
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
            auditLog('sync-success', { source });
            success = true;
            break;

        } catch (error) {
            retryCount++;
            if (retryCount < MAX_RETRIES) await new Promise(r => setTimeout(r, 15000));
        }
    }

    if (!success && fs.existsSync(GHOST_MANIFEST)) {
        auditLog('resurrection-triggered', { source });
    }
}

app.post('/webhook', (req, res) => {
    synchronize('webhook-summons');
    res.status(202).send({ status: 'summoned' });
});

setInterval(() => synchronize('polling-purgatory'), process.env.POLL_INTERVAL_MS || 180000);

app.listen(port, () => {
    synchronize('boot-sequence');
});
