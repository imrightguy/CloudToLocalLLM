#!/usr/bin/env node

/**
 * End-to-End Authentication Flow Testing Script
 * Tests the complete authentication flow from frontend token to backend validation
 */

import fetch from 'node-fetch';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

const SERVICE_URL =
  process.env.SERVICE_URL ||
  'https://cloudtolocalllm-api-123456789-uc.a.run.app';
const TEST_TOKEN = process.env.TEST_TOKEN; // Valid JWT JWT token for testing

async function testAuthFlow() {
  console.log(' CloudToLocalLLM Authentication Flow Testing');
  console.log('==============================================\n');

  console.log(` Testing service: ${SERVICE_URL}`);

  // Test 1: Database Health Check
  console.log('\n Test 1: Database Health Check');
  console.log('--------------------------------');
  try {
    const response = await fetch(`${SERVICE_URL}/api/db/health`);
    const health = await response.json();

    if (response.ok) {
      console.log(' Database health check passed');
      console.log(`   Status: ${health.status}`);
      console.log(`   Database Type: ${health.database_type}`);
      console.log(`   All Tables Valid: ${health.all_tables_valid}`);
    } else {
      console.log(' Database health check failed');
      console.log(`   Status: ${response.status}`);
      console.log(`   Response: ${JSON.stringify(health, null, 2)}`);
    }
  } catch (error) {
    console.log(' Database health check error:', error.message);
  }

  // Test 2: Unauthenticated Request (should fail)
  console.log('\n� Test 2: Unauthenticated Request');
  console.log('----------------------------------');
  try {
    const response = await fetch(`${SERVICE_URL}/ollama/bridge/status`);
    const result = await response.json();

    if (response.status === 401) {
      console.log(' Unauthenticated request properly rejected');
      console.log(`   Status: ${response.status}`);
      console.log(`   Error: ${result.error}`);
    } else {
      console.log(' Unauthenticated request should have been rejected');
      console.log(`   Status: ${response.status}`);
      console.log(`   Response: ${JSON.stringify(result, null, 2)}`);
    }
  } catch (error) {
    console.log(' Unauthenticated request test error:', error.message);
  }

  // Test 3: Authenticated Request (if test token provided)
  if (TEST_TOKEN) {
    console.log('\n Test 3: Authenticated Request');
    console.log('-------------------------------');
    try {
      // Decode token to show info (without verification)
      const decoded = jwt.decode(TEST_TOKEN);
      console.log(
        `   Token User: ${decoded?.email || decoded?.sub || 'Unknown'}`,
      );
      console.log(
        `   Token Expires: ${new Date(decoded?.exp * 1000).toISOString()}`,
      );

      const response = await fetch(`${SERVICE_URL}/ollama/bridge/status`, {
        headers: {
          Authorization: `Bearer ${TEST_TOKEN}`,
          'Content-Type': 'application/json',
        },
      });

      const result = await response.json();

      if (response.ok) {
        console.log(' Authenticated request successful');
        console.log(`   Status: ${response.status}`);
        console.log(`   Bridge Connected: ${result.connected}`);
        console.log(`   Bridge ID: ${result.bridgeId || 'None'}`);
      } else {
        console.log(' Authenticated request failed');
        console.log(`   Status: ${response.status}`);
        console.log(`   Error: ${result.error || 'Unknown error'}`);

        if (response.status === 401) {
          console.log('   � Token may be expired or invalid');
        }
      }
    } catch (error) {
      console.log(' Authenticated request test error:', error.message);
    }
  } else {
    console.log('\n  Test 3: Skipped (no TEST_TOKEN provided)');
    console.log(
      '   To test authenticated requests, set TEST_TOKEN environment variable',
    );
    console.log('   with a valid JWT JWT token');
  }

  // Test 4: CORS Headers
  console.log('\n Test 4: CORS Configuration');
  console.log('-----------------------------');
  try {
    const response = await fetch(`${SERVICE_URL}/api/db/health`, {
      method: 'OPTIONS',
      headers: {
        Origin: 'https://app.cloudtolocalllm.online',
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'Authorization',
      },
    });

    const corsHeaders = {
      'Access-Control-Allow-Origin': response.headers.get(
        'Access-Control-Allow-Origin',
      ),
      'Access-Control-Allow-Methods': response.headers.get(
        'Access-Control-Allow-Methods',
      ),
      'Access-Control-Allow-Headers': response.headers.get(
        'Access-Control-Allow-Headers',
      ),
      'Access-Control-Allow-Credentials': response.headers.get(
        'Access-Control-Allow-Credentials',
      ),
    };

    if (response.ok || response.status === 204) {
      console.log(' CORS preflight successful');
      console.log('   CORS Headers:');
      Object.entries(corsHeaders).forEach(([key, value]) => {
        if (value) {
          console.log(`     ${key}: ${value}`);
        }
      });
    } else {
      console.log(' CORS preflight failed');
      console.log(`   Status: ${response.status}`);
    }
  } catch (error) {
    console.log(' CORS test error:', error.message);
  }

  // Test 5: Rate Limiting
  console.log('\n  Test 5: Rate Limiting');
  console.log('------------------------');
  try {
    console.log('   Making 5 rapid requests to test rate limiting...');
    const promises = Array(5)
      .fill()
      .map((_, i) =>
        fetch(`${SERVICE_URL}/api/db/health`).then((r) => ({
          index: i,
          status: r.status,
        })),
      );

    const results = await Promise.all(promises);
    const successful = results.filter((r) => r.status === 200).length;
    const rateLimited = results.filter((r) => r.status === 429).length;

    console.log(`    ${successful} requests successful`);
    if (rateLimited > 0) {
      console.log(
        `     ${rateLimited} requests rate limited (this is expected behavior)`,
      );
    }
  } catch (error) {
    console.log(' Rate limiting test error:', error.message);
  }

  console.log('\n Test Summary');
  console.log('===============');
  console.log(' Database connectivity tested');
  console.log(' Authentication flow tested');
  console.log(' CORS configuration tested');
  console.log(' Rate limiting tested');

  if (!TEST_TOKEN) {
    console.log('\n� For complete testing, provide a TEST_TOKEN:');
    console.log('   1. Login to your Flutter app');
    console.log('   2. Extract the ID token from localStorage/secure storage');
    console.log('   3. Run: TEST_TOKEN="your-token" npm run test:auth-flow');
  }
}

// Run the tests
testAuthFlow().catch(console.error);
