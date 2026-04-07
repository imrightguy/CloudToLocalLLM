/**
 * API Versioning Tests
 *
 * Tests for URL-based API versioning with backward compatibility.
 * Validates version extraction, routing, and response formatting.
 *
 * Requirements: 12.4
 */

import { jest } from "@jest/globals";
import {
  extractVersionFromPath,
  API_VERSIONS,
  DEFAULT_API_VERSION,
  apiVersioningMiddleware,
  versionRouter,
  getVersionInfoHandler,
} from "../../services/api-backend/middleware/api-versioning.js";

describe("API Versioning", () => {
  describe("extractVersionFromPath", () => {
    test("should extract v1 from path", () => {
      const version = extractVersionFromPath("/v1/users");
      expect(version).toBe("v1");
    });

    test("should extract v2 from path", () => {
      const version = extractVersionFromPath("/v2/users");
      expect(version).toBe("v2");
    });

    test("should extract version from nested path", () => {
      const version = extractVersionFromPath("/v2/users/123/profile");
      expect(version).toBe("v2");
    });

    test("should return null for path without version", () => {
      const version = extractVersionFromPath("/users");
      expect(version).toBeNull();
    });

    test("should return null for invalid version format", () => {
      const version = extractVersionFromPath("/version1/users");
      expect(version).toBeNull();
    });

    test("should handle root path", () => {
      const version = extractVersionFromPath("/");
      expect(version).toBeNull();
    });
  });

  describe("API_VERSIONS configuration", () => {
    test("should have v1 version defined", () => {
      expect(API_VERSIONS.v1).toBeDefined();
      expect(API_VERSIONS.v1.status).toBe("deprecated");
    });

    test("should have v2 version defined", () => {
      expect(API_VERSIONS.v2).toBeDefined();
      expect(API_VERSIONS.v2.status).toBe("current");
    });

    test("v1 should have sunset date", () => {
      expect(API_VERSIONS.v1.sunsetAt).toBeDefined();
    });

    test("v2 should not have sunset date", () => {
      expect(API_VERSIONS.v2.sunsetAt).toBeUndefined();
    });
  });

  describe("DEFAULT_API_VERSION", () => {
    test("should be v2", () => {
      expect(DEFAULT_API_VERSION).toBe("v2");
    });
  });

  describe("apiVersioningMiddleware", () => {
    let req, res, next;

    beforeEach(() => {
      req = {
        path: "/v2/users",
      };
      res = {
        set: jest.fn().mockReturnThis(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
      };
      next = jest.fn();
    });

    test("should extract version from path and set on request", () => {
      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      expect(req.apiVersion).toBe("v2");
      expect(req.versionInfo).toBeDefined();
      expect(next).toHaveBeenCalled();
    });

    test("should set default version when not in path", () => {
      req.path = "/users";
      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      expect(req.apiVersion).toBe(DEFAULT_API_VERSION);
      expect(next).toHaveBeenCalled();
    });

    test("should add version headers to response", () => {
      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      expect(res.set).toHaveBeenCalledWith("API-Version", "v2");
      expect(res.set).toHaveBeenCalledWith("API-Version-Status", "current");
    });

    test("should add deprecation headers for v1", () => {
      req.path = "/v1/users";
      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      expect(res.set).toHaveBeenCalledWith("Deprecation", "true");
      expect(res.set).toHaveBeenCalledWith("Sunset", expect.any(String));
      expect(res.set).toHaveBeenCalledWith(
        "Warning",
        expect.stringContaining("deprecated"),
      );
    });

    test("should reject unsupported version", () => {
      req.path = "/v99/users";
      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "UNSUPPORTED_API_VERSION",
          }),
        }),
      );
    });
  });

  describe("versionRouter", () => {
    let req, res, next;

    beforeEach(() => {
      req = {
        apiVersion: "v2",
      };
      res = {
        json: jest.fn().mockReturnThis(),
        status: jest.fn().mockReturnThis(),
      };
      next = jest.fn();
    });

    test("should route to v2 handler", () => {
      const v2Handler = jest.fn();
      const handlers = {
        v1: jest.fn(),
        v2: v2Handler,
      };

      const router = versionRouter(handlers);
      router(req, res, next);

      expect(v2Handler).toHaveBeenCalledWith(req, res, next);
    });

    test("should route to v1 handler", () => {
      req.apiVersion = "v1";
      const v1Handler = jest.fn();
      const handlers = {
        v1: v1Handler,
        v2: jest.fn(),
      };

      const router = versionRouter(handlers);
      router(req, res, next);

      expect(v1Handler).toHaveBeenCalledWith(req, res, next);
    });

    test("should return 501 for unimplemented version", () => {
      req.apiVersion = "v2";
      const handlers = {
        v1: jest.fn(),
      };

      const router = versionRouter(handlers);
      router(req, res, next);

      expect(res.status).toHaveBeenCalledWith(501);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: expect.objectContaining({
            code: "VERSION_NOT_IMPLEMENTED",
          }),
        }),
      );
    });

    test("should handle array of middleware", () => {
      const middleware1 = jest.fn((req, res, next) => next());
      const middleware2 = jest.fn();
      const handlers = {
        v2: [middleware1, middleware2],
      };

      const router = versionRouter(handlers);
      router(req, res, next);

      expect(middleware2).toHaveBeenCalledWith(req, res, next);
    });
  });

  describe("getVersionInfoHandler", () => {
    let req, res;

    beforeEach(() => {
      req = {
        apiVersion: "v2",
      };
      res = {
        json: jest.fn().mockReturnThis(),
      };
    });

    test("should return version information", () => {
      const handler = getVersionInfoHandler();
      handler(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          currentVersion: "v2",
          defaultVersion: DEFAULT_API_VERSION,
          supportedVersions: expect.any(Array),
          timestamp: expect.any(String),
        }),
      );
    });

    test("should include all supported versions", () => {
      const handler = getVersionInfoHandler();
      handler(req, res);

      const call = res.json.mock.calls[0][0];
      expect(call.supportedVersions).toHaveLength(
        Object.keys(API_VERSIONS).length,
      );
    });

    test("should include version metadata", () => {
      const handler = getVersionInfoHandler();
      handler(req, res);

      const call = res.json.mock.calls[0][0];
      expect(call.supportedVersions).toBeDefined();
      expect(call.supportedVersions.length).toBeGreaterThan(0);

      // Check that at least one version has the expected structure
      const hasVersionMetadata = call.supportedVersions.some(
        (v) => v.version && v.status && v.description,
      );
      expect(hasVersionMetadata).toBe(true);
    });
  });

  describe("Version-specific behavior", () => {
    test("v1 should be marked as deprecated", () => {
      expect(API_VERSIONS.v1.status).toBe("deprecated");
      expect(API_VERSIONS.v1.deprecatedAt).toBeDefined();
    });

    test("v2 should be marked as current", () => {
      expect(API_VERSIONS.v2.status).toBe("current");
      expect(API_VERSIONS.v2.deprecatedAt).toBeUndefined();
    });

    test("v1 should have sunset date defined", () => {
      const sunsetDate = new Date(API_VERSIONS.v1.sunsetAt);
      expect(sunsetDate).toBeInstanceOf(Date);
      expect(sunsetDate.getTime()).toBeGreaterThan(0);
    });
  });

  describe("Backward compatibility", () => {
    test("requests without version should default to v2", () => {
      const req = { path: "/users" };
      const version = extractVersionFromPath(req.path);
      expect(version).toBeNull(); // No version in path

      // Middleware should set default
      const middleware = apiVersioningMiddleware();
      const res = { set: jest.fn() };
      const next = jest.fn();

      middleware(req, res, next);
      expect(req.apiVersion).toBe(DEFAULT_API_VERSION);
    });

    test("v1 and v2 should both be accessible", () => {
      const v1Version = extractVersionFromPath("/v1/users");
      const v2Version = extractVersionFromPath("/v2/users");

      expect(v1Version).toBe("v1");
      expect(v2Version).toBe("v2");
      expect(API_VERSIONS[v1Version]).toBeDefined();
      expect(API_VERSIONS[v2Version]).toBeDefined();
    });
  });

  describe("Error handling", () => {
    test("should provide helpful error for unsupported version", () => {
      const req = { path: "/v99/users" };
      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
      };
      const next = jest.fn();

      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      const errorCall = res.json.mock.calls[0][0];
      expect(errorCall.error.suggestion).toContain("supported versions");
    });

    test("should list supported versions in error", () => {
      const req = { path: "/v99/users" };
      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
      };
      const next = jest.fn();

      const middleware = apiVersioningMiddleware();
      middleware(req, res, next);

      const errorCall = res.json.mock.calls[0][0];
      expect(errorCall.error.supportedVersions).toEqual(
        Object.keys(API_VERSIONS),
      );
    });
  });
});
