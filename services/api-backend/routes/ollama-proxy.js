import logger from '../logger.js';

let sshProxy;

export function setSshProxy(proxy) {
  sshProxy = proxy;
}

export const handleOllamaProxyRequest = async (req, res) => {
  const startTime = Date.now();
  const requestId = `llm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  // Use req.userId which is normalized across JWT and API Key auth
  const userId = req.userId || req.auth?.payload.sub;

  if (!userId) {
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTH_REQUIRED',
      message: 'Please authenticate to access LLM services.',
    });
  }

  try {
    const basePath = req.path.startsWith('/ollama') ? '/ollama' : '/api/ollama';
    let ollamaPath = req.path.substring(basePath.length);
    if (!ollamaPath || ollamaPath.length === 0) {
      ollamaPath = '/';
    } else if (!ollamaPath.startsWith('/')) {
      ollamaPath = `/${ollamaPath}`;
    }
    const forwardHeaders = { ...req.headers };
    [
      'host',
      'authorization',
      'connection',
      'upgrade',
      'proxy-authenticate',
      'proxy-authorization',
      'te',
      'trailers',
      'transfer-encoding',
    ].forEach((h) => delete forwardHeaders[h]);

    const httpRequest = {
      id: requestId,
      method: req.method,
      path: ollamaPath,
      headers: forwardHeaders,
      body:
        req.method !== 'GET' && req.method !== 'HEAD'
          ? JSON.stringify(req.body)
          : undefined,
    };

    logger.debug(' [LLMTunnel] Forwarding request through tunnel', {
      userId,
      requestId,
      path: ollamaPath,
    });

    if (ollamaPath === '/bridge/status') {
      const isConnected = sshProxy && sshProxy.isUserConnected(userId);
      return res.json({
        status: isConnected ? 'connected' : 'disconnected',
        message: isConnected ? 'Bridge is connected' : 'Bridge is disconnected',
      });
    }

    if (!sshProxy) {
      return res.status(503).json({
        error: 'Tunnel system not available',
        code: 'TUNNEL_NOT_AVAILABLE',
        message: 'SSH tunnel server not initialized',
      });
    }

    const response = await sshProxy.forwardRequest(userId, httpRequest);

    const duration = Date.now() - startTime;
    logger.info(' [LLMTunnel] Request completed successfully via tunnel', {
      userId,
      requestId,
      duration,
      status: response.status,
    });

    if (response.headers) {
      Object.entries(response.headers).forEach(([key, value]) => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, value);
        }
      });
    }

    res.status(response.status || 200);
    if (response.body) {
      try {
        res.json(JSON.parse(response.body));
      } catch {
        res.send(response.body);
      }
    } else {
      res.end();
    }
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error(' [LLMTunnel] Request failed via tunnel', {
      userId,
      requestId,
      duration,
      error: error.message,
      code: error.code,
    });

    if (error.code === 'REQUEST_TIMEOUT') {
      return res
        .status(504)
        .json({ error: 'LLM request timeout', code: 'LLM_REQUEST_TIMEOUT' });
    }
    if (error.code === 'DESKTOP_CLIENT_DISCONNECTED') {
      return res.status(503).json({
        error: 'Desktop client not connected',
        code: 'DESKTOP_CLIENT_DISCONNECTED',
      });
    }
    res
      .status(500)
      .json({ error: 'LLM tunnel error', code: 'LLM_TUNNEL_ERROR' });
  }
};
