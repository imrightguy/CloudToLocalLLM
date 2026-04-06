/**
 * Flutter Test Skill
 * Runs Flutter tests with options for unit, widget, or integration tests
 */

module.exports = {
  id: "flutter-test",
  title: "Flutter Test",
  description: "Run Flutter tests (all, unit, widget, or integration)",
  icon: "🧪",

  *run(context) {
    const { ask, prompt } = context;

    const testType = yield ask.select("Which tests would you like to run?", [
      { value: "all", label: "All tests" },
      { value: "unit", label: "Unit tests (test/unit/ + test/services/)" },
      { value: "widget", label: "Widget tests (test/widgets/)" },
      { value: "integration", label: "Integration tests (test/integration/)" },
    ]);

    const commands = {
      all: "flutter test",
      unit: "flutter test test/unit/ test/services/",
      widget: "flutter test test/widgets/",
      integration: "flutter test test/integration/",
    };

    const command = commands[testType];

    yield prompt.terminal({ command });
  },
};
