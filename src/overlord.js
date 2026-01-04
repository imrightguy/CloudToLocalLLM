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

// Log deployment to audit trail
function auditLog(event, data) {
    const entry = JSON.stringify({ timestamp: new Date().toISOString(), event, ...data }) + '\n';
    fs.appendFileSync(AUDIT_LOG, entry);
}

// The core synchronization rite
function synchronize(source = 'periodic-polling') {
    console.log(`[Overlord] Commencing synchronization triggered by ${source}...`);
    try {
        // Capture current state pre-deployment
        const currentSha = execSync('git rev-parse HEAD', { cwd: '/workspace' }).toString().trim();
        
        // Execute native Kilocode CLI synchronization
        console.log('[Overlord] Executing Kilocode CLI dominion...');
        const output = execSync('kilocode --auto --sync', { cwd: '/workspace', encoding: 'utf8' });
        
        // Store success as Ghost Manifest for future resurrection
        fs.writeFileSync(GHOST_MANIFEST, output);
        
        auditLog('sync-success', { source, sha: currentSha });
        console.log('[Overlord] Synchronization complete. Chaos averted.');
    } catch (error) {
        console.error(`[Overlord] Synchronization failed: ${error.message}`);
        auditLog('sync-failure', { source, error: error.message });
        
        // Resurrection ritual: Revert to Ghost Manifest if it exists
        if (fs.existsSync(GHOST_MANIFEST)) {
            console.log('[Overlord] Deployment failed. Resurrecting from Ghost Manifest...');
            execSync('kubectl apply -f ' + GHOST_MANIFEST);
            auditLog('resurrection-triggered', { source });
        }
    }
}

// Webhook Hellmouth: Instant execution summons
app.post('/webhook', (req, res) => {
    const payload = req.body;
    console.log('[Overlord] Webhook summons received from GitHub Actions.');
    synchronize('webhook-summons');
    res.status(202).send({ status: 'summoned' });
});

// Polling Purgatory: Periodic drift detection
const POLL_INTERVAL = process.env.POLL_INTERVAL_MS || 180000;
setInterval(() => {
    synchronize('polling-purgatory');
}, POLL_INTERVAL);

app.listen(port, () => {
    console.log(`[Overlord] GitOps Overlord listening on port ${port}. Dominion established.`);
    // Initial boot sync
    synchronize('boot-sequence');
});
