console.log('Jest Config - CI Environment Variable:', process.env.CI);

export default {
  // Test environment
  testEnvironment: 'node',

  // Coverage thresholds - enforced in both CI and local dev
  // Lower thresholds for CI (50%) vs local (70%) to allow gradual improvement
  coverageThreshold: {
    global: process.env.CI
      ? { branches: 50, functions: 50, lines: 50, statements: 50 }
      : { branches: 70, functions: 70, lines: 70, statements: 70 },
  },

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
