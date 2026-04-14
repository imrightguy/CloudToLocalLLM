/**
 * Authentication Audit Logger
 * Logs all authentication attempts and failures
 * Detects brute force patterns and generates security alerts
 */

import { ConsoleLogger } from '../utils/logger';

interface AuthAttempt {
  userId: string;
  ip: string;
  timestamp: Date;
  success: boolean;
  reason?: string;
  userAgent?: string;
}

interface BruteForcePattern {
  userId?: string;
  ip: string;
  attemptCount: number;
  firstAttempt: Date;
  lastAttempt: Date;
  blocked: boolean;
}

interface SecurityAlert {
  type:
    | 'brute_force'
    | 'suspicious_activity'
    | 'token_theft'
    | 'rate_limit_abuse';
  severity: 'low' | 'medium' | 'high' | 'critical';
  userId?: string;
  ip: string;
  timestamp: Date;
  details: Record<string, any>;
}

/**
 * Authentication Audit Logger
 * Comprehensive logging and monitoring of authentication events
 */
export class AuthAuditLogger {
  private readonly logger = new ConsoleLogger('AuthAuditLogger');
  private readonly attemptHistory: AuthAttempt[] = [];
  private readonly maxHistorySize = 10000;
  private readonly bruteForceThreshold = 5; // Failed attempts
  private readonly bruteForceWindow = 5 * 60 * 1000; // 5 minutes
  private readonly blockedIPs: Set<string> = new Set();
  private readonly blockedUsers: Set<string> = new Set();
  private readonly alertCallbacks: Array<(alert: SecurityAlert) => void> = [];

  /**
   * Log authentication attempt
   */
  logAuthAttempt(
    userId: string,
    ip: string,
    success: boolean,
    reason?: string,
    userAgent?: string
  ): void {
    const attempt: AuthAttempt = {
      userId,
      ip,
      timestamp: new Date(),
      success,
      reason,
      userAgent,
    };

    // Add to history
    this.attemptHistory.push(attempt);

    // Trim history if needed
    if (this.attemptHistory.length > this.maxHistorySize) {
      this.attemptHistory.shift();
    }

    // Log to console (structured logging)
    const logDetails = {
      logType: 'auth_attempt',
      userId,
      ip,
      success,
      reason,
      userAgent,
    };

    if (success) {
      this.logger.info('Authentication attempt successful', logDetails);
    } else {
      this.logger.warn('Authentication attempt failed', logDetails);
    }

    // Check for brute force patterns
    if (!success) {
      this.checkBruteForcePattern(userId, ip);
    }
  }

  /**
   * Log authentication failure with detailed reason
   */
  logAuthFailure(
    userId: string,
    ip: string,
    reason: string,
    details?: Record<string, any>
  ): void {
    const logDetails = {
      logType: 'auth_failure',
      userId,
      ip,
      reason,
      details,
    };

    this.logger.error('Authentication failure', logDetails);

    // Log the attempt
    this.logAuthAttempt(userId, ip, false, reason);
  }

  /**
   * Log successful authentication
   */
  logAuthSuccess(
    userId: string,
    ip: string,
    details?: Record<string, any>
  ): void {
    const logDetails = {
      logType: 'auth_success',
      userId,
      ip,
      details,
    };

    this.logger.info('Authentication success', logDetails);

    // Log the attempt
    this.logAuthAttempt(userId, ip, true);

    // Clear any brute force tracking for this user/IP
    this.clearBruteForceTracking(userId, ip);
  }

  /**
   * Log token validation event
   */
  logTokenValidation(
    userId: string,
    ip: string,
    valid: boolean,
    reason?: string
  ): void {
    const logDetails = {
      logType: 'token_validation',
      userId,
      ip,
      valid,
      reason,
    };

    this.logger.info('Token validation', logDetails);
  }

  /**
   * Log token expiration event
   */
  logTokenExpiration(userId: string, ip: string, expiresAt: Date): void {
    const logDetails = {
      logType: 'token_expiration',
      userId,
      ip,
      expiresAt: expiresAt.toISOString(),
    };

    this.logger.info('Token expiration', logDetails);
  }

  /**
   * Check for brute force attack patterns
   */
  private checkBruteForcePattern(userId: string, ip: string): void {
    const now = Date.now();
    const windowStart = now - this.bruteForceWindow;

    // Get recent failed attempts for this IP
    const recentFailures = this.attemptHistory.filter(
      (attempt) =>
        attempt.ip === ip &&
        !attempt.success &&
        attempt.timestamp.getTime() > windowStart
    );

    // Check if threshold exceeded
    if (recentFailures.length >= this.bruteForceThreshold) {
      this.handleBruteForceDetection(userId, ip, recentFailures);
    }

    // Also check for distributed attacks (same user, different IPs)
    const userFailures = this.attemptHistory.filter(
      (attempt) =>
        attempt.userId === userId &&
        !attempt.success &&
        attempt.timestamp.getTime() > windowStart
    );

    if (userFailures.length >= this.bruteForceThreshold * 2) {
      this.handleDistributedAttack(userId, userFailures);
    }
  }

