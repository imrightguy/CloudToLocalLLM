import { jest } from '@jest/globals';
import fs from 'fs';
import path from 'path';
import ChangelogService from '../../services/api-backend/services/changelog-service.js';

describe('ChangelogService', () => {
  let service;
  let originalExistsSync;
  let originalReadFileSync;

  const validChangelog = `# Changelog

## [1.2.0] - 2025-01-15

### Added
- New feature for X
- Another feature for Y

### Fixed
- Bug fix for Z

## [1.1.0] - 2025-01-01

### Changed
- Updated something important

### Security
- Patched vulnerability

## [1.0.0] - 2024-12-01

### Added
- Initial release
`;

  const malformedChangelog = `# Changelog

## [not-a-version] - invalid-date

### Added
- Something
`;

  beforeEach(() => {
    service = new ChangelogService();
    originalExistsSync = fs.existsSync;
    originalReadFileSync = fs.readFileSync;
  });

  afterEach(() => {
    fs.existsSync = originalExistsSync;
    fs.readFileSync = originalReadFileSync;
    jest.restoreAllMocks();
  });

  const mockChangelogFile = (content) => {
    fs.existsSync = jest.fn((p) => {
      if (p.includes('CHANGELOG.md')) return true;
      return originalExistsSync.call(fs, p);
    });
    fs.readFileSync = jest.fn((p, encoding) => {
      if (p.includes('CHANGELOG.md')) return content;
      return originalReadFileSync.call(fs, p, encoding);
    });
  };

  const mockPackageJson = (version) => {
    fs.readFileSync = jest.fn((p, encoding) => {
      if (p.includes('package.json')) return JSON.stringify({ version });
      if (p.includes('CHANGELOG.md')) return validChangelog;
      return originalReadFileSync.call(fs, p, encoding);
    });
    fs.existsSync = jest.fn((p) => {
      if (p.includes('CHANGELOG.md')) return true;
      return originalExistsSync.call(fs, p);
    });
  };

  describe('parseChangelog', () => {
    test('should return empty array when changelog file does not exist', () => {
      fs.existsSync = jest.fn(() => false);
      const result = service.parseChangelog();
      expect(result).toEqual([]);
    });

    test('should parse valid changelog with multiple versions', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      expect(result).toHaveLength(3);
    });

    test('should extract version numbers correctly', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      expect(result[0].version).toBe('1.2.0');
      expect(result[1].version).toBe('1.1.0');
      expect(result[2].version).toBe('1.0.0');
    });

    test('should extract dates correctly', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      expect(result[0].date).toBe('2025-01-15');
      expect(result[1].date).toBe('2025-01-01');
      expect(result[2].date).toBe('2024-12-01');
    });

    test('should collect changes including section headers and bullets', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      expect(result[0].changes.length).toBeGreaterThan(0);
    });

    test('should filter out empty changes', () => {
      const changelogWithEmpty = `# Changelog

## [1.0.0] - 2025-01-01

### Added
- Feature A
`;
      mockChangelogFile(changelogWithEmpty);
      const result = service.parseChangelog();
      const emptyChanges = result[0].changes.filter((c) => c.trim() === '');
      expect(emptyChanges).toHaveLength(0);
    });

    test('should handle changelog with no version entries', () => {
      mockChangelogFile('# Changelog\n\nNothing here.\n');
      const result = service.parseChangelog();
      expect(result).toEqual([]);
    });

    test('should throw wrapped error on read failure', () => {
      fs.existsSync = jest.fn(() => true);
      fs.readFileSync = jest.fn(() => {
        throw new Error('disk error');
      });
      expect(() => service.parseChangelog()).toThrow(
        'Failed to parse changelog',
      );
    });

    test('should parse section headers as changes', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      const addedHeaders = result[0].changes.filter((c) =>
        c.includes('### Added'),
      );
      expect(addedHeaders.length).toBeGreaterThan(0);
    });

    test('should parse bullet point changes', () => {
      mockChangelogFile(validChangelog);
      const result = service.parseChangelog();
      const bullets = result[0].changes.filter((c) => c.match(/^- /));
      expect(bullets.length).toBeGreaterThan(0);
    });
  });

  describe('getLatestVersion', () => {
    test('should return first entry from parsed changelog', () => {
      mockChangelogFile(validChangelog);
      const result = service.getLatestVersion();
      expect(result.version).toBe('1.2.0');
      expect(result.date).toBe('2025-01-15');
    });

    test('should return null when changelog is empty', () => {
      fs.existsSync = jest.fn(() => false);
      const result = service.getLatestVersion();
      expect(result).toBeNull();
    });
  });

  describe('getVersionByNumber', () => {
    test('should find existing version', () => {
      mockChangelogFile(validChangelog);
      const result = service.getVersionByNumber('1.1.0');
      expect(result).not.toBeNull();
      expect(result.version).toBe('1.1.0');
    });

    test('should return null for non-existent version', () => {
      mockChangelogFile(validChangelog);
      const result = service.getVersionByNumber('99.99.99');
      expect(result).toBeNull();
    });

    test('should return null when changelog is empty', () => {
      fs.existsSync = jest.fn(() => false);
      const result = service.getVersionByNumber('1.0.0');
      expect(result).toBeNull();
    });
  });

  describe('getAllVersions', () => {
    test('should return all versions with default pagination', () => {
      mockChangelogFile(validChangelog);
      const result = service.getAllVersions();
      expect(result.total).toBe(3);
      expect(result.limit).toBe(10);
      expect(result.offset).toBe(0);
      expect(result.versions).toHaveLength(3);
    });

    test('should respect limit parameter', () => {
      mockChangelogFile(validChangelog);
      const result = service.getAllVersions(2);
      expect(result.versions).toHaveLength(2);
      expect(result.total).toBe(3);
    });

    test('should respect offset parameter', () => {
      mockChangelogFile(validChangelog);
      const result = service.getAllVersions(10, 1);
      expect(result.versions).toHaveLength(2);
      expect(result.versions[0].version).toBe('1.1.0');
    });

    test('should handle offset beyond available entries', () => {
      mockChangelogFile(validChangelog);
      const result = service.getAllVersions(10, 100);
      expect(result.versions).toEqual([]);
      expect(result.total).toBe(3);
    });

    test('should return empty versions array when no changelog', () => {
      fs.existsSync = jest.fn(() => false);
      const result = service.getAllVersions();
      expect(result.total).toBe(0);
      expect(result.versions).toEqual([]);
    });
  });

  describe('getCurrentApiVersion', () => {
    test('should return version from package.json', () => {
      mockPackageJson('2.5.1');
      const result = service.getCurrentApiVersion();
      expect(result).toBe('2.5.1');
    });

    test('should throw wrapped error when package.json is unreadable', () => {
      fs.readFileSync = jest.fn((p) => {
        if (p.includes('package.json'))
          throw new Error('permission denied');
        return '{}';
      });
      expect(() => service.getCurrentApiVersion()).toThrow(
        'Failed to read package.json',
      );
    });
  });

  describe('formatChangelogEntry', () => {
    test('should format entry with version, date, changes, and changeCount', () => {
      const entry = {
        version: '1.0.0',
        date: '2025-01-01',
        changes: ['### Added', '- Feature A', '- Feature B', '### Fixed'],
      };
      const result = service.formatChangelogEntry(entry);
      expect(result.version).toBe('1.0.0');
      expect(result.date).toBe('2025-01-01');
      expect(result.changes).toHaveLength(4);
      expect(result.changeCount).toBe(2);
    });

    test('should count only bullet lines for changeCount', () => {
      const entry = {
        version: '2.0.0',
        date: '2025-06-01',
        changes: [
          '### Added',
          '- New thing',
          '### Changed',
          '- Updated thing',
          '- Another update',
        ],
      };
      const result = service.formatChangelogEntry(entry);
      expect(result.changeCount).toBe(3);
    });

    test('should return 0 changeCount for entry with no bullets', () => {
      const entry = {
        version: '0.1.0',
        date: '2025-01-01',
        changes: [],
      };
      const result = service.formatChangelogEntry(entry);
      expect(result.changeCount).toBe(0);
    });
  });

  describe('getReleaseNotes', () => {
    test('should return formatted release notes for existing version', () => {
      mockChangelogFile(validChangelog);
      const result = service.getReleaseNotes('1.2.0');
      expect(result).not.toBeNull();
      expect(result.version).toBe('1.2.0');
      expect(result.date).toBe('2025-01-15');
      expect(result.releaseNotes).toContain('### Added');
      expect(result.formatted).toBeDefined();
      expect(result.formatted.version).toBe('1.2.0');
    });

    test('should return null for non-existent version', () => {
      mockChangelogFile(validChangelog);
      const result = service.getReleaseNotes('0.0.1');
      expect(result).toBeNull();
    });

    test('should join changes with newlines in releaseNotes', () => {
      mockChangelogFile(validChangelog);
      const result = service.getReleaseNotes('1.1.0');
      expect(result.releaseNotes).toContain('\n');
    });
  });

  describe('validateChangelogFormat', () => {
    test('should return true for valid changelog', () => {
      mockChangelogFile(validChangelog);
      expect(service.validateChangelogFormat()).toBe(true);
    });

    test('should return false when no entries exist', () => {
      mockChangelogFile('# Changelog\n\nNothing here.\n');
      expect(service.validateChangelogFormat()).toBe(false);
    });

    test('should return false for malformed version numbers', () => {
      mockChangelogFile(malformedChangelog);
      expect(service.validateChangelogFormat()).toBe(false);
    });

    test('should return false on parse error', () => {
      fs.existsSync = jest.fn(() => true);
      fs.readFileSync = jest.fn(() => {
        throw new Error('read error');
      });
      expect(service.validateChangelogFormat()).toBe(false);
    });
  });

  describe('getChangelogStats', () => {
    test('should return stats for valid changelog', () => {
      mockChangelogFile(validChangelog);
      const stats = service.getChangelogStats();
      expect(stats.totalVersions).toBe(3);
      expect(stats.latestVersion).toBe('1.2.0');
      expect(stats.oldestVersion).toBe('1.0.0');
      expect(stats.totalChanges).toBeGreaterThan(0);
      expect(stats.isValid).toBe(true);
    });

    test('should return zero stats for empty changelog', () => {
      fs.existsSync = jest.fn(() => false);
      const stats = service.getChangelogStats();
      expect(stats.totalVersions).toBe(0);
      expect(stats.latestVersion).toBeNull();
      expect(stats.oldestVersion).toBeNull();
      expect(stats.totalChanges).toBe(0);
      expect(stats.isValid).toBe(false);
    });

    test('should count only bullet point changes', () => {
      mockChangelogFile(validChangelog);
      const stats = service.getChangelogStats();
      const bulletCount = validChangelog
        .split('\n')
        .filter((l) => l.match(/^- /)).length;
      expect(stats.totalChanges).toBe(bulletCount);
    });
  });
});
