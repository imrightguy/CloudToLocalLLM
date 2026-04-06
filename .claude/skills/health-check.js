/**
 * Health Check Skill
 * Checks health status of local services
 */

module.exports = {
  id: "health-check",
  title: "Health Check",
  description: "Check health of local backend services",
  icon: "💚",

  *run(context) {
    const { prompt } = context;

    yield prompt.note({
      message: "Checking service health...",
    });

    yield prompt.terminal({
      command: `echo "=== API Backend ===" && curl -s http://localhost:8080/health || echo "Not running" && echo "" && echo "=== Streaming Proxy ===" && curl -s http://localhost:3001/health || echo "Not running" && echo "" && echo "=== Flutter Router ===" && curl -s http://localhost:1337/health || echo "Not running"`,
    });
  },
};
