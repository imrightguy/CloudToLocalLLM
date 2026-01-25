/**
 * CloudToLocalLLM SDK Client
 *
 * Main client for interacting with the CloudToLocalLLM API
 * Provides methods for authentication, user management, tunnels, and more
 *
 * Requirements: 12.6
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import {
  SDKConfig,
  AuthTokens,
  User,
  Tunnel,
  TunnelCreateRequest,
  TunnelUpdateRequest,
  Webhook,
  WebhookCreateRequest,
  WebhookUpdateRequest,
  HealthStatus,
  PaginationParams,
  PaginatedResponse,
  AdminUser,
  AdminUserUpdateRequest,
  AuditLog,
  APIKey,
  APIKeyCreateRequest,
  ProxyInstance,
  WebhookDelivery,
  UserUpdateRequest,
} from './types';

export class CloudToLocalLLMClient {
  private client: AxiosInstance;
  private config: Required<SDKConfig>;
  private accessToken?: string;
  private refreshToken?: string;

  constructor(config: SDKConfig) {
    this.config = {
      baseURL: config.baseURL,
      apiVersion: config.apiVersion || 'v2',
      timeout: config.timeout || 30000,
      retryAttempts: config.retryAttempts || 3,
      retryDelay: config.retryDelay || 1000,
      headers: config.headers || {},
    };

    this.client = axios.create({
      baseURL: `${this.config.baseURL}/${this.config.apiVersion}`,
      timeout: this.config.timeout,
      headers: {
        'Content-Type': 'application/json',
        ...this.config.headers,
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor
    this.client.interceptors.request.use((config) => {
      if (this.accessToken) {
        config.headers.Authorization = `Bearer ${this.accessToken}`;
      }
      return config;
    });

    // Response interceptor with retry logic
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const config = error.config as any;

        if (!config || !config.retryCount) {
          config.retryCount = 0;
        }

        if (
          error.response?.status === 401 &&
          this.refreshToken &&
          config.retryCount < this.config.retryAttempts
        ) {
          config.retryCount++;
          try {
            await this.refreshAccessToken();
            return this.client(config);
          } catch (refreshError) {
            return Promise.reject(refreshError);
          }
        }

        return Promise.reject(error);
      }
    );
  }

  /**
   * Set authentication tokens
   */
  public setTokens(accessToken: string, refreshToken?: string): void {
    this.accessToken = accessToken;
    if (refreshToken) {
      this.refreshToken = refreshToken;
    }
  }

  /**
   * Clear authentication tokens
   */
  public clearTokens(): void {
    this.accessToken = undefined;
    this.refreshToken = undefined;
  }

  /**
   * Refresh access token using refresh token
   */
  public async refreshAccessToken(): Promise<AuthTokens> {
    if (!this.refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await this.client.post<AuthTokens>('/auth/refresh', {
      refreshToken: this.refreshToken,
    });

    this.setTokens(response.data.accessToken, response.data.refreshToken);
    return response.data;
  }

  // ============ Authentication Endpoints ============

  /**
   * Get current user profile
   */
  public async getCurrentUser(): Promise<User> {
    const response = await this.client.get<User>('/users/me');
    return response.data;
  }

  /**
   * Logout and revoke tokens
   */
  public async logout(): Promise<void> {
    try {
      await this.client.post('/auth/logout');
    } finally {
      this.clearTokens();
    }
  }

  // ============ User Management Endpoints ============

  /**
   * Get user profile by ID
   */
  public async getUser(userId: string): Promise<User> {
    const response = await this.client.get<User>(`/users/${userId}`);
    return response.data;
  }

  /**
   * Update user profile
   */
  public async updateUser(userId: string, data: UserUpdateRequest): Promise<User> {
    const response = await this.client.put<User>(`/users/${userId}`, data);
    return response.data;
  }

  /**
   * Delete user account
   */
  public async deleteUser(userId: string): Promise<void> {
    await this.client.delete(`/users/${userId}`);
  }

  /**
   * Get user tier information
   */
  public async getUserTier(userId: string): Promise<{ tier: string; features: string[] }> {
    const response = await this.client.get(`/users/${userId}/tier`);
    return response.data;
  }

  /**
   * Upgrade user tier
   */
  public async upgradeUserTier(userId: string, tier: string): Promise<User> {
    const response = await this.client.post<User>(`/users/${userId}/tier/upgrade`, { tier });
    return response.data;
  }

  // ============ Tunnel Management Endpoints ============

  /**
   * Create a new tunnel
   */
  public async createTunnel(data: TunnelCreateRequest): Promise<Tunnel> {
    const response = await this.client.post<Tunnel>('/tunnels', data);
    return response.data;
  }

  /**
   * Get tunnel by ID
   */
  public async getTunnel(tunnelId: string): Promise<Tunnel> {
    const response = await this.client.get<Tunnel>(`/tunnels/${tunnelId}`);
    return response.data;
  }

  /**
   * List user's tunnels
   */
  public async listTunnels(params?: PaginationParams): Promise<PaginatedResponse<Tunnel>> {
    const response = await this.client.get<PaginatedResponse<Tunnel>>('/tunnels', { params });
    return response.data;
  }

  /**
   * Update tunnel
   */
  public async updateTunnel(tunnelId: string, data: TunnelUpdateRequest): Promise<Tunnel> {
    const response = await this.client.put<Tunnel>(`/tunnels/${tunnelId}`, data);
    return response.data;
  }

  /**
   * Delete tunnel
   */
  public async deleteTunnel(tunnelId: string): Promise<void> {
    await this.client.delete(`/tunnels/${tunnelId}`);
  }

  /**
   * Start tunnel
   */
  public async startTunnel(tunnelId: string): Promise<Tunnel> {
    const response = await this.client.post<Tunnel>(`/tunnels/${tunnelId}/start`);
    return response.data;
  }

  /**
   * Stop tunnel
   */
  public async stopTunnel(tunnelId: string): Promise<Tunnel> {
    const response = await this.client.post<Tunnel>(`/tunnels/${tunnelId}/stop`);
    return response.data;
  }

  /**
   * Get tunnel status
   */
  public async getTunnelStatus(tunnelId: string): Promise<{ status: string; lastUpdate: string }> {
    const response = await this.client.get(`/tunnels/${tunnelId}/status`);
    return response.data;
  }

  /**
   * Get tunnel metrics
   */
  public async getTunnelMetrics(tunnelId: string): Promise<any> {
    const response = await this.client.get(`/tunnels/${tunnelId}/metrics`);
    return response.data;
  }

  // ============ Webhook Management Endpoints ============

  /**
   * Create webhook
   */
  public async createWebhook(data: WebhookCreateRequest): Promise<Webhook> {
    const response = await this.client.post<Webhook>('/webhooks', data);
    return response.data;
  }

  /**
   * Get webhook by ID
   */
  public async getWebhook(webhookId: string): Promise<Webhook> {
    const response = await this.client.get<Webhook>(`/webhooks/${webhookId}`);
    return response.data;
  }

  /**
   * List webhooks
   */
  public async listWebhooks(params?: PaginationParams): Promise<PaginatedResponse<Webhook>> {
    const response = await this.client.get<PaginatedResponse<Webhook>>('/webhooks', { params });
    return response.data;
  }

  /**
   * Update webhook
   */
  public async updateWebhook(webhookId: string, data: WebhookUpdateRequest): Promise<Webhook> {
    const response = await this.client.put<Webhook>(`/webhooks/${webhookId}`, data);
    return response.data;
  }

  /**
   * Delete webhook
   */
  public async deleteWebhook(webhookId: string): Promise<void> {
    await this.client.delete(`/webhooks/${webhookId}`);
  }

  /**
   * Test webhook delivery
   */
  public async testWebhook(webhookId: string): Promise<WebhookDelivery> {
    const response = await this.client.post<WebhookDelivery>(`/webhooks/${webhookId}/test`);
    return response.data;
  }

  /**
   * Get webhook deliveries
   */
  public async getWebhookDeliveries(
    webhookId: string,
    params?: PaginationParams
  ): Promise<PaginatedResponse<WebhookDelivery>> {
    const response = await this.client.get<PaginatedResponse<WebhookDelivery>>(
      `/webhooks/${webhookId}/deliveries`,
      { params }
    );
    return response.data;
  }

  // ============ Admin Endpoints ============

  /**
   * List all users (admin only)
   */
  public async listUsers(
    params?: PaginationParams & { search?: string }
  ): Promise<PaginatedResponse<AdminUser>> {
    const response = await this.client.get<PaginatedResponse<AdminUser>>('/admin/users', {
      params,
    });
    return response.data;
  }

  /**
   * Get user by ID (admin only)
   */
  public async getAdminUser(userId: string): Promise<AdminUser> {
    const response = await this.client.get<AdminUser>(`/admin/users/${userId}`);
    return response.data;
  }

  /**
   * Update user (admin only)
   */
  public async updateAdminUser(userId: string, data: AdminUserUpdateRequest): Promise<AdminUser> {
    const response = await this.client.put<AdminUser>(`/admin/users/${userId}`, data);
    return response.data;
  }

  /**
   * Delete user (admin only)
   */
  public async deleteAdminUser(userId: string): Promise<void> {
    await this.client.delete(`/admin/users/${userId}`);
  }

  /**
   * Get audit logs (admin only)
   */
  public async getAuditLogs(params?: PaginationParams): Promise<PaginatedResponse<AuditLog>> {
    const response = await this.client.get<PaginatedResponse<AuditLog>>('/admin/audit-logs', {
      params,
    });
    return response.data;
  }

  /**
   * Get system health status (admin only)
   */
  public async getSystemHealth(): Promise<HealthStatus> {
    const response = await this.client.get<HealthStatus>('/admin/health');
    return response.data;
  }

  // ============ API Key Management Endpoints ============

  /**
   * Create API key
   */
  public async createAPIKey(data: APIKeyCreateRequest): Promise<APIKey> {
    const response = await this.client.post<APIKey>('/api-keys', data);
    return response.data;
  }

  /**
   * List API keys
   */
  public async listAPIKeys(): Promise<APIKey[]> {
    const response = await this.client.get<APIKey[]>('/api-keys');
    return response.data;
  }

  /**
   * Revoke API key
   */
  public async revokeAPIKey(keyId: string): Promise<void> {
    await this.client.delete(`/api-keys/${keyId}`);
  }

  // ============ Health Check Endpoints ============

  /**
   * Get API health status
   */
  public async getHealth(): Promise<HealthStatus> {
    const response = await this.client.get<HealthStatus>('/health');
    return response.data;
  }

  /**
   * Get API version information
   */
  public async getVersionInfo(): Promise<any> {
    const response = await this.client.get('/version');
    return response.data;
  }

  // ============ Proxy Management Endpoints ============

  /**
   * Get proxy status
   */
  public async getProxyStatus(): Promise<ProxyInstance> {
    const response = await this.client.get<ProxyInstance>('/proxy/status');
    return response.data;
  }

  /**
   * Start proxy
   */
  public async startProxy(): Promise<ProxyInstance> {
    const response = await this.client.post<ProxyInstance>('/proxy/start');
    return response.data;
  }

  /**
   * Stop proxy
   */
  public async stopProxy(): Promise<void> {
    await this.client.post('/proxy/stop');
  }

  /**
   * Get proxy metrics
   */
  public async getProxyMetrics(): Promise<any> {
    const response = await this.client.get('/proxy/metrics');
    return response.data;
  }

  /**
   * Scale proxy instances
   */
  public async scaleProxy(replicas: number): Promise<ProxyInstance> {
    const response = await this.client.post<ProxyInstance>('/proxy/scale', { replicas });
    return response.data;
  }
}

export default CloudToLocalLLMClient;
