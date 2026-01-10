// Jest configuration for CloudToLocalLLM API Backend (ESM)
// Optimized for CI/CD pipeline execution under Node.js 24

export default {
  // Test environment
  testEnvironment: 'node',

  // Test file patterns
  testMatch: ['<rootDir>/../../test/api-backend/**/*.js'],

  // Files to ignore
  testPathIgnorePatterns: [
    '/node_modules/',
    '/build/',
    '/dist/',
    'tunnel-server\\.test\\.js$',
  ],

  // Expand Jest roots to include repository test directory
  roots: ['<rootDir>', '<rootDir>/../../test'],

  // Help Jest resolve modules from service node_modules when tests live outside
  moduleDirectories: ['node_modules', '<rootDir>/node_modules'],

  // Ensure Jest globals (jest, expect) are available in ESM tests
  injectGlobals: true,

  // Map imports from test files (living outside service) back into service source
  moduleNameMapper: {
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
  coverageThreshold: {
    global:
      process.env.CI === 'true'
        ? { branches: 0, functions: 0, lines: 0, statements: 0 }
        : { branches: 70, functions: 70, lines: 70, statements: 70 },
  },

  // Files to collect coverage from
  collectCoverageFrom: [
    '**/*.js',
    '!**/node_modules/**',
    '!**/test/**',
    '!**/coverage/**',
    '!jest.config.js',
    '!eslint.config.js',
  ],

  // Setup files
  setupFilesAfterEnv: ['<rootDir>/test/setup.js'],

  // Module file extensions
  moduleFileExtensions: ['js', 'json'],

  // No transform needed for plain JS in pure ESM setup
  transform: {},

  // Test timeout (increased for CI)
  testTimeout: 30000,

  // Reporters for CI
  reporters: [
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
  ],

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
  globalSetup: '<rootDir>/test/global-setup.js',
  globalTeardown: '<rootDir>/test/global-teardown.js',

  // Env vars for testing
  testEnvironmentOptions: { NODE_ENV: 'test' },
};
