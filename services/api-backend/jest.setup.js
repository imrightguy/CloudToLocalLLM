// Jest global setup for API backend tests
// - Mocks external dependencies (network)
// - Sets up JUnit reporter output directory if needed

// Disable real network calls by default (best-effort; only if nock is available)
// Note: uses require() intentionally — Jest provides CJS require in setup context
let nock;
try {
  nock = require('nock');
} catch {
  // nock not installed; skip network stubbing
}

if (nock) {
  beforeAll(() => {
    nock.disableNetConnect();
    // Allow localhost if needed for tests
    nock.enableNetConnect(
      (host) => host.includes('127.0.0.1') || host.includes('localhost'),
    );
  });

  afterAll(() => {
    nock.cleanAll();
    nock.restore();
  });
}
