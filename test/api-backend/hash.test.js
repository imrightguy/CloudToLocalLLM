import { sha256, md5, randomHash, hash } from '../../services/api-backend/utils/hash.js';

describe('hash utilities', () => {
  describe('sha256', () => {
    it('produces a 64-char hex string', () => {
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

    it('hashes empty string', () => {
      const result = sha256('');
      expect(result).toHaveLength(64);
      expect(typeof result).toBe('string');
    });

    it('matches known SHA-256 value', () => {
      expect(sha256('')).toBe(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });

  describe('md5', () => {
    it('produces a 32-char hex string', () => {
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

    it('matches known MD5 value', () => {
      expect(md5('')).toBe('d41d8cd98f00b204e9800998ecf8427e');
    });
  });

  describe('randomHash', () => {
    it('produces a 64-char hex string', () => {
      const result = randomHash();
      expect(result).toHaveLength(64);
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('generates unique values', () => {
      const a = randomHash();
      const b = randomHash();
      expect(a).not.toBe(b);
    });
  });

  describe('hash', () => {
    it('defaults to SHA-256', () => {
      expect(hash('hello')).toBe(sha256('hello'));
    });

    it('supports MD5 explicitly', () => {
      expect(hash('hello', 'md5')).toBe(md5('hello'));
    });

    it('supports SHA-512', () => {
      const result = hash('hello', 'sha512');
      expect(result).toHaveLength(128);
      expect(result).toMatch(/^[0-9a-f]{128}$/);
    });

    it('throws for unsupported algorithm', () => {
      expect(() => hash('hello', 'bogus')).toThrow();
    });
  });
});
