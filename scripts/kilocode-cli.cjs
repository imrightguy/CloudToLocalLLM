#!/usr/bin/env node

/**
 * Kilocode CLI Wrapper
 * 
 * Simplified configuration loading for Kilocode API.
 * Prioritizes kilocode.config.json if available.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const args = process.argv.slice(2);
const prompt = args.filter(arg => !arg.startsWith('-')).join(' ');

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  process.exit(1);
}

// Default values from environment
let apiKey = process.env.KILOCODE_TOKEN;
let apiModel = process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1';
let posthogApiKey = process.env.KILOCODE_POSTHOG_API_KEY;

/**
 * Resolve a config value that may reference an environment variable.
 * Supports ${VAR_NAME} and $VAR_NAME.
 */
function resolveEnvRef(value) {
  if (typeof value !== 'string') return value;

  const trimmed = value.trim();
  const braced = trimmed.match(/^\$\{([A-Z0-9_]+)\}$/);
  if (braced) return process.env[braced[1]];

  const bare = trimmed.match(/^\$([A-Z0-9_]+)$/);
  if (bare) return process.env[bare[1]];

  return value;
}

// Override from kilocode.config.json if present
const configPath = path.join(process.cwd(), 'kilocode.config.json');
if (fs.existsSync(configPath)) {
  try {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    // Simple logic: Take the first provider's config
    if (config.providers && Array.isArray(config.providers) && config.providers.length > 0) {
      const provider = config.providers[0];
      const resolvedToken = resolveEnvRef(provider.kilocodeToken);
      const resolvedModel = resolveEnvRef(provider.kilocodeModel);
      const resolvedPosthog = resolveEnvRef(provider.kilocodePosthogApiKey);

      if (resolvedToken) apiKey = resolvedToken;
      if (resolvedModel) apiModel = resolvedModel;
      if (resolvedPosthog) posthogApiKey = resolvedPosthog;
    }
  } catch (e) {
    console.warn('Warning: Failed to read kilocode.config.json', e.message);
  }
}

if (!apiKey) {
  console.error('Error: KILOCODE_TOKEN not found (env or config).');
  process.exit(1);
}

const apiHostname = process.env.KILOCODE_API_HOST || 'api.kilocode.ai';
const apiPath = process.env.KILOCODE_API_PATH || '/v1/chat/completions';

const data = JSON.stringify({
  model: apiModel,
  messages: [
    {
      role: 'system',
      content: 'You are a CI/CD orchestration assistant. You analyze code changes and decide on version bumps and deployment strategies. Respond ONLY with valid JSON.'
    },
    {
      role: 'user',
      content: prompt
    }
  ],
  temperature: 0.1,
  max_tokens: 2048
});

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${apiKey}`,
  'Content-Length': Buffer.byteLength(data)
};

if (posthogApiKey) {
  headers['x-posthog-api-key'] = posthogApiKey;
}

const options = {
  hostname: apiHostname,
  port: 443,
  path: apiPath,
  method: 'POST',
  headers: headers,
  timeout: 60000
};

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    if (res.statusCode >= 400) {
      console.error(`Kilocode API Error (${res.statusCode}):`, body);
      process.exit(1);
    }
    try {
      const response = JSON.parse(body);
      if (response.choices?.[0]?.message?.content) {
        let text = response.choices[0].message.content;
        text = text.replace(/```json/g, '').replace(/```/g, '').trim();
        console.log(text);
      } else {
        console.error('Unexpected response format:', body);
        process.exit(1);
      }
    } catch (e) {
      console.error('Failed to parse response:', e.message, body);
      process.exit(1);
    }
  });
});

req.on('error', (e) => {
  console.error('Request failed:', e.message);
  process.exit(1);
});

req.on('timeout', () => {
  req.destroy();
  console.error('Request timed out');
  process.exit(1);
});

req.write(data);
req.end();
