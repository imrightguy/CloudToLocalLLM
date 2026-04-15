import {
  jest,
  describe,
  it,
  expect,
} from '@jest/globals';
import {
  stringify,
  truncate,
  asyncStringify,
  asyncToStringMethod,
  toStringMethod,
  default as stringifyUtils,
} from '../../services/api-backend/utils/stringify.js';

describe('stringify utils', () => {
  describe('stringify', () => {
    it('should stringify a plain object with default 2-space indent', () => {
      const result = stringify({ a: 1 });
      expect(result).toBe(JSON.stringify({ a: 1 }, null, 2));
    });

    it('should respect custom space parameter', () => {
      const result = stringify({ a: 1 }, 4);
      expect(result).toContain('    ');
    });

    it('should handle circular references gracefully', () => {
      const obj = {};
      obj.self = obj;
      const result = stringify(obj);
      expect(typeof result).toBe('string');
    });

    it('should handle null input', () => {
      expect(stringify(null)).toBe('null');
    });

    it('should handle primitive input', () => {
      expect(stringify(42)).toBe('42');
    });
  });

  describe('truncate', () => {
    it('should return string unchanged if under max length', () => {
      expect(truncate('hello', 10)).toBe('hello');
    });

    it('should truncate and add suffix at default max length 100', () => {
      const long = 'a'.repeat(120);
      const result = truncate(long);
      expect(result.length).toBeLessThan(long.length);
      expect(result.endsWith('...')).toBe(true);
    });

    it('should respect custom max length', () => {
      const result = truncate('abcdefghij', 7, '...');
      expect(result).toBe('abcd...');
    });

    it('should use custom suffix', () => {
      const result = truncate('abcdefghij', 7, '…');
      expect(result).toBe('abcdef…');
    });

    it('should not truncate when length equals max', () => {
      expect(truncate('hello', 5)).toBe('hello');
    });
  });

  describe('asyncStringify', () => {
    it('should resolve with stringified object', async () => {
      const result = await asyncStringify({ a: 1 });
      expect(result).toBe(JSON.stringify({ a: 1 }, null, 2));
    });

    it('should handle circular references gracefully', async () => {
      const obj = {};
      obj.self = obj;
      const result = await asyncStringify(obj);
      expect(typeof result).toBe('string');
    });

    it('should use custom space parameter', async () => {
      const result = await asyncStringify({ x: 1 }, 0);
      expect(result).toBe('{"x":1}');
    });
  });

  describe('asyncToStringMethod', () => {
    it('should resolve with toString result for objects', async () => {
      const result = await asyncToStringMethod({ toString: () => 'custom' });
      expect(result).toBe('custom');
    });

    it('should handle null gracefully', async () => {
      const result = await asyncToStringMethod(null);
      expect(result).toBe('null');
    });

    it('should handle undefined gracefully', async () => {
      const result = await asyncToStringMethod(undefined);
      expect(result).toBe('undefined');
    });

    it('should handle numbers', async () => {
      const result = await asyncToStringMethod(42);
      expect(result).toBe('42');
    });
  });

  describe('toStringMethod', () => {
    it('should return toString for objects with custom toString', () => {
      const result = toStringMethod({ toString: () => 'hello' });
      expect(result).toBe('hello');
    });

    it('should use String() for objects without custom toString', () => {
      const result = toStringMethod(123);
      expect(result).toBe('123');
    });

    it('should handle null', () => {
      expect(toStringMethod(null)).toBe('null');
    });

    it('should handle undefined', () => {
      expect(toStringMethod(undefined)).toBe('undefined');
    });

    it('should handle arrays', () => {
      expect(toStringMethod([1, 2, 3])).toBe('1,2,3');
    });
  });

  describe('default export', () => {
    it('should expose all functions', () => {
      expect(stringifyUtils.stringify).toBe(stringify);
      expect(stringifyUtils.truncate).toBe(truncate);
      expect(stringifyUtils.asyncStringify).toBe(asyncStringify);
      expect(stringifyUtils.asyncToStringMethod).toBe(asyncToStringMethod);
      expect(stringifyUtils.toStringMethod).toBe(toStringMethod);
    });
  });
});
