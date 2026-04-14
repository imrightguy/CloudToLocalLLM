/**
 * ChangelogService Unit Tests
 *
 * Tests for changelog parsing, version lookup, pagination,
 * format validation, and statistics.
 */

import { jest, describe, it, expect, beforeEach, beforeAll } from "@jest/globals";

const mockExistsSync = jest.fn();
const mockReadFileSync = jest.fn();

jest.unstable_mockModule("fs", () => ({
  default: {
    existsSync: mockExistsSync,
    readFileSync: mockReadFileSync,
  },
  existsSync: mockExistsSync,
  readFileSync: mockReadFileSync,
}));

const { default: ChangelogService } = await import(
  "../../services/api-backend/services/changelog-service.js"
);

const SAMPLE_CHANGELOG = `# Changelog

## [1.2.0] - 2025-04-10

### Added
- New changelog API endpoint
- Version comparison utility

### Fixed
- Fixed date parsing in release notes

## [1.1.0] - 2025-03-15

### Changed
- Updated API response format
- Improved error messages

### Security
- Patched XSS vulnerability

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core API functionality
`;

const SAMPLE_PACKAGE_JSON = JSON.stringify({ version: "1.2.0" });

describe("ChangelogService", () => {
  let service;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new ChangelogService();
  });

  function mockChangelog(content, packageJson = SAMPLE_PACKAGE_JSON) {
    mockExistsSync.mockImplementation((p) => {
      if (typeof p === "string" && p.includes("CHANGELOG")) return true;
      if (typeof p === "string" && p.includes("package.json")) return true;
      return false;
    });
    mockReadFileSync.mockImplementation((p) => {
      if (typeof p === "string" && p.includes("CHANGELOG")) return content;
      if (typeof p === "string" && p.includes("package.json")) return packageJson;
      throw new Error("Unexpected readFileSync call");
    });
  }

  describe("parseChangelog", () => {
    it("should return empty array when changelog file does not exist", () => {
      mockExistsSync.mockReturnValue(false);
      const entries = service.parseChangelog();
      expect(entries).toEqual([]);
    });

    it("should parse multiple version entries", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const entries = service.parseChangelog();
      expect(entries).toHaveLength(3);
    });

    it("should extract version numbers correctly", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const entries = service.parseChangelog();
      expect(entries[0].version).toBe("1.2.0");
      expect(entries[1].version).toBe("1.1.0");
      expect(entries[2].version).toBe("1.0.0");
    });

    it("should extract dates correctly", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const entries = service.parseChangelog();
      expect(entries[0].date).toBe("2025-04-10");
      expect(entries[1].date).toBe("2025-03-15");
    });

    it("should collect changes including section headers and bullets", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const entries = service.parseChangelog();
      const first = entries[0];
      expect(first.changes.length).toBeGreaterThan(0);
      expect(
        first.changes.some((c) => c.includes("New changelog API endpoint")),
      ).toBe(true);
    });

    it("should handle empty changelog content", () => {
      mockChangelog("# Changelog\n");
      const entries = service.parseChangelog();
      expect(entries).toEqual([]);
    });

    it("should throw on read errors", () => {
      mockExistsSync.mockReturnValue(true);
      mockReadFileSync.mockImplementation(() => {
        throw new Error("disk error");
      });
      expect(() => service.parseChangelog()).toThrow("Failed to parse changelog");
    });
  });

  describe("getLatestVersion", () => {
    it("should return the first entry", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const latest = service.getLatestVersion();
      expect(latest.version).toBe("1.2.0");
      expect(latest.date).toBe("2025-04-10");
    });

    it("should return null when no entries", () => {
      mockExistsSync.mockReturnValue(false);
      expect(service.getLatestVersion()).toBeNull();
    });
  });

  describe("getVersionByNumber", () => {
    it("should find a specific version", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const entry = service.getVersionByNumber("1.1.0");
      expect(entry).toBeDefined();
      expect(entry.version).toBe("1.1.0");
      expect(entry.date).toBe("2025-03-15");
    });

    it("should return null for nonexistent version", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      expect(service.getVersionByNumber("99.0.0")).toBeNull();
    });
  });

  describe("getAllVersions", () => {
    it("should return paginated results with defaults", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const result = service.getAllVersions();
      expect(result.total).toBe(3);
      expect(result.limit).toBe(10);
      expect(result.offset).toBe(0);
      expect(result.versions).toHaveLength(3);
    });

    it("should respect limit and offset", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const result = service.getAllVersions(1, 1);
      expect(result.total).toBe(3);
      expect(result.limit).toBe(1);
      expect(result.offset).toBe(1);
      expect(result.versions).toHaveLength(1);
      expect(result.versions[0].version).toBe("1.1.0");
    });

    it("should return empty versions for offset beyond data", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const result = service.getAllVersions(10, 100);
      expect(result.versions).toEqual([]);
    });
  });

  describe("getCurrentApiVersion", () => {
    it("should return version from package.json", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      expect(service.getCurrentApiVersion()).toBe("1.2.0");
    });

    it("should throw on read errors", () => {
      mockReadFileSync.mockImplementation(() => {
        throw new Error("no file");
      });
      expect(() => service.getCurrentApiVersion()).toThrow(
        "Failed to read package.json",
      );
    });
  });

  describe("formatChangelogEntry", () => {
    it("should format entry with changeCount", () => {
      const entry = {
        version: "1.0.0",
        date: "2025-01-01",
        changes: ["### Added", "- Feature A", "- Feature B", "### Fixed", "- Bug fix"],
      };
      const formatted = service.formatChangelogEntry(entry);
      expect(formatted.version).toBe("1.0.0");
      expect(formatted.date).toBe("2025-01-01");
      expect(formatted.changeCount).toBe(3);
      expect(formatted.changes).toHaveLength(5);
    });

    it("should count only bullet items", () => {
      const entry = {
        version: "1.0.0",
        date: "2025-01-01",
        changes: ["### Added", "not a bullet", "- actual bullet"],
      };
      const formatted = service.formatChangelogEntry(entry);
      expect(formatted.changeCount).toBe(1);
    });
  });

  describe("getReleaseNotes", () => {
    it("should return formatted release notes", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const notes = service.getReleaseNotes("1.0.0");
      expect(notes).not.toBeNull();
      expect(notes.version).toBe("1.0.0");
      expect(notes.releaseNotes).toContain("Initial release");
      expect(notes.formatted).toBeDefined();
      expect(notes.formatted.changeCount).toBe(2);
    });

    it("should return null for nonexistent version", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      expect(service.getReleaseNotes("0.0.0")).toBeNull();
    });
  });

  describe("validateChangelogFormat", () => {
    it("should return true for valid changelog", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      expect(service.validateChangelogFormat()).toBe(true);
    });

    it("should return false for empty changelog", () => {
      mockExistsSync.mockReturnValue(false);
      expect(service.validateChangelogFormat()).toBe(false);
    });

    it("should return false for invalid version format", () => {
      mockChangelog("## [abc] - 2025-01-01\n\n### Added\n- Something\n");
      expect(service.validateChangelogFormat()).toBe(false);
    });

    it("should return false for invalid date", () => {
      mockChangelog("## [1.0.0] - not-a-date\n\n### Added\n- Something\n");
      expect(service.validateChangelogFormat()).toBe(false);
    });
  });

  describe("getChangelogStats", () => {
    it("should return correct statistics", () => {
      mockChangelog(SAMPLE_CHANGELOG);
      const stats = service.getChangelogStats();
      expect(stats.totalVersions).toBe(3);
      expect(stats.latestVersion).toBe("1.2.0");
      expect(stats.oldestVersion).toBe("1.0.0");
      expect(stats.totalChanges).toBeGreaterThan(0);
      expect(stats.isValid).toBe(true);
    });

    it("should handle empty changelog", () => {
      mockExistsSync.mockReturnValue(false);
      const stats = service.getChangelogStats();
      expect(stats.totalVersions).toBe(0);
      expect(stats.latestVersion).toBeNull();
      expect(stats.oldestVersion).toBeNull();
      expect(stats.totalChanges).toBe(0);
      expect(stats.isValid).toBe(false);
    });
  });
});
