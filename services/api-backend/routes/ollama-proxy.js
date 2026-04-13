// Ollama proxy for local LLM integration
// Proxies requests to the local Ollama instance running on localhost:11434

import axios from 'axios';
import logger from '../logger.js';

// eslint-disable-next-line no-unused-vars
let _sshProxy = null;

/**
 * Set the SSH proxy (if needed for tunneling)
 * @param {Object} proxy - Proxy configuration
 */
export function setSshProxy(proxy) {
  _sshProxy = proxy;
}

/**
 * Handle Ollama proxy requests
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
export async function handleOllamaProxyRequest(req, res) {
  try {
    // Construct the target URL for Ollama API
    const ollamaBaseUrl = 'http://localhost:11434';
    const targetUrl = `${ollamaBaseUrl}${req.path}`;

    // Prepare the request configuration
    const config = {
      method: req.method,
      url: targetUrl,
      headers: { ...req.headers },
      data: req.body,
      // Remove host header as it will be set by axios
      // Remove content-length as it will be recalculated
    };

    // Delete headers that axios should handle
    delete config.headers.host;
    delete config.headers['content-length'];

    // Make the request to Ollama
    const ollamaResponse = await axios(config);

    // Forward the response from Ollama
    res.status(ollamaResponse.status);

    // Copy headers from Ollama response (except some that Express should handle)
    const excludedHeaders = [
      'content-length',
      'connection',
      'transfer-encoding',
    ];
    for (const [key, value] of Object.entries(ollamaResponse.headers)) {
      if (!excludedHeaders.includes(key.toLowerCase())) {
        res.setHeader(key, value);
      }
    }

    // Send the response body
    res.send(ollamaResponse.data);
  } catch (error) {
    logger.error('Ollama proxy error:', error.message);

    // Handle different types of errors
    let statusCode = 502; // Bad Gateway
    let errorMessage = 'Failed to proxy request to Ollama';

    if (error.code === 'ECONNREFUSED') {
      statusCode = 503; // Service Unavailable
      errorMessage =
        'Ollama service is not available. Please ensure Ollama is running on localhost:11434';
    } else if (error.response) {
      // Ollama returned an error
      statusCode = error.response.status || 502;
      errorMessage =
        error.response.data?.error ||
        error.response.statusText ||
        'Ollama returned an error';
    }

    res.status(statusCode).json({
      error: 'Ollama proxy error',
      message: errorMessage,
      details:
        process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
}
