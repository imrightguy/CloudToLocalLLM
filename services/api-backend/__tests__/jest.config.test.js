const configPath = require.resolve('../jest.config');

describe('jest config integration test discovery', () => {
  const originalIncludeIntegration = process.env.JEST_INCLUDE_INTEGRATION;

  afterEach(() => {
    if (originalIncludeIntegration === undefined) {
      delete process.env.JEST_INCLUDE_INTEGRATION;
    } else {
      process.env.JEST_INCLUDE_INTEGRATION = originalIncludeIntegration;
    }
    jest.resetModules();
  });

  it('keeps integration tests excluded by default', () => {
    delete process.env.JEST_INCLUDE_INTEGRATION;
    jest.resetModules();

    const config = require(configPath);

    expect(config.testPathIgnorePatterns).toEqual(expect.arrayContaining([
      '<rootDir>/node_modules/',
      '<rootDir>/__tests__/integration/',
    ]));
  });

  it('allows integration tests to be discovered when explicitly requested', () => {
    process.env.JEST_INCLUDE_INTEGRATION = 'true';
    jest.resetModules();

    const config = require(configPath);

    expect(config.testPathIgnorePatterns).toEqual(expect.arrayContaining([
      '<rootDir>/node_modules/',
    ]));
    expect(config.testPathIgnorePatterns).not.toEqual(expect.arrayContaining([
      '<rootDir>/__tests__/integration/',
    ]));
  });
});
