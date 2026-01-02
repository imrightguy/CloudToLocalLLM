#!/usr/bin/env node

/**
 * Kilocode CLI Wrapper
 * 
 * Simplified configuration loading for Kilocode API.
 * Prioritizes kilocode.config.json if available.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

const args = process.argv.slice(2);
const configureCi = args.includes('--configure-ci');
const prompt = args.filter(arg => !arg.startsWith('-')).join(' ');

// --configure-ci: Helper to set up CI environment
if (configureCi) {
  const isCI = process.env.CI || process.env.GITHUB_ACTIONS;
  if (!isCI) {
    console.warn('Warning: --configure-ci is intended for CI environments.');
  }

  const token = process.env.KILOCODE_TOKEN;
  const model = process.env.KILOCODE_MODEL || 'x-ai/grok-code-fast-1';
  const posthog = process.env.KILOCODE_POSTHOG_API_KEY;

  if (!token) {
    console.error('Error: KILOCODE_TOKEN environment variable is required for configuration.');
    process.exit(1);
  }

  const configDir = path.join(os.homedir(), '.kilocode');
  const configPath = path.join(configDir, 'config.json');

  try {
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }

    const config = {
      providers: [
        {
          id: "default",
          provider: "kilocode",
          kilocodeToken: token,
          kilocodeModel: model,
          kilocodePosthogApiKey: posthog
        }
      ]
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log(`Successfully configured CI environment at: ${configPath}`);
    process.exit(0);
  } catch (e) {
    console.error('Failed to write CI configuration:', e.message);
    process.exit(1);
  }
}

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  console.error('       kilocode-cli --configure-ci');
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

// Configuration loading logic
const configPaths = [
  path.join(process.cwd(), 'kilocode.config.json'),
  path.join(os.homedir(), '.kilocode', 'config.json')
];

let configLoaded = false;

for (const configPath of configPaths) {
  if (fs.existsSync(configPath)) {
    try {
      if (process.env.CI || process.env.GITHUB_ACTIONS) {
        console.log(`Loading configuration from: ${configPath}`);
      }
      
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
        
        configLoaded = true;
        break; // Stop after finding the first valid config
      }
    } catch (e) {
      console.warn(`Warning: Failed to read config from ${configPath}`, e.message);
    }
  }
}

if (!apiKey) {
  console.error('Error: KILOCODE_TOKEN not found (env or config).');
  process.exit(1);
}

const apiHostname = process.env.KILOCODE_API_HOST || 'api.kilocode.ai';
const apiPath = process.env.KILOCODE_API_PATH || '/v1/chat/completions';
const maxRetries = parseInt(process.env.KILOCODE_MAX_RETRIES) || 3;
const retryDelay = parseInt(process.env.KILOCODE_RETRY_DELAY) || 2000; // 2 seconds

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

function makeRequest(retryCount = 0) {
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
      if (res.statusCode === 404) {
        console.error(`Kilocode API Error (${res.statusCode}): Endpoint not found. Check API path: ${apiPath}`);
        process.exit(1);
      } else if (res.statusCode === 405) {
        console.error(`Kilocode API Error (${res.statusCode}): Method not allowed. API may not support POST on this endpoint.`);
        process.exit(1);
      } else if (res.statusCode >= 400) {
        if (retryCount < maxRetries && (res.statusCode >= 500 || res.statusCode === 429)) {
          console.warn(`API Error (${res.statusCode}), retrying in ${retryDelay}ms... (${retryCount + 1}/${maxRetries})`);
          setTimeout(() => makeRequest(retryCount + 1), retryDelay);
          return;
        }
        console.error(`Kilocode API Error (${res.statusCode}):`, body);
        process.exit(1);
      }
      try {
        const response = JSON.parse(body);
        if (response.choices?.[0]?.message?.content) {
          let text = response.choices[0].message.content;
          text = text.replace(/```json/g, '').replace(/```/g, '').trim();
          console.log(text);
        } else if (response.error) {
          console.error('API Error:', response.error.message || response.error);
          process.exit(1);
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
    if (retryCount < maxRetries) {
      console.warn(`Request failed: ${e.message}, retrying in ${retryDelay}ms... (${retryCount + 1}/${maxRetries})`);
      setTimeout(() => makeRequest(retryCount + 1), retryDelay);
      return;
    }
    console.error('Request failed:', e.message);
    process.exit(1);
  });

  req.on('timeout', () => {
    req.destroy();
    if (retryCount < maxRetries) {
      console.warn(`Request timed out, retrying in ${retryDelay}ms... (${retryCount + 1}/${maxRetries})`);
      setTimeout(() => makeRequest(retryCount + 1), retryDelay);
      return;
    }
    console.error('Request timed out');
    process.exit(1);
  });

  req.write(data);
  req.end();
}

makeRequest();
