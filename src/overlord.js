const express = require("express");
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const app = express();
const port = 8080;
const STATE_DIR = "/state";
const AUDIT_LOG = path.join(STATE_DIR, "audit.jsonl");
const GHOST_MANIFEST = path.join(STATE_DIR, "ghost-manifest.yaml");

app.use(express.json());

if (!fs.existsSync(STATE_DIR)) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
}

function auditLog(event, data) {
  const entry =
    JSON.stringify({ timestamp: new Date().toISOString(), event, ...data }) +
    "\n";
  fs.appendFileSync(AUDIT_LOG, entry);
}

/**
 * Detect changes logic.
 */
function detectChanges() {
  try {
    return execSync("git diff HEAD^ HEAD", { cwd: "/workspace" }).toString();
  } catch (e) {
    return "forced-sync";
  }
}

/**
 * Cloudflare Tunnel Remediation Logic.
 * Ensures tunnel instances are reconciled and recovered.
 */
function remediateTunnels() {
  console.log("[Overlord] Auditing Cloudflare Tunnel status...");
  try {
    // Forensic audit of running tunnel pods
    const pods = execSync("kubectl get pods -l app=cloudflared -o json", {
      encoding: "utf8",
    });
    const podData = JSON.parse(pods);

    const unhealthy = podData.items.filter(
      (pod) =>
        pod.status.phase !== "Running" ||
        pod.status.containerStatuses.some((cs) => !cs.ready),
    );

    if (unhealthy.length > 0) {
      console.log(
        `[Overlord] Unhealthy tunnels detected: ${unhealthy.length}. Triggering remediation...`,
      );
      unhealthy.forEach((pod) => {
        execSync(`kubectl delete pod ${pod.metadata.name}`, {
          stdio: "ignore",
        });
      });
      auditLog("tunnel-remediation", { count: unhealthy.length });
    }
  } catch (e) {
    console.error(`[Overlord] Tunnel remediation failed: ${e.message}`);
  }
}

/**
 * Mirroring the sacred main-orchestrator workflow logic.
 */
async function synchronize(source = "periodic-polling") {
  const MAX_RETRIES = 3;
  let retryCount = 0;
  let success = false;

  const changes = detectChanges();
  const prompt = `Analyze these changes and identify components for deployment: ${changes.substring(0, 2000)}. IMPORTANT: Perform STATIC ANALYSIS ONLY. Respond ONLY with JSON.`;

  while (retryCount < MAX_RETRIES) {
    try {
      // API Health check
      execSync('gemini-cli --auto "Respond with OK"', {
        cwd: "/workspace",
        env: {
          ...process.env,
          CI: "true",
          TERM: "dumb",
          GEMINI_PROVIDER_TYPE: "gemini-cli",
          GEMINI_CLI_MODEL:
            process.env.GEMINI_CLI_MODEL || "google/gemini-2.5-flash",
        },
        stdio: "ignore",
      });

      // Actual execution
      const output = execSync(`gemini-cli --auto --json "${prompt}"`, {
        cwd: "/workspace",
        encoding: "utf8",
        env: {
          ...process.env,
          CI: "true",
          TERM: "dumb",
          GEMINI_PROVIDER_TYPE: "gemini-cli",
          GEMINI_CLI_MODEL:
            process.env.GEMINI_CLI_MODEL || "google/gemini-2.5-flash",
        },
      });

      fs.writeFileSync(GHOST_MANIFEST, output);
      auditLog("sync-success", { source });

      // Reconcile Cloudflare Tunnels post-sync
      remediateTunnels();

      success = true;
      break;
    } catch (error) {
      retryCount++;
      if (retryCount < MAX_RETRIES)
        await new Promise((r) => setTimeout(r, 15000));
    }
  }

  if (!success && fs.existsSync(GHOST_MANIFEST)) {
    auditLog("resurrection-triggered", { source });
  }
}

app.post("/webhook", (req, res) => {
  synchronize("webhook-summons");
  res.status(202).send({ status: "summoned" });
});

// Production-grade monitoring endpoint for telemetry
app.get("/metrics", (req, res) => {
  try {
    const auditData = fs
      .readFileSync(AUDIT_LOG, "utf8")
      .split("\n")
      .filter(Boolean)
      .map(JSON.parse);
    const tunnelPods = execSync("kubectl get pods -l app=cloudflared -o json", {
      encoding: "utf8",
    });

    res.json({
      status: "online",
      last_sync: auditData
        .reverse()
        .find((entry) => entry.event === "sync-success")?.timestamp,
      tunnel_health: JSON.parse(tunnelPods).items.map((pod) => ({
        name: pod.metadata.name,
        status: pod.status.phase,
        ready: pod.status.containerStatuses.every((cs) => cs.ready),
      })),
      drift_detected: auditData.some((entry) => entry.event === "sync-failure"),
    });
  } catch (e) {
    res.status(500).json({ status: "error", message: e.message });
  }
});

setInterval(
  () => synchronize("polling-purgatory"),
  process.env.POLL_INTERVAL_MS || 180000,
);

app.listen(port, () => {
  synchronize("boot-sequence");
});
