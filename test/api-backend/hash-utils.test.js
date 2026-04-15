import {
  jest,
  describe,
  it,
  expect,
} from '@jest/globals';
import {
  sha256,
  md5,
  randomHash,
  hash,
  default as hashUtils,
} from '../../services/api-backend/utils/hash.js';

describe('hash utils', () => {
  describe('sha256', () => {
    it('should produce a hex-encoded SHA256 hash', () => {
      const result = sha256('hello');
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('should produce consistent results for the same input', () => {
      expect(sha256('test')).toBe(sha256('test'));
    });

    it('should produce different results for different inputs', () => {
      expect(sha256('a')).not.toBe(sha256('b'));
    });

    it('should match known SHA256 value', () => {
      expect(sha256('')).toBe(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    it('should handle unicode input', () => {
      const result = sha256('héllo wörld 🌍');
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  describe('md5', () => {
    it('should produce a hex-encoded MD5 hash', () => {
      const result = md5('hello');
      expect(result).toMatch(/^[0-9a-f]{32}$/);
    });

    it('should match known MD5 value', () => {
      expect(md5('')).toBe('d41d8cd98f00b204e9800998ecf8427e');
    });

    it('should be consistent', () => {
      expect(md5('test')).toBe(md5('test'));
    });

    it('should differ from sha256 output', () => {
      expect(md5('test')).not.toBe(sha256('test'));
    });
  });

  describe('randomHash', () => {
    it('should return a 64-character hex string', () => {
      const result = randomHash();
      expect(result).toMatch(/^[0-9a-f]{64}$/);
    });

    it('should produce unique values on successive calls', () => {
      const a = randomHash();
      const b = randomHash();
      expect(a).not.toBe(b);
    });
  });

  describe('hash', () => {
    it('should default to sha256', () => {
      expect(hash('test')).toBe(sha256('test'));
    });

    it('should support sha512 algorithm', () => {
      const result = hash('test', 'sha512');
      expect(result).toMatch(/^[0-9a-f]{128}$/);
    });

    it('should support sha1 algorithm', () => {
      const result = hash('test', 'sha1');
      expect(result).toMatch(/^[0-9a-f]{40}$/);
    });

    it('should respect explicit algorithm parameter', () => {
      expect(hash('test', 'md5')).toBe(md5('test'));
    });
  });

  describe('default export', () => {
    it('should expose all functions', () => {
      expect(hashUtils.sha256).toBe(sha256);
      expect(hashUtils.md5).toBe(md5);
      expect(hashUtils.randomHash).toBe(randomHash);
      expect(hashUtils.hash).toBe(hash);
    });
  });
});