  /**
   * Handle brute force detection
   */
  private handleBruteForceDetection(
    userId: string,
    ip: string,
    attempts: AuthAttempt[]
  ): void {
    // Block the IP
    this.blockedIPs.add(ip);

    // Generate security alert
    const alert: SecurityAlert = {
      type: 'brute_force',
      severity: 'high',
      userId,
      ip,
      timestamp: new Date(),
      details: {
        attemptCount: attempts.length,
        firstAttempt: attempts[0].timestamp,
        lastAttempt: attempts[attempts.length - 1].timestamp,
        blocked: true,
      },
    };

    this.emitSecurityAlert(alert);

    // Log the detection
    this.logger.error('Brute force attempt detected', {
      logType: 'brute_force_detected',
      userId,
      ip,
      attemptCount: attempts.length,
      action: 'ip_blocked',
    });
  }

  /**
   * Handle distributed attack detection
   */
  private handleDistributedAttack(
    userId: string,
    attempts: AuthAttempt[]
  ): void {
    // Block the user
    this.blockedUsers.add(userId);

    // Get unique IPs
    const uniqueIPs = new Set(attempts.map((a) => a.ip));

    // Generate security alert
    const alert: SecurityAlert = {
      type: 'brute_force',
      severity: 'critical',
      userId,
      ip: Array.from(uniqueIPs).join(', '),
      timestamp: new Date(),
      details: {
        attemptCount: attempts.length,
        uniqueIPs: uniqueIPs.size,
        firstAttempt: attempts[0].timestamp,
        lastAttempt: attempts[attempts.length - 1].timestamp,
        blocked: true,
        distributed: true,
      },
    };

    this.emitSecurityAlert(alert);

    // Log the detection
    this.logger.error('Distributed attack detected', {
      logType: 'distributed_attack_detected',
      userId,
      uniqueIPs: uniqueIPs.size,
      attemptCount: attempts.length,
      action: 'user_blocked',
    });
  }

  /**
   * Clear brute force tracking for user/IP
   */
  private clearBruteForceTracking(userId: string, ip: string): void {
    // Remove from blocked lists on successful auth
    this.blockedIPs.delete(ip);
    this.blockedUsers.delete(userId);
  }

  /**
   * Check if IP is blocked
   */
  isIPBlocked(ip: string): boolean {
    return this.blockedIPs.has(ip);
  }

  /**
   * Check if user is blocked
   */
  isUserBlocked(userId: string): boolean {
    return this.blockedUsers.has(userId);
  }

  /**
   * Unblock IP
   */
  unblockIP(ip: string): void {
    this.blockedIPs.delete(ip);
    this.logger.info('IP unblocked', {
      logType: 'ip_unblocked',
      ip,
    });
  }

  /**
   * Unblock user
   */
  unblockUser(userId: string): void {
    this.blockedUsers.delete(userId);
    this.logger.info('User unblocked', {
      logType: 'user_unblocked',
      userId,
    });
  }

  /**
   * Get authentication statistics
   */
  getAuthStats(timeWindow?: number): {
    totalAttempts: number;
    successfulAttempts: number;
    failedAttempts: number;
    successRate: number;
    uniqueUsers: number;
    uniqueIPs: number;
    blockedIPs: number;
    blockedUsers: number;
  } {
    const now = Date.now();
    const windowStart = timeWindow ? now - timeWindow : 0;

    const relevantAttempts = this.attemptHistory.filter(
      (attempt) => attempt.timestamp.getTime() > windowStart
    );

    const successful = relevantAttempts.filter((a) => a.success).length;
    const failed = relevantAttempts.length - successful;

    const uniqueUsers = new Set(relevantAttempts.map((a) => a.userId)).size;
    const uniqueIPs = new Set(relevantAttempts.map((a) => a.ip)).size;

    return {
      totalAttempts: relevantAttempts.length,
      successfulAttempts: successful,
      failedAttempts: failed,
      successRate:
        relevantAttempts.length > 0 ? successful / relevantAttempts.length : 0,
      uniqueUsers,
      uniqueIPs,
      blockedIPs: this.blockedIPs.size,
      blockedUsers: this.blockedUsers.size,
    };
  }

  /**
   * Get recent failed attempts for user
   */
  getRecentFailures(
    userId: string,
    timeWindow: number = 5 * 60 * 1000
  ): AuthAttempt[] {
    const now = Date.now();
    const windowStart = now - timeWindow;

    return this.attemptHistory.filter(
      (attempt) =>
        attempt.userId === userId &&
        !attempt.success &&
        attempt.timestamp.getTime() > windowStart
    );
  }

