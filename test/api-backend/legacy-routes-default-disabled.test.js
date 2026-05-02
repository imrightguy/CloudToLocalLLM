import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverSource = fs.readFileSync(
  path.resolve(__dirname, "../../services/api-backend/server.js"),
  "utf8",
);

describe("legacy proxy and tunnel route gates", () => {
  it("keeps legacy tunnel route mounts behind an explicit flag", () => {
    expect(serverSource).toContain("LEGACY_TUNNEL_ROUTES_ENABLED");
    expect(serverSource).toMatch(
      /if \(LEGACY_TUNNEL_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/tunnel'/,
    );
    expect(serverSource).toMatch(
      /if \(LEGACY_TUNNEL_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/tunnels'/,
    );
    expect(serverSource).toMatch(
      /if \(LEGACY_TUNNEL_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/tunnel-health'/,
    );
  });

  it("keeps direct and streaming proxy route mounts behind explicit flags", () => {
    expect(serverSource).toMatch(
      /if \(LEGACY_DIRECT_PROXY_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/direct-proxy'/,
    );
    expect(serverSource).toMatch(
      /if \(LEGACY_STREAMING_PROXY_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/proxy\/status'/,
    );
    expect(serverSource).toMatch(
      /if \(LEGACY_STREAMING_PROXY_ROUTES_ENABLED\) \{[\s\S]*registerRoutes\('\/streaming-proxy\/provision'/,
    );
  });

  it("keeps the Ollama proxy route behind an explicit flag", () => {
    expect(serverSource).toMatch(
      /if \(LEGACY_OLLAMA_PROXY_ENABLED\) \{[\s\S]*app\.all\(/,
    );
  });
});
