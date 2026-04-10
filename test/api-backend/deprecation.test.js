/**


 * API Deprecation Tests
 *
 * Tests for deprecation service, middleware, and routes.
 * Validates deprecation headers, migration guides, and sunset enforcement.
 *
 * Requirements: 12.5
 */

import { describe, it, expect, beforeEach } from "@jest/globals";
import express from "express";
import request from "supertest";
import {
  getDeprecationInfo,
  isDeprecated,
  isSunset,
  getMigrationGuide,
  formatDeprecationWarning,
  getDeprecationHeaders,
  getAllDeprecatedEndpoints,
  getDeprecationStatusReport,
} from "../../services/api-backend/services/deprecation-service.js";
import {
  deprecationMiddleware,
  deprecationWarningMiddleware,
  deprecationResponseMiddleware,
} from "../../services/api-backend/middleware/deprecation-middleware.js";
import deprecationRoutes from "../../services/api-backend/routes/deprecation.js";

describe("Deprecation Service", () => {
  describe("getDeprecationInfo", () => {
    it("should return deprecation info for deprecated endpoint", () => {
      const info = getDeprecationInfo("/v1/users");
      expect(info).toBeDefined();
      expect(info.status).toBe("deprecated");
      expect(info.replacedBy).toBe("/v2/users");
    });

    it("should return null for non-deprecated endpoint", () => {
      const info = getDeprecationInfo("/v2/users");
      expect(info).toBeNull();
    });

    it("should handle prefix matching", () => {
      const info = getDeprecationInfo("/v1/users/123");
      expect(info).toBeDefined();
      expect(info.status).toBe("deprecated");
    });
  });

  describe("isDeprecated", () => {
    it("should return true for deprecated endpoint", () => {
      expect(isDeprecated("/v1/users")).toBe(true);
      expect(isDeprecated("/v1/tunnels")).toBe(true);
      expect(isDeprecated("/v1/auth")).toBe(true);
    });

    it("should return false for non-deprecated endpoint", () => {
      expect(isDeprecated("/v2/users")).toBe(false);
      expect(isDeprecated("/v2/tunnels")).toBe(false);
    });
  });

  describe("isSunset", () => {
    it("should return false for deprecated but not sunset endpoint", () => {
      // v1 endpoints are deprecated but not yet sunset
      expect(isSunset("/v1/users")).toBe(false);
    });

    it("should return false for non-deprecated endpoint", () => {
      expect(isSunset("/v2/users")).toBe(false);
    });
  });

  describe("getMigrationGuide", () => {
    it("should return migration guide for deprecated endpoint", () => {
      const guide = getMigrationGuide("/v1/users");
      expect(guide).toBeDefined();
      expect(guide.title).toBe("Migrating from API v1 to v2");
      expect(guide.steps).toBeDefined();
      expect(guide.steps.length).toBeGreaterThan(0);
    });

    it("should return null for non-deprecated endpoint", () => {
      const guide = getMigrationGuide("/v2/users");
      expect(guide).toBeNull();
    });

    it("should include migration steps", () => {
      const guide = getMigrationGuide("/v1/users");
      expect(guide.steps).toContainEqual(
        expect.objectContaining({
          step: 1,
          title: "Update Base URL",
        }),
      );
    });

    it("should include resources in migration guide", () => {
      const guide = getMigrationGuide("/v1/users");
      expect(guide.resources).toBeDefined();
      expect(guide.resources.documentation).toBeDefined();
      expect(guide.resources.support).toBeDefined();
    });
  });

  describe("formatDeprecationWarning", () => {
    it("should format deprecation warning message", () => {
      const warning = formatDeprecationWarning("/v1/users");
      expect(warning).toContain("/v1/users");
      expect(warning).toContain("deprecated");
      expect(warning).toContain("2027-01-01");
      expect(warning).toContain("/v2/users");
    });

    it("should return empty string for non-deprecated endpoint", () => {
      const warning = formatDeprecationWarning("/v2/users");
      expect(warning).toBe("");
    });
  });

  describe("getDeprecationHeaders", () => {
    it("should return deprecation headers for deprecated endpoint", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers.Deprecation).toBe("true");
      expect(headers.Sunset).toBeDefined();
      expect(headers.Warning).toBeDefined();
      expect(headers["Deprecation-Link"]).toBe("/v2/users");
    });

    it("should return empty object for non-deprecated endpoint", () => {
      const headers = getDeprecationHeaders("/v2/users");
      expect(Object.keys(headers).length).toBe(0);
    });

    it("should include sunset date in RFC format", () => {
      const headers = getDeprecationHeaders("/v1/users");
      expect(headers.Sunset).toMatch(/\d{1,2} \w{3} \d{4}/);
    });
  });

  describe("getAllDeprecatedEndpoints", () => {
    it("should return array of deprecated endpoints", () => {
      const endpoints = getAllDeprecatedEndpoints();
      expect(Array.isArray(endpoints)).toBe(true);
      expect(endpoints.length).toBeGreaterThan(0);
    });

    it("should include required fields", () => {
      const endpoints = getAllDeprecatedEndpoints();
      endpoints.forEach((endpoint) => {
        expect(endpoint.path).toBeDefined();
        expect(endpoint.status).toBe("deprecated");
        expect(endpoint.sunsetAt).toBeDefined();
        expect(endpoint.replacedBy).toBeDefined();
        expect(endpoint.daysUntilSunset).toBeDefined();
      });
    });
  });

  describe("getDeprecationStatusReport", () => {
    it("should return deprecation status report", () => {
      const report = getDeprecationStatusReport();
      expect(report.timestamp).toBeDefined();
      expect(report.deprecatedEndpoints).toBeDefined();
      expect(report.sunsetEndpoints).toBeDefined();
      expect(report.totalDeprecated).toBeGreaterThan(0);
      expect(report.totalSunset).toBeGreaterThanOrEqual(0);
    });

    it("should include all deprecated endpoints", () => {
      const report = getDeprecationStatusReport();
      expect(report.deprecatedEndpoints.length).toBe(report.totalDeprecated);
    });
  });
});

