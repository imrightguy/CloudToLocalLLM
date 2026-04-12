import { sha256, md5, randomHash, hash } from '../../services/api-backend/utils/hash.js';

describe('hash utils', () => {
  describe('sha256', () => {
    it('returns a 64-char hex string', () => {
      const result = sha256('hello');
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('is deterministic', () => {
      expect(sha256('test')).toBe(sha256('test'));
    });

    it('differs for different inputs', () => {
      expect(sha256('a')).not.toBe(sha256('b'));
    });

    it('handles empty string', () => {
      const result = sha256('');
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  describe('md5', () => {
    it('returns a 32-char hex string', () => {
      const result = md5('hello');
      expect(result).toHaveLength(32);
      expect(result).toMatch(/^[0-9a-f]{32}$/);
    });

    it('is deterministic', () => {
      expect(md5('test')).toBe(md5('test'));
    });

    it('differs for different inputs', () => {
      expect(md5('a')).not.toBe(md5('b'));
    });
  });

  describe('randomHash', () => {
    it('returns a 64-char hex string', () => {
      const result = randomHash();
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('returns different values on each call', () => {
      const results = new Set(Array.from({ length: 10 }, () => randomHash()));
      expect(results.size).toBeGreaterThan(1);
    });
  });

  describe('hash', () => {
    it('defaults to sha256', () => {
      expect(hash('hello')).toBe(sha256('hello'));
    });

    it('supports different algorithms', () => {
      expect(hash('hello', 'md5')).toBe(md5('hello'));
      expect(hash('hello', 'sha1')).toHaveLength(40);
    });

    it('throws on invalid algorithm', () => {
      expect(() => hash('hello', 'bogus')).toThrow();
    });
  });
});
