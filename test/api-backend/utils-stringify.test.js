import {
  stringify,
  truncate,
  asyncStringify,
  asyncToStringMethod,
  toStringMethod,
} from "../../services/api-backend/utils/stringify.js";

describe("stringify utils", () => {
  describe("stringify", () => {
    it("stringifies a plain object", () => {
      expect(stringify({ a: 1 })).toBe(JSON.stringify({ a: 1 }, null, 2));
    });

    it("accepts custom space", () => {
      const result = stringify({ a: 1 }, 0);
      expect(result).toBe('{"a":1}');
    });

    it("handles circular refs gracefully", () => {
      const obj = {};
      obj.self = obj;
      const result = stringify(obj);
      expect(typeof result).toBe("string");
      expect(result.length).toBeGreaterThan(0);
    });

    it("returns undefined for non-serializable (JSON.stringify behavior)", () => {
      const fn = () => {};
      expect(stringify(fn)).toBeUndefined();
    });
  });

  describe("truncate", () => {
    it("returns original if under maxLength", () => {
      expect(truncate("hi", 10)).toBe("hi");
    });

    it("returns original if at maxLength", () => {
      expect(truncate("hello", 5)).toBe("hello");
    });

    it("truncates and adds suffix", () => {
      expect(truncate("hello world", 8)).toBe("hello...");
    });

    it("uses custom suffix", () => {
      expect(truncate("hello world", 8, "…")).toBe("hello w…");
    });

    it("uses default maxLength 100", () => {
      const short = "a".repeat(50);
      expect(truncate(short)).toBe(short);
      const long = "a".repeat(200);
      expect(truncate(long)).toHaveLength(100);
    });

    it("throws on non-string input", () => {
      expect(() => truncate(123, 10)).toThrow();
    });
  });

  describe("asyncStringify", () => {
    it("resolves with JSON string", async () => {
      await expect(asyncStringify({ a: 1 })).resolves.toBe(
        JSON.stringify({ a: 1 }, null, 2),
      );
    });

    it("returns undefined for non-serializable (JSON.stringify behavior)", async () => {
      const fn = () => {};
      await expect(asyncStringify(fn)).resolves.toBeUndefined();
    });
  });

  describe("asyncToStringMethod", () => {
    it("calls toString if available", async () => {
      await expect(asyncToStringMethod(42)).resolves.toBe("42");
    });

    it("falls back to String", async () => {
      await expect(asyncToStringMethod(null)).resolves.toBe("null");
    });

    it("returns [Object] on error", async () => {
      const bad = {
        toString() {
          throw new Error("boom");
        },
      };
      await expect(asyncToStringMethod(bad)).resolves.toBe("[Object]");
    });
  });

  describe("toStringMethod", () => {
    it("calls toString if available", () => {
      expect(toStringMethod(42)).toBe("42");
    });

    it("falls back to String", () => {
      expect(toStringMethod(null)).toBe("null");
    });

    it("returns [Object] on error", () => {
      const bad = {
        toString() {
          throw new Error("boom");
        },
      };
      expect(toStringMethod(bad)).toBe("[Object]");
    });
  });
});
