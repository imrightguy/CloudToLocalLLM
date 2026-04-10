#!/usr/bin/env node

/**
 * Container Configuration Verification Script
 * Verifies that container configurations are properly updated for simplified tunnel system
 */

const fs = require("fs");
const path = require("path");

console.log(
  "🔍 Verifying Container Configuration for Simplified Tunnel System",
);
console.log("================================================================");

let passed = 0;
let failed = 0;

/**
 * Test helper function
 */
function test(name, testFn) {
  try {
    const result = testFn();
    if (result) {
      console.log(`✅ ${name}`);
      passed++;
    } else {
      console.log(`❌ ${name}`);
      failed++;
    }
  } catch (error) {
    console.log(`❌ ${name}: ${error.message}`);
    failed++;
  }
}

/**
 * Verify Dockerfile.streaming-proxy has been updated
 */
test("Dockerfile.streaming-proxy updated for simplified tunnel", () => {
  const dockerfilePath = path.join(
    __dirname,
    "../config/docker/Dockerfile.streaming-proxy",
  );
  const content = fs.readFileSync(dockerfilePath, "utf8");

  // Should contain simplified container setup
  const hasSimplifiedSetup = content.includes(
    "Simplified container for tunnel-aware applications",
  );
  const hasHttpClient = content.includes("Uses standard HTTP libraries");
  const hasTestScript = content.includes("test-tunnel.js");
  const hasHealthCheck = content.includes("health-check.js");

  return hasSimplifiedSetup && hasHttpClient && hasTestScript && hasHealthCheck;
});

/**
 * Verify streaming-proxy/proxy-server.js has been updated
 */
test("proxy-server.js updated to use standard HTTP client", () => {
  const serverPath = path.join(
    __dirname,
    "../services/streaming-proxy/proxy-server.js",
  );
  const content = fs.readFileSync(serverPath, "utf8");

  // Should not contain WebSocket server code
  const noWebSocketServer = !content.includes("WebSocketServer");
  const noWebSocketImport = !content.includes("from 'ws'");

  // Should contain HTTP client code
  const hasHttpClient = content.includes("TunnelHttpClient");
  const hasStandardHttp = content.includes("import http from 'http'");
  const hasOllamaBaseUrl = content.includes("OLLAMA_BASE_URL");

  return (
    noWebSocketServer &&
    noWebSocketImport &&
    hasHttpClient &&
    hasStandardHttp &&
    hasOllamaBaseUrl
  );
});

/**
 * Verify package.json has been updated
 */
test("package.json updated with simplified dependencies", () => {
  const packagePath = path.join(__dirname, "../streaming-proxy/package.json");
  const content = fs.readFileSync(packagePath, "utf8");
  const packageJson = JSON.parse(content);

  // Should not have WebSocket dependencies
  const noWsDependency = !packageJson.dependencies.ws;
  const noJwtDependency = !packageJson.dependencies.jsonwebtoken;

  // Should have updated name and description
  const hasUpdatedName =
    packageJson.name === "CloudToLocalLLM-tunnel-container";
  const hasUpdatedDescription = packageJson.description.includes(
    "standard HTTP libraries",
  );

  return (
    noWsDependency && noJwtDependency && hasUpdatedName && hasUpdatedDescription
  );
});

/**
 * Verify streaming-proxy-manager.js has been updated
 */
test("streaming-proxy-manager.js updated with OLLAMA_BASE_URL", () => {
  const managerPath = path.join(
    __dirname,
    "../services/api-backend/streaming-proxy-manager.js",
  );
  const content = fs.readFileSync(managerPath, "utf8");

  // Should contain OLLAMA_BASE_URL environment variable
  const hasOllamaBaseUrl = content.includes(
    "OLLAMA_BASE_URL=http://api-backend:8080/api/tunnel/",
  );
  const hasTunnelEndpoint = content.includes("/api/tunnel/${userId}");

  return hasOllamaBaseUrl && hasTunnelEndpoint;
});

/**
 * Verify docker-compose.multi.yml has been updated
 */
