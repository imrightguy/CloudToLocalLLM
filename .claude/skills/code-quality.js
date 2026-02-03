/**
 * Code Quality Skill
 * Runs linting and formatting checks for Flutter and backend code
 */

module.exports = {
  id: "code-quality",
  title: "Code Quality Check",
  description: "Run linting and formatting for Flutter or backend code",
  icon: "✨",

  *run(context) {
    const { ask, prompt } = context;

    const scope = yield ask.select("What would you like to check?", [
      { value: "flutter-lint", label: "Flutter: Run analyze" },
      { value: "flutter-format", label: "Flutter: Format code" },
      { value: "backend-lint", label: "Backend: Run ESLint" },
      { value: "backend-format", label: "Backend: Format with Prettier" },
      { value: "all-lint", label: "All: Run all linters" },
      { value: "all-format", label: "All: Format all code" },
    ]);

    const commands = {
      "flutter-lint": "flutter analyze",
      "flutter-format": "flutter format .",
      "backend-lint": "cd services/api-backend && npm run lint && cd ../sdk && npm run lint && cd ../streaming-proxy && npm run lint",
      "backend-format": "cd services/api-backend && npm run format && cd ../sdk && npm run format && cd ../streaming-proxy && npm run format",
      "all-lint": "flutter analyze && cd services/api-backend && npm run lint && cd ../sdk && npm run lint && cd ../streaming-proxy && npm run lint",
      "all-format": "flutter format . && cd services/api-backend && npm run format && cd ../sdk && npm run format && cd ../streaming-proxy && npm run format",
    };

    yield prompt.terminal({ command: commands[scope] });
  },
};
