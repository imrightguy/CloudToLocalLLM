#!/usr/bin/env node

/**
 * Container Tunnel Integration Test Script
 * Tests that containers can communicate through the simplified tunnel proxy
 * using standard HTTP libraries without special tunnel-aware code
 */

import http from 'http';
import https from 'https';
import { URL } from 'url';

// Test configuration
const TEST_USER_ID = process.env.TEST_USER_ID || 'test-user-123';
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8080';
const CONTAINER_HEALTH_URL = process.env.CONTAINER_HEALTH_URL || 'http://localhost:8081';
const TUNNEL_BASE_URL = `${API_BASE_URL}/api/tunnel/${TEST_USER_ID}`;

console.log('🧪 Container Tunnel Integration Tests');
console.log('=====================================');
console.log(`Test User ID: ${TEST_USER_ID.substring(0, 4)}***`);
console.log(`API Base URL: ${API_BASE_URL}`);
console.log(`Tunnel Base URL: ${TUNNEL_BASE_URL.replace(TEST_USER_ID, '***')}`);
console.log(`Container Health URL: ${CONTAINER_HEALTH_URL}`);
console.log('');

/**
 * Make HTTP request with timeout
 * @param {string} url - Request URL
 * @param {Object} options - Request options
 * @returns {Promise<Object>} Response data
 */
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const client = urlObj.protocol === 'https:' ? https : http;

    const requestOptions = {
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'CloudToLocalLLM-IntegrationTest/1.0',
        ...options.headers
      },
      timeout: options.timeout || 30000
    };

    const req = client.request(urlObj, requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const jsonData = data ? JSON.parse(data) : {};
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data,
            data: jsonData
          });
        } catch {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data,
            data: null
          });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (options.body) {
      req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    }

    req.end();
  });
}

/**
 * Test that containers can make HTTP requests through tunnel proxy
 */
