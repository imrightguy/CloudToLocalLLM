import { describe, expect, it } from '@jest/globals';

import clientLogsRouter from '../../services/api-backend/routes/client-logs.js';

describe('client logs route bootstrap', () => {
  it('loads the route module without throwing startup-time schema errors', () => {
    expect(clientLogsRouter).toBeDefined();
    expect(typeof clientLogsRouter.use).toBe('function');
  });
});
