#!/usr/bin/env node
/**
 * ArgoCD MCP Server
 * Provides ArgoCD application management tools
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

class ArgoCDMCPServer {
  constructor() {}

  /**
   * List ArgoCD applications
   */
  async listApps() {
    const { stdout } = await execAsync('argocd app list -o json');
    return JSON.parse(stdout);
  }

  /**
   * Get ArgoCD application details
   */
  async getApp(appName) {
    const { stdout } = await execAsync(`argocd app get ${appName} -o json`);
    return JSON.parse(stdout);
  }

  /**
   * Sync ArgoCD application
   */
  async syncApp(appName) {
    const { stdout } = await execAsync(`argocd app sync ${appName}`);
    return stdout;
  }

  /**
   * Get ArgoCD application history
   */
  async getHistory(appName) {
    const { stdout } = await execAsync(`argocd app history ${appName} -o json`);
    return JSON.parse(stdout);
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case 'argocd_app_list':
        return await this.listApps();
      case 'argocd_app_get':
        return await this.getApp(args.appName);
      case 'argocd_app_sync':
        return await this.syncApp(args.appName);
      case 'argocd_app_history':
        return await this.getHistory(args.appName);
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

const server = new ArgoCDMCPServer();

process.stdin.on('data', async (data) => {
  try {
    const message = JSON.parse(data.toString());
    const result = await server.handleToolCall(message.tool, message.args || {});
    console.log(JSON.stringify({ success: true, result }));
  } catch (error) {
    console.log(JSON.stringify({ success: false, error: error.message }));
  }
});
/**
 * ArgoCD MCP Server
 * Provides ArgoCD application management tools
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

class ArgoCDMCPServer {
  constructor() {}

  /**
   * List ArgoCD applications
   */
  async listApps() {
    const { stdout } = await execAsync('argocd app list -o json');
    return JSON.parse(stdout);
  }

  /**
   * Get ArgoCD application details
   */
  async getApp(appName) {
    const { stdout } = await execAsync(`argocd app get ${appName} -o json`);
    return JSON.parse(stdout);
  }

  /**
   * Sync ArgoCD application
   */
  async syncApp(appName) {
    const { stdout } = await execAsync(`argocd app sync ${appName}`);
    return stdout;
  }

  /**
   * Get ArgoCD application history
   */
  async getHistory(appName) {
    const { stdout } = await execAsync(`argocd app history ${appName} -o json`);
    return JSON.parse(stdout);
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case 'argocd_app_list':
        return await this.listApps();
      case 'argocd_app_get':
        return await this.getApp(args.appName);
      case 'argocd_app_sync':
        return await this.syncApp(args.appName);
      case 'argocd_app_history':
        return await this.getHistory(args.appName);
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

const server = new ArgoCDMCPServer();

process.stdin.on('data', async (data) => {
  try {
    const message = JSON.parse(data.toString());
    const result = await server.handleToolCall(message.tool, message.args || {});
    console.log(JSON.stringify({ success: true, result }));
  } catch (error) {
    console.log(JSON.stringify({ success: false, error: error.message }));
  }
});

