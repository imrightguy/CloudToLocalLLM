// CloudToLocalLLM - Production Subdomain Configuration
// This file configures the Flutter web app to use production subdomains

window.cloudToLocalLLMConfig = {
  environment: 'production',
  
  // Production subdomain URLs
  services: {
    api: {
      baseUrl: 'https://api.cloudtolocalllm.online',
      endpoints: {
        health: '/health',
        auth: '/api/auth',
        models: '/api/models',
        chat: '/api/chat',
        streaming: '/api/streaming',
        tunnel: '/api/tunnel',
        bridge: '/api/bridge'
      }
    },
    streaming: {
      baseUrl: 'https://streaming.cloudtolocalllm.online',
      endpoints: {
        health: '/health',
        proxy: '/proxy',
        websocket: '/ws'
      }
    }
  },
  
  // CORS configuration
  cors: {
    credentials: 'include',
    mode: 'cors'
  },
  
  // Feature flags
  features: {
    localOllama: false,
    tunneling: true,
    streaming: true,
    auth: true,
    monitoring: true
  },
  
  // API configuration
  api: {
    timeout: 30000,
    retries: 3,
    retryDelay: 1000
  }
};

console.log('CloudToLocalLLM: Production subdomain configuration loaded');
console.log('API URL:', window.cloudToLocalLLMConfig.services.api.baseUrl);
console.log('Streaming URL:', window.cloudToLocalLLMConfig.services.streaming.baseUrl);

// Override the cloudRunConfig if it exists
if (window.cloudRunConfig) {
  window.cloudRunConfig.services.api.baseUrl = 'https://api.cloudtolocalllm.online';
  window.cloudRunConfig.services.streaming.baseUrl = 'https://streaming.cloudtolocalllm.online';
}
