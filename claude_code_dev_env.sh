#!/bin/bash
# =============================================================================
# Zoidbot Development Environment Aliases
# =============================================================================
# Source this file in your shell:
#   source /mnt/data/dev/Zoidbot/claude_code_dev_env.sh
#
# Or add to ~/.bashrc:
#   source /mnt/data/dev/Zoidbot/claude_code_dev_env.sh
# =============================================================================

# Project root
export CLOUD_TO_LOCAL_LLM_ROOT="/mnt/data/dev/Zoidbot"
cd "$CLOUD_TO_LOCAL_LLM_ROOT" 2>/dev/null || true

# =============================================================================
# Flutter Development Aliases
# =============================================================================

# Flutter Run
alias fw='flutter run -d linux'
alias fw-win='flutter run -d windows'
alias fw-web='flutter run -d chrome'
alias fw-edge='flutter run -d edge'

# Flutter Testing
alias ft='flutter test'
alias ft-coverage='flutter test --coverage'
alias ft-watch='flutter test --watch'

# Flutter Analysis
alias fa='flutter analyze'
alias ff='flutter format .'
alias ffw='flutter format --set-exit-if-changed .'

# Flutter Build
alias fb-web='flutter build web --release'
alias fb-linux='flutter build linux --release'
alias fb-win='flutter build windows --release'

# Flutter Pub
alias fp='flutter pub get'
alias fup='flutter pub upgrade'
alias fout='flutter pub outdated'

# =============================================================================
# Backend Development Aliases
# =============================================================================

# API Backend
alias api-dev='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run dev'
alias api-test='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm test'
alias api-test-unit='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run test:unit'
alias api-test-auth='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run test:auth'
alias api-test-security='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run test:security'
alias api-lint='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run lint'
alias api-format='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run format'

# SDK
alias sdk-dev='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/sdk" && npm run dev'
alias sdk-build='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/sdk" && npm run build'
alias sdk-test='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/sdk" && npm test'

# Streaming Proxy
alias proxy-dev='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/streaming-proxy" && npm run dev'
alias proxy-lint='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/streaming-proxy" && npm run lint'

# =============================================================================
# Database Aliases
# =============================================================================

alias db-migrate='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run db:migrate'
alias db-validate='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run db:validate'
alias db-stats='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run db:stats'

# PostgreSQL CLI (requires pgcli)
alias db-cli='pgcli postgresql://cloudtolocallm:your-password@localhost:5432/cloudtolocallm'
alias db-psql='psql postgresql://cloudtolocallm:your-password@localhost:5432/cloudtolocallm'

# =============================================================================
# Docker & DevOps Aliases
# =============================================================================

alias dc='docker-compose'
alias dcb='docker-compose build'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
alias dcud='docker-compose up -d'
alias dcl='docker-compose logs -f'
alias dcps='docker-compose ps'

# Docker container management
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# =============================================================================
# Git Aliases
# =============================================================================

alias gp='git push'
alias gpn='git push --no-verify'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gpp='git pull --rebase'

alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias glog='git log --oneline --graph --decorate --all'

alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

alias gb='git branch'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcom='git checkout main'

# =============================================================================
# Claude Code Aliases
# =============================================================================

alias cc='claude'
alias cc-here='claude --cwd "$PWD"'

# =============================================================================
# Utility Functions
# =============================================================================

# Run all tests (Flutter + Backend)
alias test-all='flutter test && cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm test'

# Format all code
alias format-all='flutter format . && cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend" && npm run format && cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/sdk" && npm run format && cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/streaming-proxy" && npm run format'

# Watch mode for development (requires watchexec)
alias watch-flutter='watchexec -w lib flutter run -d linux'
alias watch-api='watchexec -w src npm run dev'

# =============================================================================
# Development Navigation
# =============================================================================

alias cdroot='cd "$CLOUD_TO_LOCAL_LLM_ROOT"'
alias cdapi='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/api-backend"'
alias cdsdk='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/sdk"'
alias cdproxy='cd "$CLOUD_TO_LOCAL_LLM_ROOT/services/streaming-proxy"'
alias cdweb='cd "$CLOUD_TO_LOCAL_LLM_ROOT/web"'

# =============================================================================
# Installation Instructions
# =============================================================================

# To enable these aliases permanently, add this line to your ~/.bashrc:
#   source /mnt/data/dev/Zoidbot/claude_code_dev_env.sh

# Optional tools to install:
#   - pgcli:       pip install pgcli           # Better PostgreSQL CLI
#   - lazygit:     brew install lazygit        # Terminal Git UI
#   - watchexec:   cargo install watchexec     # File watcher for dev
#   - fvm:         dart pub global activate fvm # Flutter version manager

# =============================================================================
# Info
# =============================================================================

echo "Zoidbot development environment loaded!"
echo "Project root: $CLOUD_TO_LOCAL_LLM_ROOT"
echo ""
echo "Quick start:"
echo "  fw         - Run Flutter on Linux"
echo "  api-dev    - Start API backend in dev mode"
echo "  ft         - Run Flutter tests"
echo "  api-test   - Run backend tests"
echo "  dcu        - Start Docker Compose services"
echo ""
echo "Type 'alias' to see all available aliases"
