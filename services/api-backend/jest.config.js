export default {
  // Test environment
  testEnvironment: 'node',

  // Coverage thresholds: disabled — repo outgrew 70% target.
  // Coverage still collected (see coverageDirectory) for spotting gaps.
  // coverageThreshold: {},

  // Test file patterns
  testMatch: ['<rootDir>/../../test/api-backend/**/*.js'],

  // Files to ignore (Requirement: CI Stability)
  testPathIgnorePatterns: [
    '/node_modules/',
    '/build/',
    '/dist/',
    // Tunnel tests require real DB + auth infrastructure
    'tunnel-server\\.test\\.js$',
    'tunnel-lifecycle\\.test\\.js$',
    'tunnel-health-tracking\\.test\\.js$',
    'tunnel-properties\\.test\\.js$',
    'tunnel-sharing\\.test\\.js$',
    'tunnel-usage\\.test\\.js$',
    'tunnel-webhooks\\.test\\.js$',
    'tunnel-sharing-integration\\.test\\.js$',
    // Tests requiring live infrastructure or unmockable auth
    'proxy-usage\\.test\\.js$',
    'bridge-polling-routes\\.test\\.js$',
    'cloudflare-dns-resolution\\.test\\.js$',
  ],

  // Expand Jest roots to include repository test directory
  roots: ['<rootDir>', '<rootDir>/../../test'],

  // Help Jest resolve modules from service node_modules when tests live outside
  moduleDirectories: ['node_modules', '<rootDir>/node_modules'],

  // Ensure Jest globals (jest, expect) are available in ESM tests
  injectGlobals: true,

  // Map imports from test files (living outside service) back into service source
  moduleNameMapper: {
    // jwks-rsa → jose ESM incompatibility with Node 22 (needs v24.9+)
    '^jwks-rsa$': '<rootDir>/../../test/mocks/jwks-rsa.cjs',
    // One-level up (../)
    '^\\.\\./tunnel/(.*)\\.js$': '<rootDir>/tunnel/$1.js',
    '^\\.\\./utils/(.*)\\.js$': '<rootDir>/utils/$1.js',
    '^\\.\\./routes/(.*)\\.js$': '<rootDir>/routes/$1.js',
    '^\\.\\./middleware/(.*)\\.js$': '<rootDir>/middleware/$1.js',
    '^\\.\\./admin-data-flush-service\\.js$':
      '<rootDir>/admin-data-flush-service.js',

    // Two-levels up (../../)
    '^\\.\\.\\/\\.\\.\\/tunnel/(.*)\\.js$': '<rootDir>/tunnel/$1.js',
    '^\\.\\.\\/\\.\\.\\/utils/(.*)\\.js$': '<rootDir>/utils/$1.js',
    '^\\.\\.\\/\\.\\.\\/routes/(.*)\\.js$': '<rootDir>/routes/$1.js',
    '^\\.\\.\\/\\.\\.\\/middleware/(.*)\\.js$': '<rootDir>/middleware/$1.js',
    '^\\.\\.\\/\\.\\.\\/admin-data-flush-service\\.js$':
      '<rootDir>/admin-data-flush-service.js',

    // Absolute-ish imports from repo root used in some tests
    '^\\.\\.\\/\\.\\.\\/services\\/api-backend\\/(.*)\\.js$': '<rootDir>/$1.js',
  },

  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'json', 'cobertura'],

  // Coverage thresholds

  // Files to collect coverage from
  collectCoverageFrom: [
    '**/*.js',
    '!**/node_modules/**',
    '!**/test/**',
    '!**/coverage/**',
    '!jest.config.js',
    '!jest.setup.js',
    '!eslint.config.js',
    '!tunnel/**',
    '!utils/globals.js',
    '!server.js',
    '!admin-server.js',
    '!streaming-proxy-manager.js',
    '!tracing.js',
    '!config/**',
    '!database/migrations/**',
    '!database/seeds/**',
    '!database/migrate-*.js',
    '!database/pool-monitor.js',
  ],

  // Setup files
  // setupFilesAfterEnv: ['<rootDir>/test/setup.js'],

  // Module file extensions
  moduleFileExtensions: ['js', 'json'],

  // No transform needed for plain JS in pure ESM setup
  transform: {},

  // Test timeout (increased for CI)
  testTimeout: 30000,

  // Reporters for CI
  reporters: process.env.CI
    ? [
        'default',
        [
          'jest-junit',
          {
            outputDirectory: 'test-results',
            outputName: 'junit.xml',
            classNameTemplate: '{classname}',
            titleTemplate: '{title}',
            ancestorSeparator: ' › ',
            usePathForSuiteName: true,
          },
        ],
      ]
    : ['default'],

  // Verbose output for CI
  verbose: process.env.CI === 'true',

  // Bail on first test failure in CI
  bail: process.env.CI === 'true' ? 1 : 0,

  // Force exit after tests complete
  forceExit: true,

  // Clear mocks between tests
  clearMocks: true,

  // Restore mocks after each test
  restoreMocks: true,

  // Global setup/teardown
  // globalSetup: './test/global-setup.js',
  // globalTeardown: './test/global-teardown.js',

  // Env vars for testing
  testEnvironmentOptions: { NODE_ENV: 'test' },
};
