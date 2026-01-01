#!/usr/bin/env node

/**
 * Kilocode CLI Wrapper
 * 
 * This script replaces gemini-cli.cjs and provides a simple interface for
 * AI-powered CI/CD analysis using the Kilocode API and grok-code-fast-1 model.
 */

const https = require('https');

const args = process.argv.slice(2);
const prompt = args.filter(arg => !arg.startsWith('-')).join(' ');
const apiKey = process.env.OPENAI_API_KEY;

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  process.exit(1);
}

if (!apiKey) {
  console.error('Error: OPENAI_API_KEY environment variable is not set.');
  process.exit(1);
}

const data = JSON.stringify({
  model: 'gpt-4',
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
  max_tokens: 1024
});

const options = {
  hostname: 'api.openai.com',
  port: 443,
  path: '/v1/chat/completions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${apiKey}`,
    'Content-Length': data.length
  },
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
