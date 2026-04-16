import { sha256, md5, randomHash, hash } from '../../../services/api-backend/utils/hash.js';

describe('utils/hash', () => {
  describe('sha256', () => {
    it('returns a 64-char hex string', () => {
      const result = sha256('hello');
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('produces consistent output for same input', () => {
      expect(sha256('test')).toBe(sha256('test'));
    });

    it('produces different output for different inputs', () => {
      expect(sha256('a')).not.toBe(sha256('b'));
    });

    it('handles empty string', () => {
      const result = sha256('');
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('matches known SHA256 value', () => {
      expect(sha256('hello')).toBe(
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
      );
    });
  });

  describe('md5', () => {
    it('returns a 32-char hex string', () => {
      const result = md5('hello');
      expect(result).toHaveLength(32);
      expect(result).toMatch(/^[0-9a-f]{32}$/);
    });

    it('produces consistent output for same input', () => {
      expect(md5('test')).toBe(md5('test'));
    });

    it('produces different output for different inputs', () => {
      expect(md5('a')).not.toBe(md5('b'));
    });

    it('matches known MD5 value', () => {
      expect(md5('hello')).toBe('5d41402abc4b2a76b9719d911017c592');
    });
  });

  describe('randomHash', () => {
    it('returns a 64-char hex string', () => {
      const result = randomHash();
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('returns different values on successive calls', () => {
      const results = new Set(Array.from({ length: 10 }, () => randomHash()));
      expect(results.size).toBe(10);
    });
  });

  describe('hash', () => {
    it('defaults to sha256', () => {
      expect(hash('hello')).toBe(sha256('hello'));
    });

    it('supports sha256 explicitly', () => {
      expect(hash('hello', 'sha256')).toBe(
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
      );
    });

    it('supports sha1', () => {
      const result = hash('hello', 'sha1');
      expect(result).toHaveLength(40);
      expect(result).toMatch(/^[0-9a-f]{40}$/);
    });

    it('supports sha512', () => {
      const result = hash('hello', 'sha512');
      expect(result).toHaveLength(128);
      expect(result).toMatch(/^[0-9a-f]{128}$/);
    });
  });
});
