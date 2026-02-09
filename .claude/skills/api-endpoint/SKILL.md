---
name: api-endpoint
description: Generate Express.js API endpoint with Auth0 JWT middleware, Zod validation, and Swagger docs
disable-model-invocation: true
---

Create a new Express.js API endpoint for {{feature}}.

Include:
- Route registration in services/api-backend/routes/
- Auth0 JWT middleware (requireAuth)
- Request validation with Zod schemas
- Winston logging
- Error handling with proper HTTP status codes
- OpenAPI/Swagger documentation comment

Follow existing patterns in services/api-backend/routes/auth.js

Example structure:
```javascript
import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { logger } from '../utils/logger.js';
import { z } from 'zod';

const router = express.Router();

// Request schema
const schema = z.object({
  // fields
});

// POST /api/{{feature}}
router.post('/', requireAuth, async (req, res, next) => {
  try {
    // Validate request
    const validated = schema.parse(req.body);

    // Log request
    logger.info({ userId: req.auth.payload.sub, action: '{{feature}}' }, '{{feature}} request');

    // Business logic

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

export default router;
```
