export default {
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.js"],
  transform: {},
  coverageThreshold: {
    global: process.env.CI
      ? { branches: 0, functions: 0, lines: 0, statements: 0 }
      : { branches: 70, functions: 70, lines: 70, statements: 70 },
  },
  collectCoverageFrom: [
    "services/**/*.js",
    "!services/**/node_modules/**",
    "!**/dist/**",
  ],
  coveragePathIgnorePatterns: ["/node_modules/", "/dist/"],
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  testPathIgnorePatterns: [
    "/node_modules/",
    "/dist/",
    // Integration tests requiring live PostgreSQL
    "tunnel-lifecycle\\.test\\.js$",
    "tunnel-health-tracking\\.test\\.js$",
    "tunnel-properties\\.test\\.js$",
    "tunnel-sharing\\.test\\.js$",
    "tunnel-usage\\.test\\.js$",
    "tunnel-webhooks\\.test\\.js$",
    "proxy-usage\\.test\\.js$",
    "bridge-polling-routes\\.test\\.js$",
    "cloudflare-dns-resolution\\.test\\.js$",
  ],
};
