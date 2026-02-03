/**
 * Database Skill
 * Runs PostgreSQL database migrations and validation
 */

module.exports = {
  id: "database",
  title: "Database Operations",
  description: "Run PostgreSQL migrations, validation, or check stats",
  icon: "🗄️",

  *run(context) {
    const { ask, prompt } = context;

    const operation = yield ask.select("Which operation?", [
      { value: "migrate", label: "Run migrations" },
      { value: "validate", label: "Validate schema" },
      { value: "stats", label: "Database statistics" },
    ]);

    const commands = {
      migrate: "cd services/api-backend && npm run db:migrate",
      validate: "cd services/api-backend && npm run db:validate",
      stats: "cd services/api-backend && npm run db:stats",
    };

    yield prompt.terminal({ command: commands[operation] });
  },
};
