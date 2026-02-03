/**
 * Build Release Skill
 * Builds release versions of the Flutter app or Docker images
 */

module.exports = {
  id: "build-release",
  title: "Build Release",
  description: "Build release versions (Flutter Web/Linux/Windows or Docker images)",
  icon: "📦",

  *run(context) {
    const { ask, prompt } = context;

    const buildType = yield ask.select("What would you like to build?", [
      { value: "flutter-web", label: "Flutter: Web release" },
      { value: "flutter-linux", label: "Flutter: Linux release" },
      { value: "flutter-windows", label: "Flutter: Windows release" },
      { value: "docker-api", label: "Docker: API Backend image" },
      { value: "docker-all", label: "Docker: All service images" },
    ]);

    const commands = {
      "flutter-web": "flutter build web --release",
      "flutter-linux": "flutter build linux --release",
      "flutter-windows": "flutter build windows --release",
      "docker-api": "docker build -f config/docker/Dockerfile.api-backend -t cloudtolocallm-api:latest .",
      "docker-all": "docker build -f config/docker/Dockerfile.api-backend -t cloudtolocallm-api:latest . && docker build -f config/docker/Dockerfile.streaming-proxy -t cloudtolocallm-proxy:latest . && docker build -f config/docker/Dockerfile.sdk -t cloudtolocallm-sdk:latest .",
    };

    const command = commands[buildType];

    yield prompt.note({
      message: `Building ${buildType}... This may take a few minutes.`,
    });

    yield prompt.terminal({ command });
  },
};
