/**
 * DeprecationService Unit Tests
 *
 * Tests for deprecation info lookup, status checks, migration guides,
 * warning formatting, headers, and status reports.
 */

import { jest, describe, it, expect } from "@jest/globals";

const {
  DeprecationStatus,
  DEPRECATED_ENDPOINTS,
  MIGRATION_GUIDES,
  getDeprecationInfo,
  isDeprecated,
  isSunset,
  getMigrationGuide,
  formatDeprecationWarning,
  getDeprecationHeaders,
  getAllDeprecatedEndpoints,
  getAllSunsetEndpoints,
  getDeprecationStatusReport,
} = await import(
  "../../services/api-backend/services/deprecation-service.js"
);

describe("DeprecationService", () => {
  describe("DeprecationStatus enum", () => {
    it("should have ACTIVE status", () => {
      expect(DeprecationStatus.ACTIVE).toBe("active");
    });

    it("should have DEPRECATED status", () => {
      expect(DeprecationStatus.DEPRECATED).toBe("deprecated");
    });

    it("should have SUNSET status", () => {
      expect(DeprecationStatus.SUNSET).toBe("sunset");
    });

    it("should have exactly 3 statuses", () => {
      expect(Object.keys(DeprecationStatus)).toHaveLength(3);
    });
  });

  describe("DEPRECATED_ENDPOINTS registry", () => {
    it("should contain v1 users endpoint", () => {
      expect(DEPRECATED_ENDPOINTS["/v1/users"]).toBeDefined();
    });

    it("should contain v1 tunnels endpoint", () => {
      expect(DEPRECATED_ENDPOINTS["/v1/tunnels"]).toBeDefined();
    });

    it("should contain v1 auth endpoint", () => {
      expect(DEPRECATED_ENDPOINTS["/v1/auth"]).toBeDefined();
    });

    it("should contain v1 admin endpoint", () => {
      expect(DEPRECATED_ENDPOINTS["/v1/admin"]).toBeDefined();
    });

    it("should have all v1 endpoints with DEPRECATED status", () => {
      const v1Endpoints = Object.entries(DEPRECATED_ENDPOINTS).filter(([path]) =>
        path.startsWith("/v1/")
      );
      for (const [, info] of v1Endpoints) {
        expect(info.status).toBe(DeprecationStatus.DEPRECATED);
      }
    });

    it("should have replacedBy for all deprecated endpoints", () => {
      for (const [, info] of Object.entries(DEPRECATED_ENDPOINTS)) {
        if (info.status === DeprecationStatus.DEPRECATED) {
          expect(info.replacedBy).toBeDefined();
          expect(info.replacedBy).toBeTruthy();
        }
      }
    });

    it("should have sunsetAt after deprecatedAt for all entries", () => {
      for (const [, info] of Object.entries(DEPRECATED_ENDPOINTS)) {
        expect(new Date(info.sunsetAt).getTime()).toBeGreaterThan(
          new Date(info.deprecatedAt).getTime()
        );
      }
    });

    it("should have migrationGuide for all v1 endpoints", () => {
      for (const [path, info] of Object.entries(DEPRECATED_ENDPOINTS)) {
        if (path.startsWith("/v1/")) {
          expect(info.migrationGuide).toBeDefined();
        }
      }
    });
  });

  describe("MIGRATION_GUIDES", () => {
    it("should contain MIGRATION_V1_TO_V2", () => {
      expect(MIGRATION_GUIDES.MIGRATION_V1_TO_V2).toBeDefined();
    });

    it("should have a title", () => {
      expect(MIGRATION_GUIDES.MIGRATION_V1_TO_V2.title).toBeTruthy();
    });

    it("should have a description", () => {
      expect(MIGRATION_GUIDES.MIGRATION_V1_TO_V2.description).toBeTruthy();
    });

    it("should have migration steps", () => {
      const steps = MIGRATION_GUIDES.MIGRATION_V1_TO_V2.steps;
      expect(Array.isArray(steps)).toBe(true);
      expect(steps.length).toBeGreaterThan(0);
    });

    it("should have steps with sequential numbering starting at 1", () => {
      const steps = MIGRATION_GUIDES.MIGRATION_V1_TO_V2.steps;
      steps.forEach((step, index) => {
        expect(step.step).toBe(index + 1);
        expect(step.title).toBeTruthy();
      });
    });

    it("should have resources with documentation links", () => {
      const resources = MIGRATION_GUIDES.MIGRATION_V1_TO_V2.resources;
      expect(resources).toBeDefined();
      expect(resources.documentation).toBeTruthy();
      expect(resources.apiDocs).toBeTruthy();
    });

    it("should have timeline with sunset date", () => {
      const timeline = MIGRATION_GUIDES.MIGRATION_V1_TO_V2.timeline;
      expect(timeline).toBeDefined();
      expect(timeline.deprecatedAt).toBe("2024-01-01");
      expect(timeline.sunsetAt).toBe("2027-01-01");
    });

    it("should have positive daysUntilSunset", () => {
      const timeline = MIGRATION_GUIDES.MIGRATION_V1_TO_V2.timeline;
      expect(timeline.daysUntilSunset).toBeGreaterThan(0);
    });
  });

  describe("getDeprecationInfo", () => {
    it("should return info for exact match /v1/users", () => {
      const info = getDeprecationInfo("/v1/users");
      expect(info).toBeDefined();
      expect(info.status).toBe(DeprecationStatus.DEPRECATED);
    });

    it("should return info for exact match /v1/tunnels", () => {
      const info = getDeprecationInfo("/v1/tunnels");
      expect(info).toBeDefined();
      expect(info.replacedBy).toBe("/v2/tunnels");
    });

    it("should return info for prefix match /v1/users/123", () => {
      const info = getDeprecationInfo("/v1/users/123");
      expect(info).toBeDefined();
      expect(info.replacedBy).toBe("/v2/users");
    });

    it("should return info for prefix match /v1/auth/login", () => {
      const info = getDeprecationInfo("/v1/auth/login");
      expect(info).toBeDefined();
    });

    it("should return null for non-deprecated endpoint", () => {
      const info = getDeprecationInfo("/v2/users");
      expect(info).toBeNull();
    });

    it("should return null for unknown endpoint", () => {
      const info = getDeprecationInfo("/v3/something");
      expect(info).toBeNull();
    });

    it("should return null for root path", () => {
      const info = getDeprecationInfo("/");
      expect(info).toBeNull();
    });

    it("should return null for empty string", () => {
      const info = getDeprecationInfo("");
      expect(info).toBeNull();
    });
  });

  describe("isDeprecated", () => {
    it("should return true for /v1/users", () => {
      expect(isDeprecated("/v1/users")).toBe(true);
    });

    it("should return true for /v1/tunnels", () => {
      expect(isDeprecated("/v1/tunnels")).toBe(true);
    });

    it("should return true for sub-paths like /v1/users/123", () => {
      expect(isDeprecated("/v1/users/123")).toBe(true);
    });

    it("should return false for v2 endpoints", () => {
      expect(isDeprecated("/v2/users")).toBe(false);
    });

    it("should return false for unknown path", () => {
      expect(isDeprecated("/api/health")).toBe(false);
    });
  });

  describe("isSunset", () => {
    it("should return false for endpoints with future sunset date", () => {
      expect(isSunset("/v1/users")).toBe(false);
    });

    it("should return false for non-deprecated endpoints", () => {
      expect(isSunset("/v2/users")).toBe(false);
    });

    it("should return false for unknown path", () => {
      expect(isSunset("/unknown")).toBe(false);
    });
  });

  describe("getMigrationGuide", () => {
    it("should return migration guide for /v1/users", () => {
      const guide = getMigrationGuide("/v1/users");
      expect(guide).toBeDefined();
      expect(guide.title).toContain("v1 to v2");
    });

    it("should return migration guide for /v1/auth", () => {
      const guide = getMigrationGuide("/v1/auth");
      expect(guide).toBeDefined();
    });

    it("should return null for non-deprecated path", () => {
      expect(getMigrationGuide("/v2/users")).toBeNull();
    });

    it("should return null for unknown path", () => {
      expect(getMigrationGuide("/unknown")).toBeNull();
    });
  });

  describe("formatDeprecationWarning", () => {
    it("should include the path in warning", () => {
      const warning = formatDeprecationWarning("/v1/users");
      expect(warning).toContain("/v1/users");
      expect(warning).toContain("deprecated");
    });

    it("should include sunset date", () => {
      const warning = formatDeprecationWarning("/v1/users");
      expect(warning).toContain("2027-01-01");
    });

    it("should include days until sunset", () => {
      const warning = formatDeprecationWarning("/v1/users");
      expect(warning).toMatch(/\d+ days/);
    });

    it("should include replacement suggestion", () => {
      const warning = formatDeprecationWarning("/v1/users");
      expect(warning).toContain("/v2/users");
      expect(warning).toContain("instead");
    });

    it("should return empty string for non-deprecated path", () => {
      expect(formatDeprecationWarning("/v2/users")).toBe("");
    });

    it("should return empty string for unknown path", () => {
      expect(formatDeprecationWarning("/unknown")).toBe("");
    });
  });

  describe("getDeprecationHeaders", () => {
    it("should return Deprecation header set to true", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers.Deprecation).toBe("true");
    });

    it("should return Sunset header as UTC string", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers.Sunset).toBeDefined();
      expect(headers.Sunset).toContain("2027");
    });

    it("should return Warning header with 299 status", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers.Warning).toContain("299");
    });

    it("should return Deprecation-Link header for replaced endpoints", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers["Deprecation-Link"]).toBe("/v2/users");
    });

    it("should return empty object for non-deprecated path", () => {
      const headers = getDeprecationHeaders("/v2/users");
      expect(headers).toEqual({});
    });

    it("should return empty object for unknown path", () => {
      const headers = getDeprecationHeaders("/unknown");
      expect(headers).toEqual({});
    });

    it("should not have Deprecation-Link if replacedBy is missing", () => {
      const headers = getDeprecationHeaders("/v1/admin");
      expect(headers["Deprecation-Link"]).toBe("/v2/admin");
    });
  });

  describe("getAllDeprecatedEndpoints", () => {
    it("should return an array", () => {
      const endpoints = getAllDeprecatedEndpoints();
      expect(Array.isArray(endpoints)).toBe(true);
    });

    it("should return all v1 deprecated endpoints", () => {
      const endpoints = getAllDeprecatedEndpoints();
      expect(endpoints.length).toBeGreaterThanOrEqual(4);
    });

    it("should include path in each entry", () => {
      const endpoints = getAllDeprecatedEndpoints();
      for (const entry of endpoints) {
        expect(entry.path).toBeDefined();
        expect(entry.path).toMatch(/^\/v1\//);
      }
    });

    it("should include daysUntilSunset in each entry", () => {
      const endpoints = getAllDeprecatedEndpoints();
      for (const entry of endpoints) {
        expect(entry.daysUntilSunset).toBeDefined();
        expect(typeof entry.daysUntilSunset).toBe("number");
        expect(entry.daysUntilSunset).toBeGreaterThan(0);
      }
    });

    it("should only include DEPRECATED status entries", () => {
      const endpoints = getAllDeprecatedEndpoints();
      for (const entry of endpoints) {
        expect(entry.status).toBe(DeprecationStatus.DEPRECATED);
      }
    });
  });

  describe("getAllSunsetEndpoints", () => {
    it("should return an array", () => {
      const endpoints = getAllSunsetEndpoints();
      expect(Array.isArray(endpoints)).toBe(true);
    });

    it("should return empty array since no endpoints are sunset yet", () => {
      const endpoints = getAllSunsetEndpoints();
      expect(endpoints.length).toBe(0);
    });
  });

  describe("getDeprecationStatusReport", () => {
    it("should return a report object", () => {
      const report = getDeprecationStatusReport();
      expect(report).toBeDefined();
      expect(typeof report).toBe("object");
    });

    it("should include timestamp as ISO string", () => {
      const report = getDeprecationStatusReport();
      expect(report.timestamp).toBeDefined();
      expect(typeof report.timestamp).toBe("string");
      expect(() => new Date(report.timestamp)).not.toThrow();
    });

    it("should include deprecatedEndpoints array", () => {
      const report = getDeprecationStatusReport();
      expect(Array.isArray(report.deprecatedEndpoints)).toBe(true);
    });

    it("should include sunsetEndpoints array", () => {
      const report = getDeprecationStatusReport();
      expect(Array.isArray(report.sunsetEndpoints)).toBe(true);
    });

    it("should include totalDeprecated count", () => {
      const report = getDeprecationStatusReport();
      expect(typeof report.totalDeprecated).toBe("number");
      expect(report.totalDeprecated).toBe(report.deprecatedEndpoints.length);
    });

    it("should include totalSunset count", () => {
      const report = getDeprecationStatusReport();
      expect(typeof report.totalSunset).toBe("number");
      expect(report.totalSunset).toBe(report.sunsetEndpoints.length);
    });

    it("should have consistent counts", () => {
      const report = getDeprecationStatusReport();
      expect(report.totalDeprecated).toBeGreaterThanOrEqual(4);
      expect(report.totalSunset).toBe(0);
    });
  });
});