describe("Deprecation Middleware", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(deprecationMiddleware());
    app.use(deprecationWarningMiddleware());
    app.use(deprecationResponseMiddleware());

    // Test routes
    app.get("/v1/users", (req, res) => {
      res.json({ user: { id: "123", email: "test@example.com" } });
    });

    app.get("/v2/users", (req, res) => {
      res.json({ user: { id: "123", email: "test@example.com" } });
    });
  });

  describe("deprecationMiddleware", () => {
    it("should add deprecation headers to deprecated endpoint response", async () => {
      const response = await request(app).get("/v1/users");
      expect(response.headers.deprecation).toBe("true");
      expect(response.headers.sunset).toBeDefined();
      expect(response.headers.warning).toBeDefined();
    });

    it("should not add deprecation headers to current endpoint", async () => {
      const response = await request(app).get("/v2/users");
      expect(response.headers.deprecation).toBeUndefined();
      expect(response.headers.sunset).toBeUndefined();
    });

    it("should include deprecation link header", async () => {
      const response = await request(app).get("/v1/users");
      expect(response.headers["deprecation-link"]).toBe("/v2/users");
    });
  });

  describe("deprecationResponseMiddleware", () => {
    it("should include deprecation info in response body", async () => {
      const response = await request(app).get("/v1/users");
      expect(response.body._deprecation).toBeDefined();
      expect(response.body._deprecation.deprecated).toBe(true);
      expect(response.body._deprecation.replacedBy).toBe("/v2/users");
      expect(response.body._deprecation.sunsetAt).toBeDefined();
    });

    it("should include migration guide in response", async () => {
      const response = await request(app).get("/v1/users");
      expect(response.body._deprecation.migrationGuide).toBeDefined();
      expect(response.body._deprecation.migrationGuide.title).toBeDefined();
      expect(response.body._deprecation.migrationGuide.steps).toBeDefined();
    });

    it("should not include deprecation info for current endpoint", async () => {
      const response = await request(app).get("/v2/users");
      expect(response.body._deprecation).toBeUndefined();
    });
  });
});

