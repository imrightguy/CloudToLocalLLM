import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from '@jest/globals';

const mockReadFile = jest.fn();

jest.unstable_mockModule('fs/promises', () => ({
  readFile: mockReadFile,
  default: { readFile: mockReadFile },
}));

const { serviceVersionHandler } = await import(
  '../../services/api-backend/routes/service-version.js'
);

function reloadHandler() {
  return import(
    '../../services/api-backend/routes/service-version.js?' +
      Date.now()
  ).then((m) => m.serviceVersionHandler);
}

describe('service-version route', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.resetModules();

    req = {};
    res = {
      json: jest.fn(),
      status: jest.fn().mockReturnThis(),
    };

    mockReadFile.mockReset();
  });

  afterEach(() => {
    delete process.env.API_VERSION;
    delete process.env.BUILD_NUMBER;
    delete process.env.GIT_COMMIT;
    delete process.env.NODE_ENV;
  });

  it('should return version info from package.json', async () => {
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '1.2.3', name: 'test-api-backend' })
    );

    const handler = await reloadHandler();
    await handler(req, res);

    expect(res.json).toHaveBeenCalledTimes(1);
    const body = res.json.mock.calls[0][0];
    expect(body.service).toBe('api-backend');
    expect(body.version).toBe('1.2.3');
    expect(body.name).toBe('test-api-backend');
    expect(body.node_version).toBe(process.version);
    expect(body.timestamp).toBeDefined();
  });

  it('should use API_VERSION env when package has no version', async () => {
    process.env.API_VERSION = '9.9.9';
    mockReadFile.mockResolvedValue(JSON.stringify({}));

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.version).toBe('9.9.9');
  });

  it('should fall back to unknown when no version available', async () => {
    mockReadFile.mockResolvedValue(JSON.stringify({}));

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.version).toBe('unknown');
  });

  it('should include BUILD_NUMBER and GIT_COMMIT env vars', async () => {
    process.env.BUILD_NUMBER = '42';
    process.env.GIT_COMMIT = 'abc123';
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '1.0.0' })
    );

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.build_number).toBe('42');
    expect(body.git_commit).toBe('abc123');
  });

  it('should default BUILD_NUMBER to dev and GIT_COMMIT to unknown', async () => {
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '1.0.0' })
    );

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.build_number).toBe('dev');
    expect(body.git_commit).toBe('unknown');
  });

  it('should use NODE_ENV for environment field', async () => {
    process.env.NODE_ENV = 'staging';
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '1.0.0' })
    );

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.environment).toBe('staging');
  });

  it('should default environment to production', async () => {
    delete process.env.NODE_ENV;
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '1.0.0' })
    );

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.environment).toBe('production');
  });

  it('should handle file read failure gracefully', async () => {
    mockReadFile.mockRejectedValue(new Error('ENOENT'));

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.service).toBe('api-backend');
    expect(body.error).toBe('Could not read version from package.json');
    expect(body.version).toBe('unknown');
  });

  it('should cache version across multiple calls', async () => {
    mockReadFile.mockResolvedValue(
      JSON.stringify({ version: '2.0.0' })
    );

    const handler = await reloadHandler();
    await handler(req, res);
    await handler(req, res);

    expect(res.json).toHaveBeenCalledTimes(2);
    expect(mockReadFile).toHaveBeenCalledTimes(1);
  });

  it('should return error message with fallback on file read failure', async () => {
    mockReadFile.mockRejectedValue(new Error('ENOENT'));

    const handler = await reloadHandler();
    await handler(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.error).toBe('Could not read version from package.json');
    expect(body.build_number).toBe('dev');
    expect(body.environment).toBeDefined();
    expect(body.node_version).toBe(process.version);
  });
});
