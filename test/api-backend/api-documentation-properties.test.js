/**


 * API Documentation Consistency Property-Based Tests
 *
 * Property 15: API documentation consistency
 * Validates: Requirements 12.1, 12.2
 *
 * Property: For any API endpoint documented in the changelog, the documentation
 * should be consistent and complete across all versions.
 *
 * Feature: api-backend-enhancement, Property 15: API documentation consistency
 */

import { describe, it, expect } from "@jest/globals";
import ChangelogService from "../../services/api-backend/services/changelog-service.js";

describe("Property 15: API Documentation Consistency", () => {
  const changelogService = new ChangelogService();

  /**
   * Property: For any changelog entry, the version should follow semantic versioning
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain semantic versioning consistency across all versions", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        // Version should match semantic versioning pattern (X.Y.Z)
        expect(entry.version).toMatch(/^\d+\.\d+\.\d+/);

        // Extract version parts
        const parts = entry.version.split(".");
        expect(parts.length).toBeGreaterThanOrEqual(3);

        // Each part should be a valid number
        parts.slice(0, 3).forEach((part) => {
          expect(parseInt(part)).toBeGreaterThanOrEqual(0);
          expect(isNaN(parseInt(part))).toBe(false);
        });
      });
    }
  });

  /**
   * Property: For any changelog entry, the date should be a valid ISO date
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain valid date format consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        // Date should be parseable
        const dateObj = new Date(entry.date);
        expect(isNaN(dateObj.getTime())).toBe(false);

        // Date should be in the past or today
        expect(dateObj.getTime()).toBeLessThanOrEqual(Date.now());
      });
    }
  });

  /**
   * Property: For any changelog entry, changes should be an array of strings
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain consistent change format", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        // Changes should be an array
        expect(Array.isArray(entry.changes)).toBe(true);

        // Each change should be a string
        entry.changes.forEach((change) => {
          expect(typeof change).toBe("string");
        });
      });
    }
  });

  /**
   * Property: For any two consecutive versions, the version numbers should be ordered
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain version ordering consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      for (let i = 0; i < entries.length - 1; i++) {
        const current = entries[i].version;
        const next = entries[i + 1].version;

        // Parse versions
        const currentParts = current.split(".").map((p) => parseInt(p));
        const nextParts = next.split(".").map((p) => parseInt(p));

        // Current should be >= next (descending order)
        let isGreaterOrEqual = false;

        if (currentParts[0] > nextParts[0]) {
          isGreaterOrEqual = true;
        } else if (currentParts[0] === nextParts[0]) {
          if (currentParts[1] > nextParts[1]) {
            isGreaterOrEqual = true;
          } else if (currentParts[1] === nextParts[1]) {
            if (currentParts[2] >= nextParts[2]) {
              isGreaterOrEqual = true;
            }
          }
        }

        expect(isGreaterOrEqual).toBe(true);
      }
    }
  });

  /**
   * Property: For any changelog entry, the formatted entry should contain all required fields
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain formatted entry consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        const formatted = changelogService.formatChangelogEntry(entry);

        // Should have all required fields
        expect(formatted).toHaveProperty("version");
        expect(formatted).toHaveProperty("date");
        expect(formatted).toHaveProperty("changes");
        expect(formatted).toHaveProperty("changeCount");

        // changeCount should match actual changes count
        const actualCount = entry.changes.filter((c) =>
          c.match(/^-\s+/),
        ).length;
        expect(formatted.changeCount).toBe(actualCount);
      });
    }
  });

  /**
   * Property: For any changelog, the validation should be consistent
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain changelog validation consistency", () => {
    for (let run = 0; run < 20; run++) {
      const isValid = changelogService.validateChangelogFormat();

      // If valid, should have entries
      if (isValid) {
        const entries = changelogService.parseChangelog();
        expect(entries.length).toBeGreaterThan(0);
      }

      // Validation should be boolean
      expect(typeof isValid).toBe("boolean");
    }
  });

  /**
   * Property: For any changelog stats, the totals should be consistent with parsed entries
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain changelog statistics consistency", () => {
    for (let run = 0; run < 20; run++) {
      const stats = changelogService.getChangelogStats();
      const entries = changelogService.parseChangelog();

      // Total versions should match
      expect(stats.totalVersions).toBe(entries.length);

      // Latest version should match first entry
      if (entries.length > 0) {
        expect(stats.latestVersion).toBe(entries[0].version);
      } else {
        expect(stats.latestVersion).toBeNull();
      }

      // Oldest version should match last entry
      if (entries.length > 0) {
        expect(stats.oldestVersion).toBe(entries[entries.length - 1].version);
      } else {
        expect(stats.oldestVersion).toBeNull();
      }

      // Total changes should be sum of all changes
      const expectedTotal = entries.reduce((sum, entry) => {
        return sum + entry.changes.filter((c) => c.match(/^-\s+/)).length;
      }, 0);
      expect(stats.totalChanges).toBe(expectedTotal);

      // isValid should match validation
      expect(stats.isValid).toBe(changelogService.validateChangelogFormat());
    }
  });

  /**
   * Property: For any version retrieval, the result should be consistent with parsed entries
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain version retrieval consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        const retrieved = changelogService.getVersionByNumber(entry.version);

        // Should retrieve the same entry
        expect(retrieved).not.toBeNull();
        expect(retrieved.version).toBe(entry.version);
        expect(retrieved.date).toBe(entry.date);
      });
    }
  });

  /**
   * Property: For any pagination request, the results should be consistent
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain pagination consistency", () => {
    for (let run = 0; run < 20; run++) {
      const allEntries = changelogService.parseChangelog();
      const limit = Math.floor(Math.random() * 10) + 1;
      const offset = Math.floor(
        Math.random() * Math.max(1, allEntries.length - limit),
      );

      const result = changelogService.getAllVersions(limit, offset);

      // Total should match parsed entries
      expect(result.total).toBe(allEntries.length);

      // Limit and offset should match request
      expect(result.limit).toBe(limit);
      expect(result.offset).toBe(offset);

      // Returned versions should match sliced entries
      const expectedVersions = allEntries.slice(offset, offset + limit);
      expect(result.versions.length).toBe(expectedVersions.length);

      result.versions.forEach((version, index) => {
        expect(version.version).toBe(expectedVersions[index].version);
      });
    }
  });

  /**
   * Property: For any release notes retrieval, the result should be consistent
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain release notes consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        const releaseNotes = changelogService.getReleaseNotes(entry.version);

        // Should retrieve release notes
        expect(releaseNotes).not.toBeNull();
        expect(releaseNotes.version).toBe(entry.version);
        expect(releaseNotes.date).toBe(entry.date);

        // Release notes should contain changes
        expect(releaseNotes.releaseNotes).toContain(entry.changes.join("\n"));
      });
    }
  });

  /**
   * Property: For any latest version retrieval, the result should be the first entry
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain latest version consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();
      const latest = changelogService.getLatestVersion();

      if (entries.length > 0) {
        expect(latest).not.toBeNull();
        expect(latest.version).toBe(entries[0].version);
        expect(latest.date).toBe(entries[0].date);
      } else {
        expect(latest).toBeNull();
      }
    }
  });

  /**
   * Property: For any changelog entry, the changes array should not contain duplicates
   *
   * Validates: Requirements 12.1, 12.2
   */
  it("should maintain change uniqueness consistency", () => {
    for (let run = 0; run < 20; run++) {
      const entries = changelogService.parseChangelog();

      entries.forEach((entry) => {
        const changes = entry.changes.filter((c) => c.match(/^-\s+/));
        const uniqueChanges = new Set(changes);

        // All changes should be unique (no duplicates)
        expect(uniqueChanges.size).toBe(changes.length);
      });
    }
  });
});
