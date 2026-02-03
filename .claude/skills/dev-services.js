/**
 * Dev Services Skill
 * Starts backend development services
 */

module.exports = {
  id: "dev-services",
  title: "Start Dev Services",
  description: "Start backend development servers (API, SDK, Streaming Proxy)",
  icon: "🔌",

  *run(context) {
    const { ask, prompt } = context;

    const service = yield ask.select("Which service to start?", [
      { value: "api-backend", label: "API Backend (with nodemon)" },
      { value: "sdk", label: "SDK (watch mode)" },
      { value: "streaming-proxy", label: "Streaming Proxy (dev mode)" },
      { value: "all", label: "Start all services" },
    ]);

    const commands = {
      "api-backend": "cd services/api-backend && npm run dev",
      sdk: "cd services/sdk && npm run dev",
      "streaming-proxy": "cd services/streaming-proxy && npm run dev",
      all: "concurrently \"cd services/api-backend && npm run dev\" \"cd services/sdk && npm run dev\" \"cd services/streaming-proxy && npm run dev\" -n api,sdk,proxy",
    };

    const command = commands[service];

    if (service === "all") {
      yield prompt.note({
        message: "Note: 'all' option requires concurrently to be installed globally (npm install -g concurrently)",
      });
    }

    yield prompt.terminal({ command });
  },
};
