import {
  validateTunnelConfig,
  getDefaultTunnelConfig,
  mergeTunnelConfig,
  sanitizeTunnelConfig,
} from '../../services/api-backend/utils/tunnel-config-validation.js';

describe('tunnel-config-validation', () => {
  describe('validateTunnelConfig', () => {
    it('returns invalid for null', () => {
      const result = validateTunnelConfig(null);
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Configuration must be an object');
    });

    it('returns invalid for undefined', () => {
      const result = validateTunnelConfig(undefined);
      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(1);
    });

    it('returns invalid for string', () => {
      const result = validateTunnelConfig('config');
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Configuration must be an object');
    });

    it('returns invalid for number', () => {
      const result = validateTunnelConfig(42);
      expect(result.isValid).toBe(false);
    });

    it('returns valid for empty object', () => {
      const result = validateTunnelConfig({});
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('returns valid for fully valid config', () => {
      const result = validateTunnelConfig({
        maxConnections: 500,
        timeout: 15000,
        compression: false,
      });
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    describe('maxConnections', () => {
      it('accepts minimum value (1)', () => {
        const result = validateTunnelConfig({ maxConnections: 1 });
        expect(result.isValid).toBe(true);
      });

      it('accepts maximum value (10000)', () => {
        const result = validateTunnelConfig({ maxConnections: 10000 });
        expect(result.isValid).toBe(true);
      });

      it('rejects zero', () => {
        const result = validateTunnelConfig({ maxConnections: 0 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('maxConnections must be between 1 and 10000');
      });

      it('rejects negative', () => {
        const result = validateTunnelConfig({ maxConnections: -1 });
        expect(result.isValid).toBe(false);
        expect(result.errors[0]).toContain('maxConnections');
      });

      it('rejects over max (10001)', () => {
        const result = validateTunnelConfig({ maxConnections: 10001 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('maxConnections must be between 1 and 10000');
      });

      it('rejects float', () => {
        const result = validateTunnelConfig({ maxConnections: 5.5 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('maxConnections must be an integer');
      });

      it('rejects string', () => {
        const result = validateTunnelConfig({ maxConnections: '100' });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('maxConnections must be an integer');
      });

      it('ignores when undefined', () => {
        const result = validateTunnelConfig({ maxConnections: undefined });
        expect(result.isValid).toBe(true);
      });
    });

    describe('timeout', () => {
      it('accepts minimum value (1000)', () => {
        const result = validateTunnelConfig({ timeout: 1000 });
        expect(result.isValid).toBe(true);
      });

      it('accepts maximum value (300000)', () => {
        const result = validateTunnelConfig({ timeout: 300000 });
        expect(result.isValid).toBe(true);
      });

      it('rejects below minimum (999)', () => {
        const result = validateTunnelConfig({ timeout: 999 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('timeout must be between 1000ms and 300000ms (5 minutes)');
      });

      it('rejects zero', () => {
        const result = validateTunnelConfig({ timeout: 0 });
        expect(result.isValid).toBe(false);
        expect(result.errors[0]).toContain('timeout');
      });

      it('rejects over max (300001)', () => {
        const result = validateTunnelConfig({ timeout: 300001 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('timeout must be between 1000ms and 300000ms (5 minutes)');
      });

      it('rejects float', () => {
        const result = validateTunnelConfig({ timeout: 1500.5 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('timeout must be an integer');
      });

      it('rejects string', () => {
        const result = validateTunnelConfig({ timeout: '30000' });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('timeout must be an integer');
      });
    });

    describe('compression', () => {
      it('accepts true', () => {
        const result = validateTunnelConfig({ compression: true });
        expect(result.isValid).toBe(true);
      });

      it('accepts false', () => {
        const result = validateTunnelConfig({ compression: false });
        expect(result.isValid).toBe(true);
      });

      it('rejects string', () => {
        const result = validateTunnelConfig({ compression: 'true' });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('compression must be a boolean');
      });

      it('rejects number', () => {
        const result = validateTunnelConfig({ compression: 1 });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('compression must be a boolean');
      });

      it('rejects null', () => {
        const result = validateTunnelConfig({ compression: null });
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain('compression must be a boolean');
      });
    });

    it('collects multiple errors', () => {
      const result = validateTunnelConfig({
        maxConnections: 'bad',
        timeout: 0.5,
        compression: 'yes',
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(3);
    });

    it('allows unknown properties without error', () => {
      const result = validateTunnelConfig({ extraProp: 'ignored' });
      expect(result.isValid).toBe(true);
    });
  });

  describe('getDefaultTunnelConfig', () => {
    it('returns expected defaults', () => {
      const defaults = getDefaultTunnelConfig();
      expect(defaults).toEqual({
        maxConnections: 100,
        timeout: 30000,
        compression: true,
      });
    });

    it('returns a new object each call', () => {
      const a = getDefaultTunnelConfig();
      const b = getDefaultTunnelConfig();
      expect(a).toEqual(b);
      expect(a).not.toBe(b);
    });
  });

  describe('mergeTunnelConfig', () => {
    it('returns defaults for null', () => {
      expect(mergeTunnelConfig(null)).toEqual(getDefaultTunnelConfig());
    });

    it('returns defaults for undefined', () => {
      expect(mergeTunnelConfig(undefined)).toEqual(getDefaultTunnelConfig());
    });

    it('returns defaults for empty object', () => {
      expect(mergeTunnelConfig({})).toEqual(getDefaultTunnelConfig());
    });

    it('merges provided maxConnections', () => {
      const result = mergeTunnelConfig({ maxConnections: 500 });
      expect(result.maxConnections).toBe(500);
      expect(result.timeout).toBe(30000);
      expect(result.compression).toBe(true);
    });

    it('merges provided timeout', () => {
      const result = mergeTunnelConfig({ timeout: 60000 });
      expect(result.timeout).toBe(60000);
      expect(result.maxConnections).toBe(100);
    });

    it('merges provided compression', () => {
      const result = mergeTunnelConfig({ compression: false });
      expect(result.compression).toBe(false);
      expect(result.maxConnections).toBe(100);
    });

    it('merges all provided values', () => {
      const result = mergeTunnelConfig({
        maxConnections: 200,
        timeout: 60000,
        compression: false,
      });
      expect(result).toEqual({
        maxConnections: 200,
        timeout: 60000,
        compression: false,
      });
    });

    it('does not override with nullish values', () => {
      const result = mergeTunnelConfig({
        maxConnections: null,
        timeout: undefined,
      });
      expect(result.maxConnections).toBe(100);
      expect(result.timeout).toBe(30000);
    });
  });

  describe('sanitizeTunnelConfig', () => {
    it('clamps maxConnections below minimum to 1', () => {
      const result = sanitizeTunnelConfig({ maxConnections: -50 });
      expect(result.maxConnections).toBe(1);
    });

    it('clamps maxConnections above maximum to 10000', () => {
      const result = sanitizeTunnelConfig({ maxConnections: 99999 });
      expect(result.maxConnections).toBe(10000);
    });

    it('clamps timeout below minimum to 1000', () => {
      const result = sanitizeTunnelConfig({ timeout: 100 });
      expect(result.timeout).toBe(1000);
    });

    it('clamps timeout above maximum to 300000', () => {
      const result = sanitizeTunnelConfig({ timeout: 500000 });
      expect(result.timeout).toBe(300000);
    });

    it('converts truthy compression to true', () => {
      const result = sanitizeTunnelConfig({ compression: 1 });
      expect(result.compression).toBe(true);
    });

    it('converts falsy compression to false', () => {
      const result = sanitizeTunnelConfig({ compression: 0 });
      expect(result.compression).toBe(false);
    });

    it('keeps valid values unchanged', () => {
      const result = sanitizeTunnelConfig({
        maxConnections: 500,
        timeout: 15000,
        compression: false,
      });
      expect(result).toEqual({
        maxConnections: 500,
        timeout: 15000,
        compression: false,
      });
    });

    it('returns defaults for null input', () => {
      const result = sanitizeTunnelConfig(null);
      expect(result).toEqual({
        maxConnections: 100,
        timeout: 30000,
        compression: true,
      });
    });
  });
});
