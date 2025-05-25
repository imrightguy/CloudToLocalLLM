# MCP Flutter Inspector Remote Debugging Guide

This guide explains how to set up remote debugging for the CloudToLocalLLM production application using the MCP Flutter Inspector.

## 🎯 Overview

The MCP Flutter Inspector allows you to debug and inspect your live Flutter web application running on cloudtolocalllm.online in real-time through Augment. This includes:

- **Widget Tree Inspection**: View the complete widget hierarchy
- **Visual Debugging**: Take screenshots and analyze layouts
- **Performance Monitoring**: Monitor frame timing and memory usage
- **Runtime Debugging**: Catch errors and inspect state changes

## 🔧 Prerequisites

1. **SSH Access**: SSH key access to cloudtolocalllm.online
2. **Local MCP Server**: MCP Flutter Inspector installed locally
3. **Augment**: VSCode with Augment extension
4. **Network Access**: Ability to create SSH tunnels

## 🚀 Quick Start

### Step 1: Deploy Debug-Enabled Version

On your VPS (cloudtolocalllm.online):

```bash
# SSH to your VPS
ssh cloudllm@cloudtolocalllm.online

# Navigate to your project directory
cd /path/to/CloudToLocalLLM

# Deploy with debug support
chmod +x deploy_mcp_debug.sh
./deploy_mcp_debug.sh
```

### Step 2: Set Up Secure Tunnel

On your local machine:

```bash
# Navigate to your local project
cd ~/Dev/CloudToLocalLLM

# Set up SSH tunnels
chmod +x scripts/setup_mcp_tunnel.sh
./scripts/setup_mcp_tunnel.sh
```

### Step 3: Configure Local MCP Server

Update your MCP configuration to enable the remote server:

```bash
# Edit the MCP configuration
nano config/mcp_servers.json

# Change "disabled": true to "disabled": false for flutter-inspector-remote
```

### Step 4: Test Connection

Ask Augment:
- "Take a screenshot of the CloudToLocalLLM production app"
- "Show me the widget tree of the live application"
- "What's the current performance of the production app?"

## 📁 File Structure

```
CloudToLocalLLM/
├── deploy_mcp_debug.sh          # Enable debug mode on VPS
├── deploy_mcp_cleanup.sh        # Disable debug mode on VPS
├── scripts/
│   ├── setup_mcp_tunnel.sh      # Create SSH tunnels
│   └── stop_mcp_tunnel.sh       # Stop SSH tunnels
├── config/
│   ├── mcp_servers.json         # Main MCP configuration
│   └── mcp_remote_config.json   # Remote debugging configuration
└── docs/
    └── MCP_REMOTE_DEBUGGING_GUIDE.md  # This guide
```

## 🔒 Security Considerations

### Firewall Configuration
The debug deployment temporarily opens these ports:
- **8182**: Flutter VM Service
- **8181**: Flutter DDS (Dart Development Service)
- **3334**: MCP Server

### SSH Tunnel Security
- Uses SSH key authentication
- Creates local port forwards (18182, 18181, 13334)
- Encrypts all debug traffic

### Best Practices
1. **Limit Debug Time**: Only enable debug mode when actively debugging
2. **Use SSH Tunnels**: Never expose debug ports directly to the internet
3. **Monitor Access**: Check SSH logs for unauthorized access attempts
4. **Clean Up**: Always run cleanup scripts after debugging

## 🛠️ Troubleshooting

### Connection Issues

**Problem**: SSH tunnel fails to connect
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Test SSH connection
ssh -i ~/.ssh/id_rsa cloudllm@cloudtolocalllm.online
```

**Problem**: Flutter VM Service not accessible
```bash
# Check if debug deployment is running
ssh cloudllm@cloudtolocalllm.online "docker ps | grep debug"

# Check if ports are open
ssh cloudllm@cloudtolocalllm.online "netstat -ln | grep 8182"
```

### MCP Server Issues

**Problem**: MCP server can't connect to remote Flutter app
```bash
# Verify tunnel is active
netstat -ln | grep 18182

# Check MCP server logs
node ~/Dev/Tools/MCP/mcp_flutter/mcp_server/build/index.js --help
```

### Performance Issues

**Problem**: Slow response from remote debugging
- **Solution**: Use SSH compression: `ssh -C` in tunnel scripts
- **Solution**: Reduce debug data frequency
- **Solution**: Use local debugging for intensive operations

## 🔄 Workflow

### Daily Debugging Session

1. **Start Debug Mode**:
   ```bash
   # On VPS
   ./deploy_mcp_debug.sh
   
   # On Local
   ./scripts/setup_mcp_tunnel.sh
   ```

2. **Debug with Augment**:
   - Enable remote MCP server in config
   - Use Augment commands to inspect the live app
   - Analyze performance and debug issues

3. **End Session**:
   ```bash
   # On Local
   ./scripts/stop_mcp_tunnel.sh
   
   # On VPS
   ./deploy_mcp_cleanup.sh
   ```

### Emergency Debugging

For urgent production issues:

```bash
# Quick debug deployment (5 minutes)
ssh cloudllm@cloudtolocalllm.online "cd /path/to/project && ./deploy_mcp_debug.sh"

# Quick tunnel setup
./scripts/setup_mcp_tunnel.sh

# Debug the issue with Augment
# ...

# Quick cleanup
./scripts/stop_mcp_tunnel.sh
ssh cloudllm@cloudtolocalllm.online "cd /path/to/project && ./deploy_mcp_cleanup.sh"
```

## 📊 Available Commands

Once connected, you can use these Augment commands:

### Visual Inspection
- "Take a screenshot of the production app"
- "Show me the current widget tree"
- "Highlight the login button in the UI"

### Performance Analysis
- "What's the current memory usage?"
- "Show me frame timing information"
- "Are there any performance bottlenecks?"

### Debugging
- "Show me any runtime errors"
- "What widgets are currently rebuilding?"
- "Inspect the authentication state"

### Layout Analysis
- "Analyze the responsive layout"
- "Show me the CSS properties of the main container"
- "What's the current viewport size?"

## 🆘 Emergency Procedures

### If Debug Ports Are Exposed
```bash
# Immediate cleanup
ssh cloudllm@cloudtolocalllm.online "ufw deny 8182 && ufw deny 8181 && ufw deny 3334"
./deploy_mcp_cleanup.sh
```

### If SSH Tunnels Are Stuck
```bash
# Kill all SSH processes to the VPS
pkill -f "ssh.*cloudtolocalllm.online"

# Restart tunnel setup
./scripts/setup_mcp_tunnel.sh
```

### If Production App Is Down
```bash
# Emergency production restore
ssh cloudllm@cloudtolocalllm.online "cd /path/to/project && ./deploy_mcp_cleanup.sh"
```

## 📞 Support

For issues with this setup:
1. Check the troubleshooting section above
2. Review SSH and Docker logs on the VPS
3. Verify MCP server configuration locally
4. Test with local Flutter app first
