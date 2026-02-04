# ============================================================================
# MCP Tools Setup Script
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║           MCP Tools Setup for Zoidbot                  ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Add doctl to PATH
$env:Path = "$env:Path;$env:LOCALAPPDATA\doctl"

Write-Host "✓ MCP Configuration Files Created" -ForegroundColor Green
Write-Host "  - config/mcp/digitalocean-mcp.json" -ForegroundColor White
Write-Host "  - config/mcp/servers/digitalocean-server.js" -ForegroundColor White
Write-Host "  - config/mcp/servers/kubernetes-server.js" -ForegroundColor White
Write-Host ""

Write-Host "Available MCP Tools:" -ForegroundColor Yellow
Write-Host ""
Write-Host "DigitalOcean MCP Server:" -ForegroundColor Cyan
Write-Host "  • list_clusters          - List all K8s clusters" -ForegroundColor White
Write-Host "  • get_cluster            - Get cluster details" -ForegroundColor White
Write-Host "  • get_kubeconfig         - Download kubeconfig" -ForegroundColor White
Write-Host "  • list_registry_repos    - List container images" -ForegroundColor White
Write-Host "  • login_registry         - Login to registry" -ForegroundColor White
Write-Host "  • get_load_balancer      - Get load balancer info" -ForegroundColor White
Write-Host "  • scale_node_pool        - Scale cluster nodes" -ForegroundColor White
Write-Host ""

Write-Host "Kubernetes MCP Server:" -ForegroundColor Cyan
Write-Host "  • get_pods               - List pods" -ForegroundColor White
Write-Host "  • get_pod_logs           - View pod logs" -ForegroundColor White
Write-Host "  • get_deployments        - List deployments" -ForegroundColor White
Write-Host "  • scale_deployment       - Scale deployment" -ForegroundColor White
Write-Host "  • restart_deployment     - Restart deployment" -ForegroundColor White
Write-Host "  • get_services           - List services" -ForegroundColor White
Write-Host "  • get_ingress            - List ingress" -ForegroundColor White
Write-Host "  • apply_manifest         - Apply K8s manifest" -ForegroundColor White
Write-Host "  • get_nodes              - List cluster nodes" -ForegroundColor White
Write-Host ""

Write-Host "Environment Variables Required:" -ForegroundColor Yellow
Write-Host "  DIGITALOCEAN_TOKEN       - Your DO API token" -ForegroundColor White
Write-Host "  GITHUB_TOKEN             - GitHub PAT (for CI/CD)" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "  1. Configure CI/CD workflows" -ForegroundColor White
Write-Host "  2. Set up GitHub Secrets" -ForegroundColor White
Write-Host "  3. Build and push Docker images" -ForegroundColor White
Write-Host "  4. Deploy to Kubernetes" -ForegroundColor White
Write-Host ""

