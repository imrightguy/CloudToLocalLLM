/** @type {import('jest').Config} */
const includeIntegration = process.env.JEST_INCLUDE_INTEGRATION === 'true';

module.exports = {
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/__tests__/**/*.test.js',
  ],
  testPathIgnorePatterns: [
    '<rootDir>/node_modules/',
    ...(!includeIntegration ? ['<rootDir>/__tests__/integration/'] : []),
  ],
  setupFilesAfterEnv: ['./jest.setup.js'],
  forceExit: true,
};
