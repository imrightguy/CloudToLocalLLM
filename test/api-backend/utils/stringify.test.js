import {
  stringify,
  truncate,
  asyncStringify,
  asyncToStringMethod,
  toStringMethod,
} from '../../../services/api-backend/utils/stringify.js';

describe('utils/stringify', () => {
  describe('stringify', () => {
    it('stringifies a plain object', () => {
      expect(stringify({ a: 1 })).toBe('{\n  "a": 1\n}');
    });

    it('uses custom indentation', () => {
      const result = stringify({ a: 1 }, 4);
      expect(result).toBe('{\n    "a": 1\n}');
    });

    it('handles arrays', () => {
      expect(stringify([1, 2, 3])).toBe('[\n  1,\n  2,\n  3\n]');
    });

    it('handles primitives', () => {
      expect(stringify(42)).toBe('42');
      expect(stringify('hello')).toBe('"hello"');
      expect(stringify(null)).toBe('null');
      expect(stringify(true)).toBe('true');
    });

    it('falls back to String() for circular refs', () => {
      const obj = {};
      obj.self = obj;
      const result = stringify(obj);
      expect(result).toBe(String(obj));
    });
  });

  describe('truncate', () => {
    it('returns original string if under max length', () => {
      expect(truncate('hello', 10)).toBe('hello');
    });

    it('truncates and adds default suffix', () => {
      expect(truncate('hello world', 8)).toBe('hello...');
    });

    it('returns original when exactly at max length', () => {
      expect(truncate('hello', 5)).toBe('hello');
    });

    it('supports custom suffix', () => {
      expect(truncate('hello world', 8, '!')).toBe('hello w!');
    });

    it('supports custom max length', () => {
      expect(truncate('abcdefghij', 5, '...')).toBe('ab...');
    });

    it('handles empty string', () => {
      expect(truncate('', 10)).toBe('');
    });
  });

  describe('asyncStringify', () => {
    it('resolves with JSON string', async () => {
      await expect(asyncStringify({ a: 1 })).resolves.toBe('{\n  "a": 1\n}');
    });

    it('falls back to String() for circular refs', async () => {
      const obj = {};
      obj.self = obj;
      await expect(asyncStringify(obj)).resolves.toBe(String(obj));
    });
  });

  describe('toStringMethod', () => {
    it('uses toString if available', () => {
      expect(toStringMethod(42)).toBe('42');
      expect(toStringMethod('hello')).toBe('hello');
    });

    it('uses String() for null/undefined', () => {
      expect(toStringMethod(null)).toBe('null');
      expect(toStringMethod(undefined)).toBe('undefined');
    });

    it('returns [Object] when toString throws', () => {
      const bad = { toString: () => { throw new Error('boom'); } };
      expect(toStringMethod(bad)).toBe('[Object]');
    });
  });

  describe('asyncToStringMethod', () => {
    it('resolves with toString result', async () => {
      await expect(asyncToStringMethod(42)).resolves.toBe('42');
    });

    it('handles null/undefined', async () => {
      await expect(asyncToStringMethod(null)).resolves.toBe('null');
    });

    it('resolves with [Object] when toString throws', async () => {
      const bad = { toString: () => { throw new Error('boom'); } };
      await expect(asyncToStringMethod(bad)).resolves.toBe('[Object]');
    });
  });
});
