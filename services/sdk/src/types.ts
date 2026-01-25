/**
 * CloudToLocalLLM SDK Type Definitions
 *
 * Comprehensive type definitions for all API endpoints and data models
 * Generated from OpenAPI specification
 */

// Authentication Types
export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
}

export interface AuthResponse {
  tokens: AuthTokens;
  user: User;
}

// User Types
export interface User {
  id: string;
  email: string;
  tier: 'free' | 'premium' | 'enterprise';
  profile: UserProfile;
  createdAt: string;
  updatedAt: string;
  lastLoginAt?: string;
  isActive: boolean;
}

export interface UserProfile {
  firstName: string;
  lastName: string;
  avatar?: string;
  preferences: UserPreferences;
}

export interface UserPreferences {
  theme: 'light' | 'dark';
  language: string;
  notifications: boolean;
}

export interface UserUpdateRequest {
  profile?: Partial<UserProfile>;
  preferences?: Partial<UserPreferences>;
}

// Tunnel Types
export interface Tunnel {
  id: string;
  userId: string;
  name: string;
  status: 'created' | 'connecting' | 'connected' | 'disconnected' | 'error';
  endpoints: TunnelEndpoint[];
  config: TunnelConfig;
  metrics: TunnelMetrics;
  createdAt: string;
  updatedAt: string;
}

export interface TunnelEndpoint {
  id: string;
  url: string;
  priority: number;
  weight: number;
  healthStatus: 'healthy' | 'unhealthy' | 'unknown';
  lastHealthCheck: string;
}

export interface TunnelConfig {
  maxConnections: number;
  timeout: number;
  compression: boolean;
}

export interface TunnelMetrics {
  requestCount: number;
  successCount: number;
  errorCount: number;
  averageLatency: number;
}

export interface TunnelCreateRequest {
  name: string;
  endpoints: Omit<TunnelEndpoint, 'id' | 'healthStatus' | 'lastHealthCheck'>[];
  config?: Partial<TunnelConfig>;
}

export interface TunnelUpdateRequest {
  name?: string;
  endpoints?: Omit<TunnelEndpoint, 'id' | 'healthStatus' | 'lastHealthCheck'>[];
  config?: Partial<TunnelConfig>;
}

// Proxy Types
export interface ProxyInstance {
  id: string;
  status: 'running' | 'stopped' | 'error';
  replicas: number;
  metrics: ProxyMetrics;
  createdAt: string;
  updatedAt: string;
}

export interface ProxyMetrics {
  activeConnections: number;
  totalRequests: number;
  successRate: number;
  averageLatency: number;
  memoryUsage: number;
  cpuUsage: number;
}

export interface ProxyConfig {
  maxConnections: number;
  timeout: number;
  compression: boolean;
}

// Webhook Types
export interface Webhook {
  id: string;
  userId: string;
  url: string;
  events: string[];
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface WebhookCreateRequest {
  url: string;
  events: string[];
  active?: boolean;
}

export interface WebhookUpdateRequest {
  url?: string;
  events?: string[];
  active?: boolean;
}

export interface WebhookDelivery {
  id: string;
  webhookId: string;
  event: string;
  payload: Record<string, any>;
  status: 'pending' | 'delivered' | 'failed';
  attempts: number;
  lastAttemptAt?: string;
  nextRetryAt?: string;
}

// Admin Types
export interface AdminUser {
  id: string;
  email: string;
  tier: 'free' | 'premium' | 'enterprise';
  role: 'user' | 'admin' | 'superadmin';
  createdAt: string;
  updatedAt: string;
  lastLoginAt?: string;
}

export interface AdminUserUpdateRequest {
  tier?: 'free' | 'premium' | 'enterprise';
  role?: 'user' | 'admin' | 'superadmin';
}

export interface AuditLog {
  id: string;
  userId: string;
  action: string;
  resource: string;
  resourceId: string;
  result: 'success' | 'failure';
  details: Record<string, any>;
  ipAddress: string;
  userAgent: string;
  timestamp: string;
}

// Health Check Types
export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'error';
  database: 'healthy' | 'degraded' | 'error';
  cache: 'healthy' | 'degraded' | 'error';
  timestamp: string;
}

// Error Types
export interface APIError {
  error: {
    code: string;
    message: string;
    category:
      | 'validation'
      | 'authentication'
      | 'authorization'
      | 'not_found'
      | 'rate_limit'
      | 'server'
      | 'service_unavailable';
    statusCode: number;
    correlationId: string;
    suggestion?: string;
  };
}

// Pagination Types
export interface PaginationParams {
  page?: number;
  limit?: number;
  sort?: string;
  order?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    pages: number;
  };
}

// Rate Limit Types
export interface RateLimitInfo {
  limit: number;
  remaining: number;
  reset: number;
}

// Session Types
export interface Session {
  id: string;
  userId: string;
  token: string;
  refreshToken: string;
  expiresAt: string;
  createdAt: string;
  ipAddress: string;
  userAgent: string;
  isActive: boolean;
}

// API Key Types
export interface APIKey {
  id: string;
  userId: string;
  name: string;
  key: string;
  lastUsedAt?: string;
  createdAt: string;
  expiresAt?: string;
}

export interface APIKeyCreateRequest {
  name: string;
  expiresAt?: string;
}

// SDK Configuration
export interface SDKConfig {
  baseURL: string;
  apiVersion?: 'v1' | 'v2';
  timeout?: number;
  retryAttempts?: number;
  retryDelay?: number;
  headers?: Record<string, string>;
}

// Request/Response Interceptor Types
export interface RequestInterceptor {
  (config: any): any;
}

export interface ResponseInterceptor {
  (response: any): any;
}

export interface ErrorInterceptor {
  (error: any): any;
}
