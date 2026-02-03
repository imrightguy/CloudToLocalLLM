/**
 * Flutter Test Skill
 * Runs Flutter tests with options for unit, widget, or integration tests
 */

module.exports = {
  id: "flutter-test",
  title: "Flutter Test",
  description: "Run Flutter tests (unit, widget, or integration)",
  icon: "🧪",

  *run(context) {
    const { ask, prompt } = context;

    const testType = yield ask.select("Which tests would you like to run?", [
      { value: "all", label: "All tests" },
      { value: "unit", label: "Unit tests only" },
      { value: "widget", label: "Widget tests only" },
      { value: "integration", label: "Integration tests only" },
    ]);

    const args = {
      all: ["test"],
      unit: ["test", "--unit"],
      widget: ["test", "--widget"],
      integration: ["test", "--integration"],
    };

    const command = `flutter ${args[testType].join(" ")}`;

    yield prompt.terminal({ command });
  },
};
