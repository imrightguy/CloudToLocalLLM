# AGENTS.md - Debug Mode

This file provides debugging-specific guidance for AI agents.

## Non-Obvious Debugging Rules

### Flutter Debugging
- Use `debugPrint()` instead of `print()` for development logging
- LLM Router runs on port 1337 - check if running with `curl http://localhost:1337/health`
- Webview dev tools: Command Palette > "Developer: Open Webview Developer Tools" (not F12)

### Auth Issues
- Desktop: Native Auth0 flow - tokens in encrypted SQLite via `flutter_secure_storage`
- Web: Auth0 bridge uses sessionStorage - check browser DevTools Application tab
- JWT validation fails silently if JWKS endpoint unreachable - check network tab

### Tunnel Debugging
- SSH tunnel uses WebSocket connections - check WebSocket upgrade in network tab
- Tunnel health monitored by `TunnelService` - check connection state in logs
- Connection failures logged with specific error codes

### Backend Debugging
- Winston structured logging with correlation IDs
- Check logs for correlation ID to trace requests across services
- Rate limiting: check `X-RateLimit-*` headers on 429 responses

### Database Debugging
- PostgreSQL: Check connection pool health via `npm run db:stats`
- SQLite (Desktop): Encrypted - cannot read with standard tools
- Drift: Generated queries in `.g.dart` files - check generated code for issues

### Common Silent Failures
- Provider rate limits: Router auto-fallbacks to tier models - check logs for fallback
- WebSocket disconnections: Auto-reconnect with exponential backoff
- Auth token expiry: Silent refresh - check token expiry in logs

## Debug Commands
```bash
# Flutter router health
curl http://localhost:1337/health

# List available models from router
curl http://localhost:1337/v1/models

# Database stats
cd services/api-backend && npm run db:stats
```
