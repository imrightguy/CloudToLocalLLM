#!/usr/bin/env node

/**
 * Kilocode CLI Wrapper
 * 
 * This script provides a simple interface for AI-powered CI/CD analysis 
 * using the Kilocode API. It supports configuration via kilocode.config.json
 * and environment variables.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const args = process.argv.slice(2);
const prompt = args.filter(arg => !arg.startsWith('-')).join(' ');

// 1. Load Configuration from kilocode.config.json if available
let configToken = null;
let configModel = null;
let configPosthogKey = null;

const configPath = path.join(process.cwd(), 'kilocode.config.json');
if (fs.existsSync(configPath)) {
  try {
    const rawConfig = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(rawConfig);
    
    // Look for the default or kilocode provider
    if (config.providers && Array.isArray(config.providers)) {
      const provider = config.providers.find(p => p.provider === 'kilocode') || 
                       config.providers.find(p => p.id === 'default');
      
      if (provider) {
        configToken = provider.kilocodeToken;
        configModel = provider.kilocodeModel;
        configPosthogKey = provider.kilocodePosthogApiKey;
        // console.log('Loaded configuration from kilocode.config.json');
      }
    }
  } catch (err) {
    console.warn('Warning: Failed to parse kilocode.config.json:', err.message);
  }
}

// 2. Resolve final configuration (Env vars override config file if set explicitly, 
//    but in this workflow context, the config file usually contains the secrets)
const apiKey = process.env.KILOCODE_TOKEN || configToken;
const apiHostname = process.env.KILOCODE_API_HOST || 'api.kilocode.ai';
const apiModel = process.env.KILOCODE_MODEL || configModel || 'x-ai/grok-code-fast-1';
const posthogApiKey = process.env.KILOCODE_POSTHOG_API_KEY || configPosthogKey;

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  process.exit(1);
}

if (!apiKey) {
  console.error('Error: KILOCODE_TOKEN not found in environment or kilocode.config.json');
  process.exit(1);
}

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

// Add PostHog Key if available (may be required for some endpoints/tracking)
if (posthogApiKey) {
  headers['x-posthog-api-key'] = posthogApiKey;
}

const options = {
  hostname: apiHostname,
  port: 443,
  path: '/v1/chat/completions',
  method: 'POST',
  headers: headers,
  timeout: 60000 // 60 seconds timeout
};

const makeRequest = () => {
  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => {
      body += chunk;
    });

    res.on('end', () => {
      if (res.statusCode >= 400) {
        console.error(`Kilocode API Error (${res.statusCode}):`, body);
        // If 405, it might be the wrong endpoint or method. 
        // We log it clearly for debugging.
        process.exit(1);
      }

      try {
        const response = JSON.parse(body);
        if (response.choices && response.choices[0] && response.choices[0].message) {
          let text = response.choices[0].message.content;
          // Clean markdown code blocks if present
          text = text.replace(/```json/g, '').replace(/```/g, '').trim();
          console.log(text);
        } else {
          console.error('Unexpected response format:', body);
          process.exit(1);
        }
      } catch (e) {
        console.error('Failed to parse response:', e.message);
        console.error('Body:', body);
        process.exit(1);
      }
    });
  });

  req.on('error', (e) => {
    console.error('Request failed:', e.message);
    process.exit(1);
  });

  req.on('timeout', () => {
    console.error('Request timed out after 60 seconds');
    req.destroy();
    process.exit(1);
  });

  req.write(data);
  req.end();
};

makeRequest();