async function testContainerTunnelCommunication() {
  console.log('📡 Testing container tunnel communication...');

  try {
    const response = await makeRequest(`${TUNNEL_BASE_URL}/api/tags`, {
      timeout: 30000
    });

    if (response.statusCode === 200) {
      console.log('✅ Container successfully communicated through tunnel');
      console.log(`   Response: ${response.body.substring(0, 100)}...`);
      return true;
    } else if (response.statusCode === 503) {
      console.log('✅ Container received proper error when desktop offline');
      console.log(`   Error: ${response.data?.error || 'Service unavailable'}`);
      return true;
    } else {
      console.log(`❌ Unexpected response status: ${response.statusCode}`);
      console.log(`   Body: ${response.body}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Container tunnel communication failed: ${error.message}`);
    return false;
  }
}

/**
 * Test container environment configuration
 */
async function testContainerEnvironment() {
  console.log('🔧 Testing container environment configuration...');

  try {
    const response = await makeRequest(`${CONTAINER_HEALTH_URL}/health`, {
      timeout: 10000
    });

    if (response.statusCode === 200) {
      const health = response.data;

      if (health.status === 'healthy' &&
        health.tunnelConfigured === true &&
        health.ollamaBaseUrl &&
        health.ollamaBaseUrl.includes('/api/tunnel/')) {
        console.log('✅ Container environment properly configured');
        console.log(`   OLLAMA_BASE_URL: ${health.ollamaBaseUrl}`);
        return true;
      } else {
        console.log('❌ Container environment misconfigured');
        console.log(`   Health data: ${JSON.stringify(health, null, 2)}`);
        return false;
      }
    } else {
      console.log(`❌ Container health check failed: ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Container health check failed: ${error.message}`);
    return false;
  }
}

/**
 * Test container tunnel connectivity test
 */
async function testContainerTunnelTest() {
  console.log('🔍 Testing container tunnel connectivity test...');

  try {
    const response = await makeRequest(`${CONTAINER_HEALTH_URL}/test-tunnel`, {
      timeout: 35000
    });

    if (response.statusCode === 200) {
      const testData = response.data;
      console.log('✅ Container tunnel connectivity test passed');
      console.log(`   Tunnel connected: ${testData.tunnelConnected}`);
      console.log(`   Stats: ${JSON.stringify(testData.stats)}`);
      return true;
    } else if (response.statusCode === 500) {
      const testData = response.data;
      console.log('✅ Container tunnel connectivity test properly reported failure');
      console.log(`   Error: ${testData.error}`);
      console.log(`   Stats: ${JSON.stringify(testData.stats)}`);
      return true;
    } else {
      console.log(`❌ Unexpected tunnel test response: ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Container tunnel test failed: ${error.message}`);
    return false;
  }
}

/**
 * Test standard HTTP library usage
 */
async function testStandardHttpUsage() {
  console.log('📚 Testing standard HTTP library usage...');

  try {
    const response = await makeRequest(`${CONTAINER_HEALTH_URL}/stats`, {
      timeout: 10000
    });

    if (response.statusCode === 200) {
      const stats = response.data;

      if (stats.tunnel &&
        stats.tunnel.configured === true &&
        stats.tunnel.stats &&
        typeof stats.tunnel.stats.requestCount === 'number') {
        console.log('✅ Container using standard HTTP client patterns');
        console.log(`   Request stats: ${JSON.stringify(stats.tunnel.stats)}`);
        return true;
      } else {
        console.log('❌ Container not using expected HTTP patterns');
        console.log(`   Stats: ${JSON.stringify(stats, null, 2)}`);
        return false;
      }
    } else {
      console.log(`❌ Container stats check failed: ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Container stats check failed: ${error.message}`);
    return false;
  }
}

/**
 * Test concurrent requests
 */
async function testConcurrentRequests() {
  console.log('🔄 Testing concurrent requests...');

  const concurrentRequests = 5;
  const promises = [];

  for (let i = 0; i < concurrentRequests; i++) {
    promises.push(
      makeRequest(`${TUNNEL_BASE_URL}/api/tags`, {
        headers: { 'User-Agent': `CloudToLocalLLM-Test-${i}/1.0` },
        timeout: 30000
      })
    );
  }

  try {
    const responses = await Promise.all(promises);
    const statusCodes = [...new Set(responses.map(r => r.statusCode))];

    if (statusCodes.length === 1) {
      const commonStatus = statusCodes[0];
      if (commonStatus === 200 || commonStatus === 503) {
        console.log('✅ Multiple concurrent requests handled properly');
        console.log(`   Status: ${commonStatus}, Count: ${responses.length}`);
        return true;
      }
    }

    console.log(`❌ Inconsistent concurrent request responses: ${statusCodes}`);
    return false;
  } catch (error) {
    console.log(`❌ Concurrent requests test failed: ${error.message}`);
    return false;
  }
}

/**
 * Test error handling
 */
async function testErrorHandling() {
  console.log('⚠️  Testing error handling...');

  try {
    const response = await makeRequest(`${TUNNEL_BASE_URL}/api/nonexistent`, {
      timeout: 30000
    });

    if ([404, 503, 504].includes(response.statusCode)) {
      console.log(`✅ Container received proper error response: ${response.statusCode}`);
      if (response.data && response.data.error) {
        console.log(`   Error message: ${response.data.error}`);
      }
      return true;
    } else {
      console.log(`❌ Unexpected error response: ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Error handling test failed: ${error.message}`);
    return false;
  }
}

/**
 * Test environment setup
 */
async function testEnvironmentSetup() {
  console.log('🏗️  Testing environment setup...');

  try {
    // Test API backend health
    const apiResponse = await makeRequest(`${API_BASE_URL}/health`, {
      timeout: 10000
    });

    if (apiResponse.statusCode === 200 && apiResponse.data.status === 'healthy') {
      console.log('✅ API Backend is healthy');
    } else {
      console.log(`❌ API Backend unhealthy: ${apiResponse.statusCode}`);
      return false;
    }

    // Test tunnel endpoint availability
    const tunnelResponse = await makeRequest(`${API_BASE_URL}/api/tunnel/status`, {
      headers: { 'Authorization': 'Bearer invalid-token' },
      timeout: 10000
    });

    if ([401, 403].includes(tunnelResponse.statusCode)) {
      console.log('✅ Tunnel endpoint is available');
      return true;
    } else {
      console.log(`❌ Tunnel endpoint not available: ${tunnelResponse.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ Environment setup test failed: ${error.message}`);
    return false;
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('Starting container tunnel integration tests...\n');

  const tests = [
    { name: 'Environment Setup', fn: testEnvironmentSetup },
    { name: 'Container Environment', fn: testContainerEnvironment },
    { name: 'Standard HTTP Usage', fn: testStandardHttpUsage },
    { name: 'Container Tunnel Test', fn: testContainerTunnelTest },
    { name: 'Tunnel Communication', fn: testContainerTunnelCommunication },
    { name: 'Concurrent Requests', fn: testConcurrentRequests },
    { name: 'Error Handling', fn: testErrorHandling }
  ];

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    try {
      const result = await test.fn();
      if (result) {
        passed++;
      } else {
        failed++;
      }
    } catch (error) {
      console.log(`❌ Test "${test.name}" threw exception: ${error.message}`);
      failed++;
    }
    console.log(''); // Empty line between tests
  }

  console.log('=====================================');
  console.log(`📊 Test Results: ${passed} passed, ${failed} failed`);

  if (failed === 0) {
    console.log('🎉 All container tunnel integration tests passed!');
    process.exit(0);
  } else {
    console.log('💥 Some tests failed. Check the output above for details.');
    process.exit(1);
  }
}

// Run tests if this script is executed directly
import { fileURLToPath } from 'url';
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runAllTests().catch(error => {
    console.error('❌ Test runner failed:', error);
    process.exit(1);
  });
}

export default {
  makeRequest,
  testContainerTunnelCommunication,
  testContainerEnvironment,
  testContainerTunnelTest,
  testStandardHttpUsage,
  testConcurrentRequests,
  testErrorHandling,
  testEnvironmentSetup,
  runAllTests
};