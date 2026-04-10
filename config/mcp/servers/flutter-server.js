#!/usr/bin/env node
/**
 * Flutter/Dart MCP Server
 * Provides Flutter and Dart development tools
 */

import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

class FlutterMCPServer {
  constructor() {}

  /**
   * Run flutter doctor
   */
  async doctor() {
    const { stdout } = await execAsync("flutter doctor");
    return stdout;
  }

  /**
   * Run flutter pub get
   */
  async pubGet(directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && flutter pub get`);
    return stdout;
  }

  /**
   * Run flutter build
   */
  async build(target, directory = ".") {
    const { stdout } = await execAsync(
      `cd ${directory} && flutter build ${target}`,
    );
    return stdout;
  }

  /**
   * Run flutter test
   */
  async test(directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && flutter test`);
    return stdout;
  }

  /**
   * Run dart analyze
   */
  async analyze(directory = ".") {
    const { stdout } = await execAsync(`cd ${directory} && dart analyze`);
    return stdout;
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case "flutter_doctor":
        return await this.doctor();
      case "flutter_pub_get":
        return await this.pubGet(args.directory);
      case "flutter_build":
        return await this.build(args.target, args.directory);
      case "flutter_test":
        return await this.test(args.directory);
      case "dart_analyze":
        return await this.analyze(args.directory);
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

const server = new FlutterMCPServer();

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
