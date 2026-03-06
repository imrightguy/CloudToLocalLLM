// Ollama proxy functionality stub
// TODO: Implement Ollama proxy for local LLM integration

let sshProxy = null;

export function setSshProxy(proxy) {
  sshProxy = proxy;
}

export async function handleOllamaProxyRequest(req, res) {
  // Stub implementation - returns 501 Not Implemented
  res.status(501).json({
    error: 'Ollama proxy not yet implemented',
    message: 'This feature will be available in a future update'
  });
}
