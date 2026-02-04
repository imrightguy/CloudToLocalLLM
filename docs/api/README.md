# API Documentation

This directory contains comprehensive API documentation for Zoidbot services.

## 📚 Contents

### Core API Documentation

- **[Admin API](ADMIN_API.md)** - Complete administrative API reference and operations
- **[Tunnel Client API](TUNNEL_CLIENT_API.md)** - Client-side tunnel management API
- **[Tunnel Server API](TUNNEL_SERVER_API.md)** - Server-side tunnel management API

### API Policies

- **[Versioning Guide](policies/API_VERSIONING_GUIDE.md)** - API versioning strategy and implementation
- **[Deprecation Guide](policies/API_DEPRECATION_GUIDE.md)** - Policy for deprecating endpoints
- **[Error Codes](policies/API_ERROR_CODES.md)** - Standardized API error codes and handling
- **[Documentation Guide](policies/API_DOCUMENTATION_GUIDE.md)** - Standards for documenting APIs

### System Design

- **[API Tier System](API_TIER_SYSTEM.md)** - User tier system and access controls
- **[Tier Implementation Plan](TIER_IMPLEMENTATION_PLAN.md)** - Implementation strategy for user tiers

## 🔗 Related Documentation

- **[Development API Documentation](../DEVELOPMENT/API_DOCUMENTATION.md)** - Developer-focused API guides
- **[Backend Documentation](../backend/README.md)** - Backend service implementation details
- **[Architecture Documentation](../ARCHITECTURE/README.md)** - System architecture and design

## 📖 Quick Reference

### Authentication

All API endpoints require proper authentication using JWT tokens. See the Admin API documentation for authentication details.

### Rate Limiting

API endpoints are subject to rate limiting based on user tier. See the API Tier System documentation for details.

### Error Handling

All APIs follow consistent error response formats. Check individual API documentation for specific error codes and handling.
