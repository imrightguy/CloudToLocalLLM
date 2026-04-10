#!/usr/bin/env node
/**
 * Node.js MCP Server
 * Provides Node.js and npm development tools
 */

import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

class NodejsMCPServer {
  constructor() {}

  /**
   * Run npm install
   */
  async npmInstall(directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && npm install`);
    return stdout;
  }

  /**
   * Run npm test
   */
  async npmTest(directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && npm test`);
    return stdout;
  }

  /**
   * Run npm run script
   */
  async npmRun(script, directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && npm run ${script}`);
    return stdout;
  }

  /**
   * Evaluate Node.js code
   */
  async nodeEval(code) {
    const { stdout } = await execAsync(
      `node -e "${code.replace(/"/g, '\\"')}"`,
    );
    return stdout;
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case "npm_install":
        return await this.npmInstall(args.directory);
      case "npm_test":
        return await this.npmTest(args.directory);
      case "npm_run":
        return await this.npmRun(args.script, args.directory);
      case "node_eval":
        return await this.nodeEval(args.code);
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

const server = new NodejsMCPServer();

process.stdin.on("data", async (data) => {
  try {
    const message = JSON.parse(data.toString());
    const result = await server.handleToolCall(
      message.tool,
      message.args || {},
    );
    console.log(JSON.stringify({ success: true, result }));
  } catch (error) {
    console.log(JSON.stringify({ success: false, error: error.message }));
  }
});
