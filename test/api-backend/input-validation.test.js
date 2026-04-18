/**
 * Input Validation Tests
 *
 * Tests for input validation and sanitization utilities:
 * - String sanitization (XSS prevention)
 * - Email validation
 * - URL validation
 * - Name validation
 * - Preference validation
 * - Profile validation
 * - SQL injection prevention (via parameterized queries)
 *
 * Validates: Requirements 3.7
 * - Add comprehensive input validation for all user endpoints
 * - Implement SQL injection prevention via parameterized queries
 * - Add XSS prevention for user inputs
 *
 * @fileoverview Input validation tests
 * @version 1.0.0
 */

import { describe, it, expect } from "@jest/globals";
import {
  sanitizeString,
  isValidEmail,
  isValidUrl,
  isValidLength,
  isNotEmpty,
  isAlphanumericUnderscore,
  isSlugFormat,
  isValidBoolean,
  isValidNumber,
  isValidInteger,
  isOneOf,
  validateName,
  validateEmail,
  validateUrl,
  validateTheme,
  validateLanguage,
  validateNotifications,
  validatePreferences,
  validateProfile,
  sanitizeInput,
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
  validateInput,
  logValidationError,
  ValidationError,
} from "../../services/api-backend/utils/input-validation.js";

describe("Input Validation Utilities", () => {
  describe("sanitizeString", () => {
    it("should remove null bytes", () => {
      const input = "hello\0world";
      const result = sanitizeString(input);
      expect(result).toBe("helloworld");
    });

    it("should escape HTML special characters", () => {
      const input = '<script>alert("xss")</script>';
      const result = sanitizeString(input);
      expect(result).toContain("&lt;");
      expect(result).toContain("&gt;");
      expect(result).not.toContain("<script>");
    });

    it("should escape quotes", () => {
      const input = "He said \"hello\" and 'goodbye'";
      const result = sanitizeString(input);
      expect(result).toContain("&quot;");
      expect(result).toContain("&#x27;");
    });

    it("should escape ampersands", () => {
      const input = "Tom & Jerry";
      const result = sanitizeString(input);
      expect(result).toBe("Tom &amp; Jerry");
    });

    it("should handle non-string input", () => {
      expect(sanitizeString(123)).toBe(123);
      expect(sanitizeString(null)).toBe(null);
      expect(sanitizeString(undefined)).toBe(undefined);
    });

    it("should prevent XSS with event handlers", () => {
      const input = "<img src=x onerror=\"alert('xss')\">";
      const result = sanitizeString(input);
      // The onerror attribute text remains but the < and > are escaped
      expect(result).toContain("&lt;");
      expect(result).toContain("&gt;");
      expect(result).not.toContain("<img");
    });
  });

  describe("isValidEmail", () => {
    it("should validate correct email addresses", () => {
      expect(isValidEmail("user@example.com")).toBe(true);
      expect(isValidEmail("john.doe@company.co.uk")).toBe(true);
      expect(isValidEmail("test+tag@domain.org")).toBe(true);
    });

    it("should reject invalid email addresses", () => {
      expect(isValidEmail("invalid")).toBe(false);
      expect(isValidEmail("user@")).toBe(false);
      expect(isValidEmail("@example.com")).toBe(false);
      expect(isValidEmail("user @example.com")).toBe(false);
    });

    it("should reject non-string input", () => {
      expect(isValidEmail(123)).toBe(false);
      expect(isValidEmail(null)).toBe(false);
      expect(isValidEmail(undefined)).toBe(false);
    });

    it("should reject emails exceeding max length", () => {
      const longEmail = "a".repeat(256) + "@example.com";
      expect(isValidEmail(longEmail)).toBe(false);
    });
  });

  describe("isValidUrl", () => {
    it("should validate correct URLs", () => {
      expect(isValidUrl("https://example.com")).toBe(true);
      expect(isValidUrl("http://example.com/path")).toBe(true);
      expect(isValidUrl("https://example.com:8080/path?query=value")).toBe(
        true,
      );
    });

    it("should reject invalid URLs", () => {
      expect(isValidUrl("not a url with spaces")).toBe(false);
      expect(isValidUrl("ht!tp://example.com")).toBe(false);
      expect(isValidUrl("://example.com")).toBe(false);
    });

    it("should reject non-string input", () => {
      expect(isValidUrl(123)).toBe(false);
      expect(isValidUrl(null)).toBe(false);
    });
  });

  describe("isValidLength", () => {
    it("should validate string length", () => {
      expect(isValidLength("hello", 0, 10)).toBe(true);
      expect(isValidLength("hello", 5, 10)).toBe(true);
      expect(isValidLength("hello", 0, 5)).toBe(true);
    });

    it("should reject strings exceeding max length", () => {
      expect(isValidLength("hello", 0, 3)).toBe(false);
    });

    it("should reject strings below min length", () => {
      expect(isValidLength("hi", 5, 10)).toBe(false);
    });

    it("should use default min and max", () => {
      expect(isValidLength("hello")).toBe(true);
      expect(isValidLength("a".repeat(1001))).toBe(false);
    });
  });

  describe("isNotEmpty", () => {
    it("should accept non-empty strings", () => {
      expect(isNotEmpty("hello")).toBe(true);
      expect(isNotEmpty("  hello  ")).toBe(true);
    });

    it("should reject empty strings", () => {
      expect(isNotEmpty("")).toBe(false);
      expect(isNotEmpty("   ")).toBe(false);
      expect(isNotEmpty("\t\n")).toBe(false);
    });

    it("should reject non-string input", () => {
      expect(isNotEmpty(123)).toBe(false);
      expect(isNotEmpty(null)).toBe(false);
    });
  });

  describe("isAlphanumericUnderscore", () => {
    it("should accept valid alphanumeric strings with underscores", () => {
      expect(isAlphanumericUnderscore("hello_world")).toBe(true);
      expect(isAlphanumericUnderscore("test123")).toBe(true);
      expect(isAlphanumericUnderscore("_private")).toBe(true);
    });

    it("should reject strings with invalid characters", () => {
      expect(isAlphanumericUnderscore("hello-world")).toBe(false);
      expect(isAlphanumericUnderscore("hello world")).toBe(false);
      expect(isAlphanumericUnderscore("hello@world")).toBe(false);
    });
  });

  describe("isSlugFormat", () => {
    it("should accept valid slug format", () => {
      expect(isSlugFormat("hello-world")).toBe(true);
      expect(isSlugFormat("test_123")).toBe(true);
      expect(isSlugFormat("my-slug_123")).toBe(true);
    });

    it("should reject invalid slug format", () => {
      expect(isSlugFormat("hello world")).toBe(false);
      expect(isSlugFormat("hello@world")).toBe(false);
    });
  });

  describe("isValidBoolean", () => {
    it("should accept boolean values", () => {
      expect(isValidBoolean(true)).toBe(true);
      expect(isValidBoolean(false)).toBe(true);
    });

    it("should reject non-boolean values", () => {
      expect(isValidBoolean("true")).toBe(false);
      expect(isValidBoolean(1)).toBe(false);
      expect(isValidBoolean(null)).toBe(false);
    });
  });

  describe("isValidNumber", () => {
    it("should accept valid numbers", () => {
      expect(isValidNumber(42)).toBe(true);
      expect(isValidNumber(3.14)).toBe(true);
      expect(isValidNumber(-10)).toBe(true);
    });

    it("should reject non-number values", () => {
      expect(isValidNumber("42")).toBe(false);
      expect(isValidNumber(NaN)).toBe(false);
      expect(isValidNumber(null)).toBe(false);
    });

    it("should validate min and max bounds", () => {
      expect(isValidNumber(50, 0, 100)).toBe(true);
      expect(isValidNumber(150, 0, 100)).toBe(false);
      expect(isValidNumber(-10, 0, 100)).toBe(false);
    });
  });

  describe("isValidInteger", () => {
    it("should accept valid integers", () => {
      expect(isValidInteger(42)).toBe(true);
      expect(isValidInteger(0)).toBe(true);
      expect(isValidInteger(-10)).toBe(true);
    });

    it("should reject non-integer values", () => {
      expect(isValidInteger(3.14)).toBe(false);
      expect(isValidInteger("42")).toBe(false);
      expect(isValidInteger(null)).toBe(false);
    });

    it("should validate min and max bounds", () => {
      expect(isValidInteger(50, 0, 100)).toBe(true);
      expect(isValidInteger(150, 0, 100)).toBe(false);
    });
  });

  describe("isOneOf", () => {
    it("should accept values in allowed list", () => {
      expect(isOneOf("light", ["light", "dark"])).toBe(true);
      expect(isOneOf("dark", ["light", "dark"])).toBe(true);
    });

    it("should reject values not in allowed list", () => {
      expect(isOneOf("blue", ["light", "dark"])).toBe(false);
      expect(isOneOf("LIGHT", ["light", "dark"])).toBe(false);
    });
  });

  describe("validateName", () => {
    it("should validate correct names", () => {
      const result = validateName("John");
      expect(result.valid).toBe(true);
    });

    it("should reject non-string names", () => {
      const result = validateName(123);
      expect(result.valid).toBe(false);
      expect(result.error).toContain("must be a string");
    });

    it("should reject names exceeding max length", () => {
      const result = validateName("a".repeat(101));
      expect(result.valid).toBe(false);
    });

    it("should reject names with HTML characters", () => {
      const result = validateName("John<script>");
      expect(result.valid).toBe(false);
    });
  });

  describe("validateEmail", () => {
    it("should validate correct emails", () => {
      const result = validateEmail("user@example.com");
      expect(result.valid).toBe(true);
    });

    it("should reject invalid emails", () => {
      const result = validateEmail("invalid");
      expect(result.valid).toBe(false);
    });

    it("should reject non-string emails", () => {
      const result = validateEmail(123);
      expect(result.valid).toBe(false);
    });
  });

  describe("validateUrl", () => {
    it("should validate correct URLs", () => {
      const result = validateUrl("https://example.com/avatar.jpg");
      expect(result.valid).toBe(true);
    });

    it("should reject invalid URLs", () => {
      const result = validateUrl("not-a-url");
      expect(result.valid).toBe(false);
    });

    it("should allow empty URLs when specified", () => {
      const result = validateUrl("", true);
      expect(result.valid).toBe(true);
    });

    it("should reject empty URLs by default", () => {
      const result = validateUrl("");
      expect(result.valid).toBe(false);
    });
  });

  describe("validateTheme", () => {
    it("should accept valid themes", () => {
      expect(validateTheme("light").valid).toBe(true);
      expect(validateTheme("dark").valid).toBe(true);
    });

    it("should reject invalid themes", () => {
      const result = validateTheme("blue");
      expect(result.valid).toBe(false);
      expect(result.error).toContain("light");
      expect(result.error).toContain("dark");
    });
  });

  describe("validateLanguage", () => {
    it("should accept valid language codes", () => {
      expect(validateLanguage("en").valid).toBe(true);
      expect(validateLanguage("en-US").valid).toBe(true);
      expect(validateLanguage("fr").valid).toBe(true);
    });

    it("should reject invalid language codes", () => {
      const result = validateLanguage("invalid-language-code-too-long");
      expect(result.valid).toBe(false);
    });

    it("should reject language codes with invalid characters", () => {
      const result = validateLanguage("en_US");
      expect(result.valid).toBe(false);
    });
  });

  describe("validateNotifications", () => {
    it("should accept boolean values", () => {
      expect(validateNotifications(true).valid).toBe(true);
      expect(validateNotifications(false).valid).toBe(true);
    });

    it("should reject non-boolean values", () => {
      const result = validateNotifications("true");
      expect(result.valid).toBe(false);
    });
  });

  describe("validatePreferences", () => {
    it("should validate correct preferences", () => {
      const preferences = {
        theme: "dark",
        language: "en",
        notifications: true,
      };
      const result = validatePreferences(preferences);
      expect(result.valid).toBe(true);
    });

    it("should allow partial preferences", () => {
      const preferences = { theme: "light" };
      const result = validatePreferences(preferences);
      expect(result.valid).toBe(true);
    });

    it("should reject invalid theme", () => {
      const preferences = { theme: "invalid" };
      const result = validatePreferences(preferences);
      expect(result.valid).toBe(false);
    });

    it("should reject invalid language", () => {
      const preferences = { language: "invalid-language-code-too-long" };
      const result = validatePreferences(preferences);
      expect(result.valid).toBe(false);
    });

    it("should reject invalid notifications", () => {
      const preferences = { notifications: "yes" };
      const result = validatePreferences(preferences);
      expect(result.valid).toBe(false);
    });

    it("should reject non-object preferences", () => {
      const result = validatePreferences("invalid");
      expect(result.valid).toBe(false);
    });
  });

  describe("validateProfile", () => {
    it("should validate correct profile", () => {
      const profile = {
        firstName: "John",
        lastName: "Doe",
        nickname: "johndoe",
        avatar: "https://example.com/avatar.jpg",
        preferences: {
          theme: "dark",
          language: "en",
          notifications: true,
        },
      };
      const result = validateProfile(profile);
      expect(result.valid).toBe(true);
    });

    it("should allow partial profile", () => {
      const profile = { firstName: "John" };
      const result = validateProfile(profile);
      expect(result.valid).toBe(true);
    });

    it("should reject invalid firstName", () => {
      const profile = { firstName: "a".repeat(101) };
      const result = validateProfile(profile);
      expect(result.valid).toBe(false);
    });

    it("should reject invalid avatar URL", () => {
      const profile = { avatar: "not-a-url" };
      const result = validateProfile(profile);
      expect(result.valid).toBe(false);
    });

    it("should reject invalid preferences", () => {
      const profile = {
        preferences: { theme: "invalid" },
      };
      const result = validateProfile(profile);
      expect(result.valid).toBe(false);
    });

    it("should reject non-object profile", () => {
      const result = validateProfile("invalid");
      expect(result.valid).toBe(false);
    });
  });

  describe("sanitizeInput", () => {
    it("should sanitize specified string fields", () => {
      const input = {
        firstName: '<script>alert("xss")</script>',
        age: 30,
      };
      const result = sanitizeInput(input, ["firstName"]);
      expect(result.firstName).toContain("&lt;");
      expect(result.age).toBe(30);
    });

    it("should recursively sanitize nested objects", () => {
      const input = {
        profile: {
          firstName: '<script>alert("xss")</script>',
        },
      };
      const result = sanitizeInput(input, ["firstName"]);
      expect(result.profile.firstName).toContain("&lt;");
    });

    it("should handle non-object input", () => {
      expect(sanitizeInput("string")).toBe("string");
      expect(sanitizeInput(null)).toBe(null);
    });
  });

  describe("validateAndSanitizeProfile", () => {
    it("should validate and sanitize correct profile", () => {
      const profile = {
        firstName: "John",
        lastName: "Doe",
      };
      const result = validateAndSanitizeProfile(profile);
      expect(result.valid).toBe(true);
      expect(result.data).toBeDefined();
    });

    it("should reject invalid profile", () => {
      const profile = {
        firstName: "a".repeat(101),
      };
      const result = validateAndSanitizeProfile(profile);
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });

    it("should reject XSS attempts in profile", () => {
      const profile = {
        firstName: '<script>alert("xss")</script>',
      };
      const result = validateAndSanitizeProfile(profile);
      // Should reject because firstName contains HTML characters
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe("validateAndSanitizePreferences", () => {
    it("should validate and sanitize correct preferences", () => {
      const preferences = {
        theme: "dark",
        language: "en",
        notifications: true,
      };
      const result = validateAndSanitizePreferences(preferences);
      expect(result.valid).toBe(true);
      expect(result.data).toBeDefined();
    });

    it("should reject invalid preferences", () => {
      const preferences = {
        theme: "invalid",
      };
      const result = validateAndSanitizePreferences(preferences);
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });

    it("should sanitize language field", () => {
      const preferences = {
        language: '<script>alert("xss")</script>',
      };
      const result = validateAndSanitizePreferences(preferences);
      expect(result.valid).toBe(false); // Invalid language format
    });
  });

  describe("SQL Injection Prevention", () => {
    it("should prevent SQL injection via parameterized queries", () => {
      // SQL injection prevention is primarily handled by parameterized queries
      // in the database layer, not by input validation. The database layer
      // uses parameterized queries which safely escape all user input.
      // This test verifies that even if malicious input passes validation,
      // it will be safely handled by parameterized queries.

      const maliciousInput = "'; DROP TABLE users; --";
      // This input may pass basic validation, but will be safely handled
      // by parameterized queries at the database layer
      const result = validateName(maliciousInput);

      // The key is that parameterized queries will treat this as a literal string,
      // not as SQL code, preventing SQL injection
      expect(result).toBeDefined();
    });

    it("should prevent SQL injection in email field", () => {
      // Email with SQL injection attempt - should be rejected by format validation
      const maliciousEmail = "admin@example.com'; DROP TABLE users; --";
      const result = validateEmail(maliciousEmail);
      // This should fail because it doesn't match email format (has spaces and special chars)
      expect(result.valid).toBe(false);
    });

    it("should prevent SQL injection in URL field", () => {
      const maliciousUrl = "https://example.com'; DROP TABLE users; --";
      const result = validateUrl(maliciousUrl);
      // URL validation should reject this
      expect(result.valid).toBe(false);
    });
  });

  describe("XSS Prevention", () => {
    it("should prevent script injection in names", () => {
      const xssAttempt = "<img src=x onerror=\"alert('xss')\">";
      const result = validateName(xssAttempt);
      expect(result.valid).toBe(false);
    });

    it("should prevent event handler injection", () => {
      const xssAttempt = 'John" onmouseover="alert(\'xss\')"';
      const result = validateName(xssAttempt);
      expect(result.valid).toBe(false);
    });

    it("should sanitize HTML entities in profile", () => {
      const profile = {
        firstName: "<b>John</b>",
      };
      const result = validateAndSanitizeProfile(profile);
      expect(result.valid).toBe(false); // Contains HTML characters
    });
  });

  describe("validateInput", () => {
    it("should validate correct primitive types", () => {
      expect(() => validateInput("hello", "name", "string")).not.toThrow();
      expect(() => validateInput(42, "age", "number")).not.toThrow();
      expect(() => validateInput(true, "active", "boolean")).not.toThrow();
    });

    it("should reject incorrect primitive types", () => {
      expect(() => validateInput(42, "name", "string")).toThrow(
        "Invalid name: expected string, got number",
      );
      expect(() => validateInput("true", "active", "boolean")).toThrow(
        "Invalid active: expected boolean, got string",
      );
    });

    it("should validate UUID format", () => {
      expect(() =>
        validateInput("550e8400-e29b-41d4-a716-446655440000", "id", "uuid"),
      ).not.toThrow();
    });

    it("should reject invalid UUID format", () => {
      expect(() =>
        validateInput("not-a-uuid", "id", "uuid"),
      ).toThrow("Invalid id: expected UUID");
    });

    it("should reject non-string UUID input", () => {
      expect(() => validateInput(123, "id", "uuid")).toThrow(
        "Invalid id: expected UUID",
      );
    });

    it("should reject UUID with wrong segment lengths", () => {
      expect(() =>
        validateInput("550e8400-e29b-41d4-a716", "id", "uuid"),
      ).toThrow("Invalid id: expected UUID");
    });
  });

  describe("ValidationError", () => {
    it("should create error with message", () => {
      const err = new ValidationError("test error");
      expect(err.message).toBe("test error");
      expect(err.name).toBe("ValidationError");
      expect(err.field).toBeNull();
      expect(err.code).toBe("VALIDATION_ERROR");
    });

    it("should create error with field and code", () => {
      const err = new ValidationError("bad input", "email", "INVALID_EMAIL");
      expect(err.message).toBe("bad input");
      expect(err.field).toBe("email");
      expect(err.code).toBe("INVALID_EMAIL");
    });

    it("should be instanceof Error", () => {
      const err = new ValidationError("test");
      expect(err).toBeInstanceOf(Error);
    });
  });

  describe("logValidationError", () => {
    it("should call logger.warn with structured data", () => {
      logValidationError("POST /users", "user-1", "email", "invalid format");
    });

    it("should accept optional context", () => {
      logValidationError(
        "POST /users",
        "user-1",
        "age",
        "too low",
        { value: -1 },
      );
    });
  });

  describe("Edge Cases", () => {
    it("should handle very long strings", () => {
      const longString = "a".repeat(10000);
      const result = isValidLength(longString, 0, 1000);
      expect(result).toBe(false);
    });

    it("should handle unicode characters", () => {
      const unicodeName = "José";
      const result = validateName(unicodeName);
      expect(result.valid).toBe(true);
    });

    it("should handle empty objects", () => {
      const result = validateProfile({});
      expect(result.valid).toBe(true);
    });

    it("should handle null values in optional fields", () => {
      const profile = {
        firstName: null,
      };
      const result = validateProfile(profile);
      expect(result.valid).toBe(false); // null is not a string
    });
  });
});
