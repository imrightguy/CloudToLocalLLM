// Zoidbot Runtime Configuration
window.cloudToLocalLLMConfig = {
  // API endpoints
  apiEndpoint: 'https://api.zoidbot.online',
  wsEndpoint: 'wss://app.zoidbot.online/ws',

  // TURN server for WebRTC
  turnServer: {
    urls: [
      'turn:174.138.115.184:3478',
      'turn:174.138.115.184:5349'
    ],
    username: 'zoidbot',
    credential: '' // Will be fetched from API after authentication
  },

  // Environment
  environment: 'production',

  // Features
  enableAnalytics: false,
  enableSentry: true,

  // Auth (SuperTokens)
  authDomain: 'https://zoidbot.b2clogin.com',
  appDomain: 'https://app.zoidbot.online'
};

/**
 * Fetch TURN server credentials from API
 * This function should be called after user authentication
 * 
 * @param {string} accessToken - JWT access token for authentication
 * @returns {Promise<void>}
 */
window.loadTurnCredentials = async function (accessToken) {
  try {
    const response = await fetch('https://api.zoidbot.online/turn/credentials', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      console.warn('[TURN Config] Failed to fetch credentials:', response.status);
      return;
    }

    const data = await response.json();
    if (data.status === 'success' && data.turnServer) {
      window.cloudToLocalLLMConfig.turnServer = {
        urls: data.turnServer.urls,
        username: data.turnServer.username,
        credential: data.turnServer.credential,
      };
      console.log('[TURN Config] Credentials loaded successfully');
    }
  } catch (error) {
    console.error('[TURN Config] Error loading credentials:', error);
    // Credentials will remain empty, WebRTC may not work without TURN
  }
};

