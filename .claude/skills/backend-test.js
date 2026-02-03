/**
 * Backend Test Skill
 * Runs backend tests for API, SDK, or streaming-proxy services
 */

module.exports = {
  id: "backend-test",
  title: "Backend Test",
  description: "Run backend tests for API, SDK, or streaming-proxy",
  icon: "🔧",

  *run(context) {
    const { ask, prompt } = context;

    const service = yield ask.select("Which service would you like to test?", [
      { value: "api-backend", label: "API Backend" },
      { value: "sdk", label: "SDK" },
      { value: "streaming-proxy", label: "Streaming Proxy" },
    ]);

    const testType = yield ask.select("Which test suite?", [
      { value: "all", label: "All tests" },
      { value: "unit", label: "Unit tests" },
      { value: "auth", label: "Auth tests" },
      { value: "security", label: "Security tests" },
    ]);

    const commands = {
      "api-backend": {
        all: `cd services/api-backend && npm test`,
        unit: `cd services/api-backend && npm run test:unit`,
        auth: `cd services/api-backend && npm run test:auth`,
        security: `cd services/api-backend && npm run test:security`,
      },
      sdk: {
        all: `cd services/sdk && npm test`,
        unit: `cd services/sdk && npm test`,
        auth: `cd services/sdk && npm test`,
        security: `cd services/sdk && npm test`,
      },
      "streaming-proxy": {
        all: `cd services/streaming-proxy && npm test`,
        unit: `cd services/streaming-proxy && npm test`,
        auth: `cd services/streaming-proxy && npm test`,
        security: `cd services/streaming-proxy && npm test`,
      },
    };

    const command = commands[service][testType];

    yield prompt.terminal({ command });
  },
};
