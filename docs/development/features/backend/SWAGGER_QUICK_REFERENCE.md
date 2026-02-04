# Swagger/OpenAPI Quick Reference

## Quick Start

### Access Swagger UI

- **Development**: http://localhost:8080/api/docs
- **Production**: https://api.zoidbot.online/api/docs

### Get OpenAPI Specification

- **Development**: http://localhost:8080/api/docs/swagger.json
- **Production**: https://api.zoidbot.online/api/docs/swagger.json

## Installation

```bash
cd services/api-backend
npm install
npm start
```

## Adding JSDoc Comments to Routes

### Basic Template

```javascript
/**
 * @swagger
 * /path/to/endpoint:
 *   method:
 *     summary: Brief description
 *     description: Detailed description
 *     tags:
 *       - Category
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *           example:
 *             field: "value"
 *     responses:
 *       200:
 *         description: Success
 *       400:
 *         $ref: '#/components/schemas/Error'
 */
router.method('/path/to/endpoint', handler);
```

### Common Response References

```javascript
// Unauthorized
401:
  $ref: '#/components/responses/UnauthorizedError'

// Forbidden
403:
  $ref: '#/components/responses/ForbiddenError'

// Not Found
404:
  $ref: '#/components/responses/NotFoundError'

// Rate Limit
429:
  $ref: '#/components/responses/RateLimitError'

// Server Error
500:
  $ref: '#/components/responses/ServerError'
```

### Common Schema References

```javascript
// Error schema
$ref: '#/components/schemas/Error'

// User schema
$ref: '#/components/schemas/User'

// Tunnel schema
$ref: '#/components/schemas/Tunnel'

// Health status schema
$ref: '#/components/schemas/HealthStatus'
```

## Error Code Reference

### Authentication (401)

| Code | Message |
|------|---------|
| INVALID_TOKEN | Invalid token format |
| TOKEN_EXPIRED | Token expired |
| MISSING_TOKEN | Token required |
| AUTH_REQUIRED | Authentication required |

### Validation (400)

| Code | Message |
|------|---------|
| MISSING_PARAMETER | Missing required parameter |
| INVALID_PARAMETER | Invalid parameter value |
| VALIDATION_ERROR | Validation failed |

### Authorization (403)

| Code | Message |
|------|---------|
| INSUFFICIENT_PERMISSIONS | Insufficient permissions |
| ADMIN_REQUIRED | Admin access required |

### Not Found (404)

| Code | Message |
|------|---------|
| NOT_FOUND | Resource not found |
| USER_NOT_FOUND | User not found |
| TUNNEL_NOT_FOUND | Tunnel not found |

### Rate Limit (429)

| Code | Message |
|------|---------|
| RATE_LIMIT_EXCEEDED | Rate limit exceeded |
| QUOTA_EXCEEDED | Quota exceeded |

### Server (500)

| Code | Message |
|------|---------|
| INTERNAL_ERROR | Internal server error |
| DATABASE_ERROR | Database error |

### Service Unavailable (503)

| Code | Message |
|------|---------|
| SERVICE_UNAVAILABLE | Service unavailable |
| DATABASE_UNAVAILABLE | Database unavailable |

## Common Patterns

### GET Endpoint with Authentication

```javascript
/**
 * @swagger
 * /path:
 *   get:
 *     summary: Get resource
 *     tags:
 *       - Category
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 */
router.get('/path', authenticateJWT, handler);
```

### POST Endpoint with Request Body

```javascript
/**
 * @swagger
 * /path:
 *   post:
 *     summary: Create resource
 *     tags:
 *       - Category
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *           example:
 *             name: "Example"
 *     responses:
 *       201:
 *         description: Created
 *       400:
 *         $ref: '#/components/schemas/Error'
 */
router.post('/path', authenticateJWT, handler);
```

### DELETE Endpoint

```javascript
/**
 * @swagger
 * /path/{id}:
 *   delete:
 *     summary: Delete resource
 *     tags:
 *       - Category
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       204:
 *         description: Deleted
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 */
router.delete('/path/:id', authenticateJWT, handler);
```

## Documentation Files

| File | Purpose |
|------|---------|
| `swagger-config.js` | OpenAPI configuration |
| `API_ERROR_CODES.md` | Error code reference |
| `API_DOCUMENTATION_GUIDE.md` | User guide |
| `SWAGGER_IMPLEMENTATION_SUMMARY.md` | Implementation details |
| `SWAGGER_QUICK_REFERENCE.md` | This file |

## Validation Checklist

- [ ] All endpoints have JSDoc comments
- [ ] All endpoints have request/response examples
- [ ] All error codes are documented
- [ ] Security requirements are specified
- [ ] Parameter descriptions are clear
- [ ] Response schemas are defined
- [ ] Swagger UI displays correctly
- [ ] OpenAPI JSON is valid

## Troubleshooting

### Swagger UI Not Loading

1. Check if server is running: `npm start`
2. Verify port is correct (default: 8080)
3. Check browser console for errors
4. Verify swagger-ui-express is installed: `npm list swagger-ui-express`

### JSDoc Comments Not Appearing

1. Verify JSDoc syntax is correct
2. Check file is listed in `swagger-config.js` apis array
3. Restart server after changes
4. Clear browser cache

### Invalid OpenAPI Specification

1. Validate JSON at https://editor.swagger.io
2. Check schema definitions
3. Verify response codes are valid
4. Check parameter types

## Resources

- [OpenAPI 3.0 Spec](https://spec.openapis.org/oas/v3.0.3)
- [Swagger UI Docs](https://swagger.io/tools/swagger-ui/)
- [swagger-jsdoc Docs](https://github.com/Surnet/swagger-jsdoc)
- [JSON Schema](https://json-schema.org/)

## Support

For questions or issues:

- Check `API_DOCUMENTATION_GUIDE.md`
- Review `API_ERROR_CODES.md`
- See `SWAGGER_IMPLEMENTATION_SUMMARY.md`
- Contact: support@zoidbot.online
