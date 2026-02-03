/**
 * Flutter Run Skill
 * Runs the Flutter app on selected platform
 */

module.exports = {
  id: "flutter-run",
  title: "Flutter Run",
  description: "Run the Flutter app on Linux, Windows, or Web",
  icon: "🚀",

  *run(context) {
    const { ask, prompt } = context;

    const platform = yield ask.select("Which platform?", [
      { value: "linux", label: "Linux" },
      { value: "windows", label: "Windows" },
      { value: "chrome", label: "Web (Chrome)" },
      { value: "edge", label: "Web (Edge)" },
    ]);

    const command = `flutter run -d ${platform}`;

    yield prompt.terminal({ command });
  },
};