test("docker-compose.multi.yml updated for tunnel containers", () => {
  const composePath = path.join(__dirname, "../docker-compose.multi.yml");
  const content = fs.readFileSync(composePath, "utf8");

  // Should reference tunnel-aware containers
  const hasTunnelContainer = content.includes("tunnel-container-base");
  const hasUpdatedComment = content.includes(
    "Tunnel-aware Container Base Image",
  );

  return hasTunnelContainer && hasUpdatedComment;
});

/**
 * Verify integration test files exist
 */
test("Integration test files created", () => {
  const dartTestPath = path.join(
    __dirname,
    "../test/integration/tunnel_container_integration_test.dart",
  );
  const jsTestPath = path.join(
    __dirname,
    "../scripts/test-container-tunnel-integration.js",
  );
  const shellTestPath = path.join(
    __dirname,
    "../scripts/run-container-tunnel-tests.sh",
  );
  const psTestPath = path.join(
    __dirname,
    "../scripts/run-tunnel-verification-test.ps1",
  );

  const dartTestExists = fs.existsSync(dartTestPath);
  const jsTestExists = fs.existsSync(jsTestPath);
  const shellTestExists = fs.existsSync(shellTestPath);
  const psTestExists = fs.existsSync(psTestPath);

  return dartTestExists && jsTestExists && shellTestExists && psTestExists;
});

/**
 * Verify integration test content
 */
test("Integration tests contain proper tunnel verification", () => {
  const jsTestPath = path.join(
    __dirname,
    "../scripts/test-container-tunnel-integration.js",
  );
  const content = fs.readFileSync(jsTestPath, "utf8");

  // Should test standard HTTP usage
  const testsStandardHttp = content.includes("testStandardHttpUsage");
  const testsTunnelCommunication = content.includes(
    "testContainerTunnelCommunication",
  );
  const testsConcurrentRequests = content.includes("testConcurrentRequests");
  const testsErrorHandling = content.includes("testErrorHandling");

  return (
    testsStandardHttp &&
    testsTunnelCommunication &&
    testsConcurrentRequests &&
    testsErrorHandling
  );
});

/**
 * Verify tunnel routes are properly configured
 */
test("Tunnel routes configured for container integration", () => {
  const routesPath = path.join(
    __dirname,
    "../api-backend/tunnel/tunnel-routes.js",
  );
  const content = fs.readFileSync(routesPath, "utf8");

  // Should have proper proxy middleware
  const hasProxyMiddleware = content.includes("router.all('/:userId/*'");
  const hasAuthMiddleware = content.includes("authenticateToken");
  const hasConnectionCheck = content.includes("requireTunnelConnection");

  return hasProxyMiddleware && hasAuthMiddleware && hasConnectionCheck;
});

console.log("");
console.log("================================================================");
console.log(
  `📊 Configuration Verification Results: ${passed} passed, ${failed} failed`,
);

if (failed === 0) {
  console.log(
    "🎉 All container configurations are properly updated for simplified tunnel system!",
  );
  console.log("");
  console.log("Summary of changes:");
  console.log("✅ Container Dockerfile updated to use standard HTTP libraries");
  console.log("✅ Streaming proxy server replaced with HTTP client");
  console.log("✅ Package dependencies simplified (removed WebSocket/JWT)");
  console.log("✅ Container environment configured with OLLAMA_BASE_URL");
  console.log("✅ Docker Compose updated for tunnel-aware containers");
  console.log(
    "✅ Integration tests created for container-tunnel communication",
  );
  console.log("✅ Tunnel routes configured for container proxy endpoints");
  console.log("");
  console.log("Next steps:");
  console.log("1. Build updated container images");
  console.log("2. Deploy containers with new tunnel configuration");
  console.log("3. Run integration tests to verify functionality");
  process.exit(0);
} else {
  console.log("💥 Some configuration updates are missing or incorrect.");
  console.log(
    "Please review the failed checks above and ensure all changes are properly applied.",
  );
  process.exit(1);
}
