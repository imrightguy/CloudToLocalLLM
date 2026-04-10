#!/usr/bin/env node
/**
 * Kubernetes MCP Server
 * Provides Kubernetes cluster management and operations
 */

import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

class KubernetesMCPServer {
  constructor() {
    this.namespace = process.env.KUBERNETES_NAMESPACE || "CloudToLocalLLM";
  }

  /**
   * Get pods in namespace
   */
  async getPods(namespace = this.namespace) {
    const { stdout } = await execAsync(
      `kubectl get pods -n ${namespace} -o json`,
    );
    const data = JSON.parse(stdout);
    return data.items.map((pod) => ({
      name: pod.metadata.name,
      status: pod.status.phase,
      ready:
        pod.status.conditions?.find((c) => c.type === "Ready")?.status ===
        "True",
      restarts: pod.status.containerStatuses?.[0]?.restartCount || 0,
      age: pod.metadata.creationTimestamp,
    }));
  }

  /**
   * Get pod logs
   */
  async getPodLogs(podName, namespace = this.namespace, lines = 100) {
    const { stdout } = await execAsync(
      `kubectl logs -n ${namespace} ${podName} --tail=${lines}`,
    );
    return stdout;
  }

  /**
   * Get deployments
   */
  async getDeployments(namespace = this.namespace) {
    const { stdout } = await execAsync(
      `kubectl get deployments -n ${namespace} -o json`,
    );
    const data = JSON.parse(stdout);
    return data.items.map((deploy) => ({
      name: deploy.metadata.name,
      replicas: deploy.spec.replicas,
      available: deploy.status.availableReplicas || 0,
      ready: deploy.status.readyReplicas || 0,
      upToDate: deploy.status.updatedReplicas || 0,
    }));
  }

  /**
   * Scale deployment
   */
  async scaleDeployment(deploymentName, replicas, namespace = this.namespace) {
    await execAsync(
      `kubectl scale deployment/${deploymentName} -n ${namespace} --replicas=${replicas}`,
    );
    return {
      success: true,
      message: `Scaled ${deploymentName} to ${replicas} replicas`,
    };
  }

  /**
   * Rollout restart deployment
   */
  async restartDeployment(deploymentName, namespace = this.namespace) {
    await execAsync(
      `kubectl rollout restart deployment/${deploymentName} -n ${namespace}`,
    );
    return { success: true, message: `Restarted ${deploymentName}` };
  }

  /**
   * Get services
   */
  async getServices(namespace = this.namespace) {
    const { stdout } = await execAsync(
      `kubectl get services -n ${namespace} -o json`,
    );
    const data = JSON.parse(stdout);
    return data.items.map((svc) => ({
      name: svc.metadata.name,
      type: svc.spec.type,
      clusterIP: svc.spec.clusterIP,
      externalIP: svc.status.loadBalancer?.ingress?.[0]?.ip || "none",
      ports: svc.spec.ports.map(
        (p) => `${p.port}:${p.targetPort}/${p.protocol}`,
      ),
    }));
  }

  /**
   * Get ingress
   */
  async getIngress(namespace = this.namespace) {
    const { stdout } = await execAsync(
      `kubectl get ingress -n ${namespace} -o json`,
    );
    const data = JSON.parse(stdout);
    return data.items.map((ing) => ({
      name: ing.metadata.name,
      hosts: ing.spec.rules?.map((r) => r.host) || [],
      address: ing.status.loadBalancer?.ingress?.[0]?.ip || "pending",
    }));
  }

  /**
   * Apply manifest
   */
  async applyManifest(manifestPath) {
    const { stdout } = await execAsync(`kubectl apply -f ${manifestPath}`);
    return { success: true, output: stdout };
  }

  /**
   * Delete resource
   */
  async deleteResource(resourceType, resourceName, namespace = this.namespace) {
    const { stdout } = await execAsync(
      `kubectl delete ${resourceType} ${resourceName} -n ${namespace}`,
    );
    return { success: true, output: stdout };
  }

  /**
   * Get cluster nodes
   */
  async getNodes() {
    const { stdout } = await execAsync("kubectl get nodes -o json");
    const data = JSON.parse(stdout);
    return data.items.map((node) => ({
      name: node.metadata.name,
      status:
        node.status.conditions?.find((c) => c.type === "Ready")?.status ===
        "True"
          ? "Ready"
          : "NotReady",
      version: node.status.nodeInfo.kubeletVersion,
      cpu: node.status.capacity.cpu,
      memory: node.status.capacity.memory,
    }));
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case "get_pods":
        return await this.getPods(args.namespace);
      case "get_pod_logs":
        return await this.getPodLogs(args.podName, args.namespace, args.lines);
      case "get_deployments":
        return await this.getDeployments(args.namespace);
      case "scale_deployment":
        return await this.scaleDeployment(
          args.deployment,
          args.replicas,
          args.namespace,
        );
      case "restart_deployment":
        return await this.restartDeployment(args.deployment, args.namespace);
      case "get_services":
        return await this.getServices(args.namespace);
      case "get_ingress":
        return await this.getIngress(args.namespace);
      case "apply_manifest":
        return await this.applyManifest(args.manifestPath);
      case "delete_resource":
        return await this.deleteResource(
          args.resourceType,
          args.resourceName,
          args.namespace,
        );
      case "get_nodes":
        return await this.getNodes();
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

export default KubernetesMCPServer;

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = new KubernetesMCPServer();
  console.log("Kubernetes MCP Server ready");

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
}
