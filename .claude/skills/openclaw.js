/**
 * OpenClaw Personal AI Assistant Skill
 * Manages OpenClaw - local AI assistant for messaging platforms
 */

module.exports = {
  id: "openclaw",
  title: "OpenClaw Assistant",
  description: "Manage OpenClaw personal AI assistant - gateway, agent, skills, channels",
  icon: "🦞",

  *run(context) {
    const { ask, prompt } = context;

    const action = yield ask.select("What would you like to do?", [
      { value: "status", label: "Check OpenClaw status" },
      { value: "gateway", label: "Start/Manage Gateway" },
      { value: "agent", label: "Send message to agent" },
      { value: "skills", label: "Manage skills" },
      { value: "channels", label: "Manage channels (login/status)" },
      { value: "config", label: "View/Edit configuration" },
      { value: "onboard", label: "Run onboarding wizard" },
      { value: "logs", label: "View logs" },
      { value: "update", label: "Update OpenClaw" },
      { value: "doctor", label: "Run health check (doctor)" },
    ]);

    switch (action) {
      case "status":
        yield prompt.terminal({
          command: `openclaw status || echo "OpenClaw may not be installed. Run: npm install -g openclaw@latest"`,
        });
        break;

      case "gateway":
        const gatewayAction = yield ask.select("Gateway action:", [
          { value: "start", label: "Start gateway" },
          { value: "stop", label: "Stop gateway" },
          { value: "restart", label: "Restart gateway" },
          { value: "status", label: "Check gateway status" },
        ]);
        const port = yield ask.text("Gateway port (default: 18789):", "18789");
        yield prompt.terminal({
          command: `openclaw gateway --${gatewayAction} --port ${port}`,
        });
        break;

      case "agent":
        const message = yield ask.text("Enter your message for the agent:");
        const thinking = yield ask.select("Thinking level:", [
          { value: "", label: "Default" },
          { value: "--thinking minimal", label: "Minimal" },
          { value: "--thinking low", label: "Low" },
          { value: "--thinking medium", label: "Medium" },
          { value: "--thinking high", label: "High" },
          { value: "--thinking xhigh", label: "Extra High" },
        ]);
        yield prompt.terminal({
          command: `openclaw agent --message "${message}" ${thinking}`,
        });
        break;

      case "skills":
        const skillsAction = yield ask.select("Skills action:", [
          { value: "list", label: "List installed skills" },
          { value: "search", label: "Search ClawHub for skills" },
          { value: "install", label: "Install a skill" },
          { value: "remove", label: "Remove a skill" },
          { value: "workspace", label: "Open workspace directory" },
        ]);

        if (skillsAction === "list") {
          yield prompt.terminal({
            command: `ls -la ~/.openclaw/workspace/skills/ 2>/dev/null || echo "No skills found. Workspace may not be initialized."`,
          });
        } else if (skillsAction === "search") {
          const searchTerm = yield ask.text("Enter search term:");
          yield prompt.terminal({
            command: `openclaw skills search ${searchTerm}`,
          });
        } else if (skillsAction === "install") {
          const skillName = yield ask.text("Enter skill name:");
          yield prompt.terminal({
            command: `openclaw skills install ${skillName}`,
          });
        } else if (skillsAction === "remove") {
          const skillName = yield ask.text("Enter skill name to remove:");
          yield prompt.terminal({
            command: `openclaw skills remove ${skillName}`,
          });
        } else if (skillsAction === "workspace") {
          yield prompt.terminal({
            command: `echo "Workspace location: ~/.openclaw/workspace/" && ls -la ~/.openclaw/workspace/`,
          });
        }
        break;

      case "channels":
        const channelAction = yield ask.select("Channels action:", [
          { value: "login", label: "Login to a channel" },
          { value: "status", label: "Check channel status" },
          { value: "list", label: "List configured channels" },
        ]);

        if (channelAction === "login") {
          yield prompt.terminal({
            command: `openclaw channels login`,
          });
        } else if (channelAction === "status") {
          yield prompt.terminal({
            command: `openclaw channels status`,
          });
        } else if (channelAction === "list") {
          yield prompt.terminal({
            command: `cat ~/.openclaw/openclaw.json | grep -A 20 '"channels"' || echo "No channels configured"`,
          });
        }
        break;

      case "config":
        yield prompt.terminal({
          command: `echo "OpenClaw config location: ~/.openclaw/openclaw.json" && echo "" && cat ~/.openclaw/openclaw.json`,
        });
        const editConfig = yield ask.select("Would you like to edit the config?", [
          { value: "yes", label: "Yes, open in editor" },
          { value: "no", label: "No" },
        ]);
        if (editConfig === "yes") {
          const editor = yield ask.text("Enter your editor (default: code):", "code");
          yield prompt.terminal({
            command: `${editor} ~/.openclaw/openclaw.json`,
          });
        }
        break;

      case "onboard":
        yield prompt.note({
          message: "This will launch the OpenClaw onboarding wizard to set up gateway, workspace, channels, and skills.",
        });
        const installDaemon = yield ask.select("Install as daemon service?", [
          { value: "yes", label: "Yes, install daemon (recommended)" },
          { value: "no", label: "No, skip daemon install" },
        ]);
        const daemonFlag = installDaemon === "yes" ? "--install-daemon" : "";
        yield prompt.terminal({
          command: `openclaw onboard ${daemonFlag}`,
        });
        break;

      case "logs":
        yield prompt.terminal({
          command: `echo "OpenClaw logs location: ~/.openclaw/logs/" && ls -la ~/.openclaw/logs/ && echo "" && echo "Recent logs:" && tail -50 ~/.openclaw/logs/gateway.log 2>/dev/null || echo "No logs found"`,
        });
        break;

      case "update":
        yield prompt.note({
          message: "This will update OpenClaw to the latest version.",
        });
        const channel = yield ask.select("Select update channel:", [
          { value: "latest", label: "Stable (latest)" },
          { value: "beta", label: "Beta" },
          { value: "dev", label: "Dev (unstable)" },
        ]);
        yield prompt.terminal({
          command: `openclaw update --channel ${channel}`,
        });
        break;

      case "doctor":
        yield prompt.note({
          message: "Running OpenClaw health check...",
        });
        yield prompt.terminal({
          command: `openclaw doctor`,
        });
        break;
    }
  },
};
