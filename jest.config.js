export default {
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.js"],
  transform: {},
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
    "^jwks-rsa$": "<rootDir>/test/mocks/jwks-rsa.cjs",
  },
  modulePathIgnorePatterns: [
    "/\\.kilo/",
  ],
  coverageThreshold: {
    global: process.env.CI
      ? { branches: 0, functions: 0, lines: 0, statements: 0 }
      : { branches: 70, functions: 70, lines: 70, statements: 70 },
  },
  collectCoverageFrom: [
    "services/**/*.js",
    "!services/**/node_modules/**",
    "!**/dist/**",
    "!**/.kilo/**",
  ],
  coveragePathIgnorePatterns: ["/node_modules/", "/dist/", "/\\.kilo/"],
  testPathIgnorePatterns: [
    "/node_modules/",
    "/dist/",
    "/\\.kilo/",
    // Auth backend tests require live Auth0 JWKS (mock can't replicate express-jwt's full error flow)
    "test/backend/auth\\.test\\.js$",
    "tunnel-lifecycle\\.test\\.js$",
    "tunnel-health-tracking\\.test\\.js$",
    "tunnel-properties\\.test\\.js$",
    "tunnel-sharing\\.test\\.js$",
    "tunnel-usage\\.test\\.js$",
    "tunnel-webhooks\\.test\\.js$",
    "proxy-usage\\.test\\.js$",
    "bridge-polling-routes\\.test\\.js$",
    "cloudflare-dns-resolution\\.test\\.js$",
    // jwks-rsa → jose ESM incompatibility with Node 22 (needs v24.9+)
    "api-keys\\.test\\.js$",
    "error-recovery-integration\\.test\\.js$",
    "sandbox-routes\\.test\\.js$",
  ],
};
