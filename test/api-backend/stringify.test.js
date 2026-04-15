import {
  stringify,
  truncate,
  asyncStringify,
  asyncToStringMethod,
  toStringMethod,
} from '../../services/api-backend/utils/stringify.js';

describe('stringify utilities', () => {
  describe('stringify', () => {
    it('stringifies a simple object with 2-space indent', () => {
      const result = stringify({ a: 1 });
      expect(result).toBe('{\n  "a": 1\n}');
    });

    it('respects custom space argument', () => {
      const result = stringify({ a: 1 }, 4);
      expect(result).toBe('{\n    "a": 1\n}');
    });

    it('stringifies arrays', () => {
      const result = stringify([1, 2, 3]);
      expect(result).toContain('1');
      expect(result).toContain('2');
      expect(result).toContain('3');
    });

    it('falls back to String() on circular reference', () => {
      const obj = {};
      obj.self = obj;
      const result = stringify(obj);
      expect(typeof result).toBe('string');
    });

    it('stringifies null', () => {
      expect(stringify(null)).toBe('null');
    });

    it('stringifies primitives', () => {
      expect(stringify(42)).toBe('42');
      expect(stringify('hi')).toBe('"hi"');
      expect(stringify(true)).toBe('true');
    });
  });

  describe('truncate', () => {
    it('returns short string unchanged', () => {
      expect(truncate('hello')).toBe('hello');
    });

    it('truncates long string with default max and suffix', () => {
      const long = 'a'.repeat(150);
      const result = truncate(long);
      expect(result).toHaveLength(100);
      expect(result.endsWith('...')).toBe(true);
    });

    it('respects custom max and suffix', () => {
      const result = truncate('abcdefghij', 7, '!');
      expect(result).toBe('abcdef!');
    });

    it('does not truncate when exactly maxLength', () => {
      expect(truncate('abcde', 5)).toBe('abcde');
    });

    it('handles empty string', () => {
      expect(truncate('')).toBe('');
    });

    it('handles suffix longer than maxLength', () => {
      const result = truncate('ab', 2, '...');
      expect(result).toBe('ab');
    });
  });

  describe('asyncStringify', () => {
    it('resolves with JSON string', async () => {
      const result = await asyncStringify({ a: 1 });
      expect(result).toBe('{\n  "a": 1\n}');
    });

    it('resolves with String() on circular reference', async () => {
      const obj = {};
      obj.self = obj;
      const result = await asyncStringify(obj);
      expect(typeof result).toBe('string');
    });

    it('respects custom space', async () => {
      const result = await asyncStringify({ x: 1 }, 0);
      expect(result).toBe('{"x":1}');
    });
  });

  describe('asyncToStringMethod', () => {
    it('resolves with toString result', async () => {
      const result = await asyncToStringMethod({ toString: () => 'custom' });
      expect(result).toBe('custom');
    });

    it('falls back to String() when no toString', async () => {
      const result = await asyncToStringMethod(42);
      expect(result).toBe('42');
    });

    it('falls back to [Object] on error', async () => {
      const obj = {
        toString() {
          throw new Error('boom');
        },
      };
      const result = await asyncToStringMethod(obj);
      expect(result).toBe('[Object]');
    });

    it('handles null', async () => {
      const result = await asyncToStringMethod(null);
      expect(result).toBe('null');
    });
  });

  describe('toStringMethod', () => {
    it('returns toString result', () => {
      expect(toStringMethod({ toString: () => 'yes' })).toBe('yes');
    });

    it('returns String() for primitives', () => {
      expect(toStringMethod(42)).toBe('42');
      expect(toStringMethod(null)).toBe('null');
      expect(toStringMethod(undefined)).toBe('undefined');
    });

    it('returns [Object] on error', () => {
      const obj = {
        toString() {
          throw new Error('fail');
        },
      };
      expect(toStringMethod(obj)).toBe('[Object]');
    });

    it('handles objects without custom toString', () => {
      const result = toStringMethod({ a: 1 });
      expect(result).toBe('[object Object]');
    });
  });
});