describe("Deprecation Routes", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.use("/api/deprecation", deprecationRoutes);
  });

  describe("GET /api/deprecation/status", () => {
    it("should return deprecation status report", async () => {
      const response = await request(app).get("/api/deprecation/status");
      expect(response.status).toBe(200);
      expect(response.body.timestamp).toBeDefined();
      expect(response.body.deprecatedEndpoints).toBeDefined();
      expect(response.body.sunsetEndpoints).toBeDefined();
      expect(response.body.totalDeprecated).toBeGreaterThan(0);
    });
  });

  describe("GET /api/deprecation/deprecated", () => {
    it("should return list of deprecated endpoints", async () => {
      const response = await request(app).get("/api/deprecation/deprecated");
      expect(response.status).toBe(200);
      expect(response.body.endpoints).toBeDefined();
      expect(Array.isArray(response.body.endpoints)).toBe(true);
      expect(response.body.count).toBeGreaterThan(0);
    });

    it("should include required fields in endpoints", async () => {
      const response = await request(app).get("/api/deprecation/deprecated");
      response.body.endpoints.forEach((endpoint) => {
        expect(endpoint.path).toBeDefined();
        expect(endpoint.status).toBe("deprecated");
        expect(endpoint.sunsetAt).toBeDefined();
        expect(endpoint.replacedBy).toBeDefined();
      });
    });
  });

  describe("GET /api/deprecation/sunset", () => {
    it("should return list of sunset endpoints", async () => {
      const response = await request(app).get("/api/deprecation/sunset");
      expect(response.status).toBe(200);
      expect(response.body.endpoints).toBeDefined();
      expect(Array.isArray(response.body.endpoints)).toBe(true);
      expect(response.body.count).toBeGreaterThanOrEqual(0);
    });
  });

  describe("GET /api/deprecation/endpoint-info", () => {
    it("should return endpoint deprecation info", async () => {
      const response = await request(app)
        .get("/api/deprecation/endpoint-info")
        .query({ path: "/v1/users" });
      expect(response.status).toBe(200);
      expect(response.body.path).toBe("/v1/users");
      expect(response.body.status).toBe("deprecated");
      expect(response.body.replacedBy).toBe("/v2/users");
    });

    it("should return 404 for non-deprecated endpoint", async () => {
      const response = await request(app)
        .get("/api/deprecation/endpoint-info")
        .query({ path: "/v2/users" });
      expect(response.status).toBe(404);
      expect(response.body.error.code).toBe("ENDPOINT_NOT_DEPRECATED");
    });

    it("should return 400 if path parameter is missing", async () => {
      const response = await request(app).get("/api/deprecation/endpoint-info");
      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe("MISSING_PATH_PARAMETER");
    });

    it("should include migration guide in response", async () => {
      const response = await request(app)
        .get("/api/deprecation/endpoint-info")
        .query({ path: "/v1/users" });
      expect(response.body.migrationGuide).toBeDefined();
      expect(response.body.migrationGuide.title).toBeDefined();
    });
  });

  describe("GET /api/deprecation/migration-guide/:guideId", () => {
    it("should return migration guide", async () => {
      const response = await request(app).get(
        "/api/deprecation/migration-guide/MIGRATION_V1_TO_V2",
      );
      expect(response.status).toBe(200);
      expect(response.body.title).toBe("Migrating from API v1 to v2");
      expect(response.body.steps).toBeDefined();
      expect(response.body.resources).toBeDefined();
    });

    it("should include migration steps", async () => {
      const response = await request(app).get(
        "/api/deprecation/migration-guide/MIGRATION_V1_TO_V2",
      );
      expect(response.body.steps.length).toBeGreaterThan(0);
      response.body.steps.forEach((step) => {
        expect(step.step).toBeDefined();
        expect(step.title).toBeDefined();
        expect(step.description).toBeDefined();
      });
    });

    it("should include resources in migration guide", async () => {
      const response = await request(app).get(
        "/api/deprecation/migration-guide/MIGRATION_V1_TO_V2",
      );
      expect(response.body.resources.documentation).toBeDefined();
      expect(response.body.resources.support).toBeDefined();
    });

    it("should include timeline in migration guide", async () => {
      const response = await request(app).get(
        "/api/deprecation/migration-guide/MIGRATION_V1_TO_V2",
      );
      expect(response.body.timeline).toBeDefined();
      expect(response.body.timeline.deprecatedAt).toBeDefined();
      expect(response.body.timeline.sunsetAt).toBeDefined();
      expect(response.body.timeline.daysUntilSunset).toBeDefined();
    });
  });
});
