import fs from 'fs';

const config = {
  "mcpServers": {
    "cloudflare": {
      "alwaysAllow": [
        "accounts_list",
        "set_active_account",
        "workers_list",
        "workers_get_worker",
        "workers_get_worker_code",
        "query_worker_observability",
        "observability_keys",
        "observability_values",
        "search_cloudflare_documentation",
        "migrate_pages_to_workers_guide"
      ],
      "args": [
        "mcp-remote",
        "https://observability.mcp.cloudflare.com/sse"
      ],
      "command": "npx"
    },
    "context7": {
      "alwaysAllow": [
        "resolve-library-id",
        "query-docs"
      ],
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ],
      "command": "npx",
      "env": {
        "DEFAULT_MINIMUM_TOKENS": ""
      }
    },
    "memory": {
      "alwaysAllow": [
        "create_entities",
        "create_relations",
        "add_observations",
        "delete_entities",
        "delete_observations",
        "delete_relations",
        "read_graph",
        "search_nodes",
        "open_nodes"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "command": "npx"
    },
    "sequentialthinking": {
      "alwaysAllow": [
        "sequentialthinking"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "command": "npx"
    },
    "kubernetes": {
      "alwaysAllow": [
        "get_pods",
        "get_pod_logs",
        "get_deployments",
        "scale_deployment",
        "restart_deployment",
        "get_services",
        "get_ingress",
        "apply_manifest",
        "delete_resource",
        "get_nodes"
      ],
      "args": [
        "config/mcp/servers/kubernetes-server.js"
      ],
      "command": "node"
    },
    "flutter": {
      "alwaysAllow": [
        "flutter_doctor",
        "flutter_pub_get",
        "flutter_build",
        "flutter_test",
        "dart_analyze"
      ],
      "args": [
        "config/mcp/servers/flutter-server.js"
      ],
      "command": "node"
    },
    "argocd": {
      "alwaysAllow": [
        "argocd_app_list",
        "argocd_app_get",
        "argocd_app_sync",
        "argocd_app_history"
      ],
      "args": [
        "config/mcp/servers/argocd-server.js"
      ],
      "command": "node"
    },
    "nodejs": {
      "alwaysAllow": [
        "npm_install",
        "npm_test",
        "npm_run",
        "node_eval"
      ],
      "args": [
        "config/mcp/servers/nodejs-server.js"
      ],
      "command": "node"
    },
    "docker": {
      "alwaysAllow": [
        "docker_ps",
        "docker_images",
        "docker_run",
        "docker_stop",
        "docker_rm",
        "docker_logs",
        "docker_inspect",
        "docker_network_ls",
        "docker_volume_ls"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-docker"
      ],
      "command": "npx"
    }
  }
};

fs.writeFileSync('.kilocode/mcp.json', JSON.stringify(config, null, 2));
console.log('Successfully wrote .kilocode/mcp.json');

const config = {
  "mcpServers": {
    "cloudflare": {
      "alwaysAllow": [
        "accounts_list",
        "set_active_account",
        "workers_list",
        "workers_get_worker",
        "workers_get_worker_code",
        "query_worker_observability",
        "observability_keys",
        "observability_values",
        "search_cloudflare_documentation",
        "migrate_pages_to_workers_guide"
      ],
      "args": [
        "mcp-remote",
        "https://observability.mcp.cloudflare.com/sse"
      ],
      "command": "npx"
    },
    "context7": {
      "alwaysAllow": [
        "resolve-library-id",
        "query-docs"
      ],
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ],
      "command": "npx",
      "env": {
        "DEFAULT_MINIMUM_TOKENS": ""
      }
    },
    "memory": {
      "alwaysAllow": [
        "create_entities",
        "create_relations",
        "add_observations",
        "delete_entities",
        "delete_observations",
        "delete_relations",
        "read_graph",
        "search_nodes",
        "open_nodes"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "command": "npx"
    },
    "sequentialthinking": {
      "alwaysAllow": [
        "sequentialthinking"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "command": "npx"
    },
    "kubernetes": {
      "alwaysAllow": [
        "get_pods",
        "get_pod_logs",
        "get_deployments",
        "scale_deployment",
        "restart_deployment",
        "get_services",
        "get_ingress",
        "apply_manifest",
        "delete_resource",
        "get_nodes"
      ],
      "args": [
        "config/mcp/servers/kubernetes-server.js"
      ],
      "command": "node"
    },
    "flutter": {
      "alwaysAllow": [
        "flutter_doctor",
        "flutter_pub_get",
        "flutter_build",
        "flutter_test",
        "dart_analyze"
      ],
      "args": [
        "config/mcp/servers/flutter-server.js"
      ],
      "command": "node"
    },
    "argocd": {
      "alwaysAllow": [
        "argocd_app_list",
        "argocd_app_get",
        "argocd_app_sync",
        "argocd_app_history"
      ],
      "args": [
        "config/mcp/servers/argocd-server.js"
      ],
      "command": "node"
    },
    "nodejs": {
      "alwaysAllow": [
        "npm_install",
        "npm_test",
        "npm_run",
        "node_eval"
      ],
      "args": [
        "config/mcp/servers/nodejs-server.js"
      ],
      "command": "node"
    },
    "docker": {
      "alwaysAllow": [
        "docker_ps",
        "docker_images",
        "docker_run",
        "docker_stop",
        "docker_rm",
        "docker_logs",
        "docker_inspect",
        "docker_network_ls",
        "docker_volume_ls"
      ],
      "args": [
        "-y",
        "@modelcontextprotocol/server-docker"
      ],
      "command": "npx"
    }
  }
};

fs.writeFileSync('.kilocode/mcp.json', JSON.stringify(config, null, 2));
console.log('Successfully wrote .kilocode/mcp.json');

