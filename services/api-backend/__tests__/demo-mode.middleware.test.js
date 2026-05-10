jest.mock('../src/config/demo-mode', () => {
  let _enabled = false;
  return {
    isDemoMode: () => _enabled,
    __setDemoMode: (v) => { _enabled = v; },
  };
});

const { demoModeContext, demoWriteGuard } = require('../src/middleware/demo-mode');
const { __setDemoMode } = require('../src/config/demo-mode');

function mockReqRes(method = 'GET', path = '/buildings') {
  const req = { method, path, headers: {} };
  const json = jest.fn();
  const res = {
    setHeader: jest.fn(),
    status: jest.fn().mockReturnValue({ json }),
    json,
  };
  const next = jest.fn();
  return { req, res, next };
}

describe('demo-mode middleware', () => {
  beforeEach(() => {
    __setDemoMode(false);
  });

  describe('demoModeContext', () => {
    it('sets demoMode=false and header when demo mode off', () => {
      const { req, res, next } = mockReqRes();
      demoModeContext(req, res, next);
      expect(req.demoMode).toBe(false);
      expect(res.setHeader).toHaveBeenCalledWith('X-Demo-Mode', 'false');
      expect(next).toHaveBeenCalled();
    });

    it('sets demoMode=true and header when demo mode on', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes();
      demoModeContext(req, res, next);
      expect(req.demoMode).toBe(true);
      expect(res.setHeader).toHaveBeenCalledWith('X-Demo-Mode', 'true');
      expect(next).toHaveBeenCalled();
    });
  });

  describe('demoWriteGuard', () => {
    it('passes through GET requests in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('GET', '/buildings');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('passes through POST when demo mode is off', () => {
      __setDemoMode(false);
      const { req, res, next } = mockReqRes('POST', '/buildings');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('blocks POST to regular endpoint in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('POST', '/buildings');
      demoWriteGuard(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(403);
      const statusChain = res.status.mock.results[0].value;
      expect(statusChain.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: expect.objectContaining({ code: 'DEMO_WRITE_BLOCKED' }),
        }),
      );
    });

    it('blocks PUT in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('PUT', '/buildings/123');
      demoWriteGuard(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(403);
    });

    it('blocks DELETE in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('DELETE', '/buildings/123');
      demoWriteGuard(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(403);
    });

    it('allows POST to demo-login even in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('POST', '/demo/login');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('allows POST to auth/login even in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('POST', '/auth/login');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('allows POST to admin/seed even in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('POST', '/admin/seed');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });

    it('allows DELETE to admin/seed even in demo mode', () => {
      __setDemoMode(true);
      const { req, res, next } = mockReqRes('DELETE', '/admin/seed');
      demoWriteGuard(req, res, next);
      expect(next).toHaveBeenCalled();
    });
  });
});