  /**
   * Get recent failed attempts for IP
   */
  getRecentFailuresForIP(
    ip: string,
    timeWindow: number = 5 * 60 * 1000
  ): AuthAttempt[] {
    const now = Date.now();
    const windowStart = now - timeWindow;

    return this.attemptHistory.filter(
      (attempt) =>
        attempt.ip === ip &&
        !attempt.success &&
        attempt.timestamp.getTime() > windowStart
    );
  }

  /**
   * Register security alert callback
   */
  onSecurityAlert(callback: (alert: SecurityAlert) => void): void {
    this.alertCallbacks.push(callback);
  }

  /**
   * Emit security alert to all registered callbacks
   */
  private emitSecurityAlert(alert: SecurityAlert): void {
    // Log the alert
    this.logger.error('Security alert', {
      logType: 'security_alert',
      alertType: alert.type,
      severity: alert.severity,
      userId: alert.userId,
      ip: alert.ip,
      details: alert.details,
    });

    // Notify callbacks
    for (const callback of this.alertCallbacks) {
      try {
        callback(alert);
      } catch (error) {
        this.logger.error('Error in security alert callback', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  /**
   * Generate audit report
   */
  generateAuditReport(
    startDate: Date,
    endDate: Date
  ): {
    period: { start: string; end: string };
    stats: {
      totalAttempts: number;
      successfulAttempts: number;
      failedAttempts: number;
      successRate: number;
      uniqueUsers: number;
      uniqueIPs: number;
      blockedIPs: number;
      blockedUsers: number;
    };
    topFailureReasons: Array<{ reason: string; count: number }>;
    suspiciousIPs: Array<{ ip: string; failureCount: number }>;
    suspiciousUsers: Array<{ userId: string; failureCount: number }>;
  } {
    const attempts = this.attemptHistory.filter(
      (attempt) =>
        attempt.timestamp >= startDate && attempt.timestamp <= endDate
    );

    // Calculate stats
    const successful = attempts.filter((a) => a.success).length;
    const failed = attempts.length - successful;

    // Top failure reasons
    const reasonCounts = new Map<string, number>();
    for (const attempt of attempts) {
      if (!attempt.success && attempt.reason) {
        reasonCounts.set(
          attempt.reason,
          (reasonCounts.get(attempt.reason) || 0) + 1
        );
      }
    }

    const topFailureReasons = Array.from(reasonCounts.entries())
      .map(([reason, count]) => ({ reason, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    // Suspicious IPs (high failure rate)
    const ipFailures = new Map<string, number>();
    for (const attempt of attempts) {
      if (!attempt.success) {
        ipFailures.set(attempt.ip, (ipFailures.get(attempt.ip) || 0) + 1);
      }
    }

    const suspiciousIPs = Array.from(ipFailures.entries())
      .map(([ip, failureCount]) => ({ ip, failureCount }))
      .filter((item) => item.failureCount >= 3)
      .sort((a, b) => b.failureCount - a.failureCount)
      .slice(0, 20);

    // Suspicious users (high failure rate)
    const userFailures = new Map<string, number>();
    for (const attempt of attempts) {
      if (!attempt.success) {
        userFailures.set(
          attempt.userId,
          (userFailures.get(attempt.userId) || 0) + 1
        );
      }
    }

    const suspiciousUsers = Array.from(userFailures.entries())
      .map(([userId, failureCount]) => ({ userId, failureCount }))
      .filter((item) => item.failureCount >= 3)
      .sort((a, b) => b.failureCount - a.failureCount)
      .slice(0, 20);

    return {
      period: {
        start: startDate.toISOString(),
        end: endDate.toISOString(),
      },
      stats: {
        totalAttempts: attempts.length,
        successfulAttempts: successful,
        failedAttempts: failed,
        successRate: attempts.length > 0 ? successful / attempts.length : 0,
        uniqueUsers: new Set(attempts.map((a) => a.userId)).size,
        uniqueIPs: new Set(attempts.map((a) => a.ip)).size,
        blockedIPs: this.blockedIPs.size,
        blockedUsers: this.blockedUsers.size,
      },
      topFailureReasons,
      suspiciousIPs,
      suspiciousUsers,
    };
  }
}

/**
 * Express middleware for authentication audit logging
 */
export function createAuthAuditMiddleware(auditLogger: AuthAuditLogger) {
  return (req: any, res: any, next: any) => {
    // Check if IP or user is blocked
    const ip = req.ip || req.connection.remoteAddress;

    if (auditLogger.isIPBlocked(ip)) {
      res.status(403).json({
        error: 'Access denied',
        reason: 'IP address blocked due to suspicious activity',
      });
      return;
    }

    // Extract user ID if available
    const userId = req.userContext?.userId;
    if (userId && auditLogger.isUserBlocked(userId)) {
      res.status(403).json({
        error: 'Access denied',
        reason: 'User account blocked due to suspicious activity',
      });
      return;
    }

    next();
  };
}
