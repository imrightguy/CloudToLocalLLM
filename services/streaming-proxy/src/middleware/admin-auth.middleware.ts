import { Request, Response, NextFunction } from 'express';
import { JWTValidationMiddleware } from './jwt-validation-middleware';
import { AuthAuditLogger } from './auth-audit-logger';
import { ConsoleLogger } from '../utils/logger';
import { HTTP_STATUS } from '../utils/http-constants';

const logger = new ConsoleLogger('AdminAuthMiddleware');

export interface AdminAuthConfig {
  authMiddleware: JWTValidationMiddleware;
  authAuditLogger: AuthAuditLogger;
}

export function createAdminAuthMiddleware(config: AdminAuthConfig) {
  const { authMiddleware, authAuditLogger } = config;

  return async function requireAdminAuth(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const token = extractBearerToken(req);
      if (!token) {
        sendUnauthorized(res, 'Missing or invalid authorization header');
        return;
      }

      const validation = await authMiddleware.validateToken(token);
      if (!validation.valid || !validation.userId) {
        sendUnauthorized(res, validation.error || 'Invalid token');
        return;
      }

      const userContext = await authMiddleware.getUserContext(token);
      if (!hasAdminPermission(userContext.permissions)) {
        logDeniedAccess(userContext.userId, userContext.permissions);
        sendForbidden(res, 'Admin permissions required to access diagnostics');
        return;
      }

      logSuccessfulAccess(userContext.userId, userContext.permissions, req);
      (req as any).user = userContext;
      next();
    } catch (error) {
      handleAuthError(res, error);
    }
  };
}

function extractBearerToken(req: Request): string | null {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.substring(7);
}

function hasAdminPermission(permissions: string[]): boolean {
  return permissions.some(
    (perm) =>
      perm === 'view_system_metrics' ||
      perm === 'admin' ||
      perm === '*' ||
      perm.includes('admin')
  );
}

function sendUnauthorized(res: Response, message: string): void {
  res.status(HTTP_STATUS.UNAUTHORIZED).json({
    error: 'Unauthorized',
    message,
    timestamp: new Date().toISOString(),
  });
}

function sendForbidden(res: Response, message: string): void {
  res.status(HTTP_STATUS.FORBIDDEN).json({
    error: 'Forbidden',
    message,
    timestamp: new Date().toISOString(),
  });
}

function logDeniedAccess(userId: string, permissions: string[]): void {
  logger.warn('Diagnostics access denied', {
    userId,
    permissions,
  });
}

function logSuccessfulAccess(
  userId: string,
  permissions: string[],
  req: Request
): void {
  const clientIp = req.ip || req.socket.remoteAddress || 'unknown';
  new AuthAuditLogger().logAuthSuccess(userId, clientIp, {
    endpoint: '/api/tunnel/diagnostics',
    method: 'GET',
    permissions,
  });
}

function handleAuthError(res: Response, error: unknown): void {
  const errorMessage = error instanceof Error ? error.message : String(error);
  logger.error('Admin auth check failed', { error: errorMessage });
  res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
    error: 'Internal server error',
    message: 'Failed to verify admin permissions',
    timestamp: new Date().toISOString(),
  });
}
