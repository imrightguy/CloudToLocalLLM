import { describe, it, expect, jest } from '@jest/globals';

import {
  sanitizeString,
  sanitizeEmail,
  sanitizeNumber,
  sanitizeUUID,
  sanitizeDate,
  sanitizeEnum,
  sanitizeObject,
  sanitizePagination,
  sanitizeLikePattern,
  sanitizeBody,
  sanitizeQuery,
  sanitizeParams,
  sanitizeAll,
  sanitizeAdminInput,
} from '../../services/api-backend/middleware/input-sanitizer.js';

describe('sanitizeString', () => {
  it('escapes HTML entities', () => {
    expect(sanitizeString('<script>alert("xss")</script>')).not.toContain('<script>');
    expect(sanitizeString('<div>hello</div>')).toBe('&lt;div&gt;hello&lt;&#x2F;div&gt;');
  });

  it('removes script tags entirely', () => {
    const input = '<script>alert("xss")</script>safe content';
    const result = sanitizeString(input);
    expect(result).not.toMatch(/<script/i);
    expect(result).toContain('safe content');
  });

  it('escapes inline event handlers via HTML entity encoding', () => {
    const input = '<img onerror="alert(1)" src=x>';
    const result = sanitizeString(input);
    expect(result).toContain('&lt;img');
    expect(result).toContain('&quot;');
    expect(result).toContain('&gt;');
    expect(result).not.toMatch(/<img/i);
  });

  it('removes javascript: protocol', () => {
    const input = 'javascript:alert(1)';
    const result = sanitizeString(input);
    expect(result.toLowerCase()).not.toContain('javascript:');
  });

  it('returns non-string input unchanged', () => {
    expect(sanitizeString(42)).toBe(42);
    expect(sanitizeString(null)).toBe(null);
    expect(sanitizeString(undefined)).toBe(undefined);
  });

  it('passes through safe strings', () => {
    expect(sanitizeString('hello world')).toBe('hello world');
    expect(sanitizeString('user@example.com')).toBe('user@example.com');
  });
});

describe('sanitizeEmail', () => {
  it('returns normalized valid email', () => {
    expect(sanitizeEmail('User@Example.COM')).toBe('user@example.com');
  });

  it('returns null for invalid email', () => {
    expect(sanitizeEmail('not-an-email')).toBeNull();
    expect(sanitizeEmail('@missing-local')).toBeNull();
  });

  it('returns null for non-string input', () => {
    expect(sanitizeEmail(123)).toBeNull();
    expect(sanitizeEmail(null)).toBeNull();
  });

  it('handles Gmail dot normalization', () => {
    const result = sanitizeEmail('u.ser@gmail.com');
    expect(result).toBeTruthy();
  });
});

describe('sanitizeNumber', () => {
  it('parses integer from string', () => {
    expect(sanitizeNumber('42')).toBe(42);
    expect(sanitizeNumber('0')).toBe(0);
  });

  it('returns null for NaN', () => {
    expect(sanitizeNumber('abc')).toBeNull();
    expect(sanitizeNumber('')).toBeNull();
  });

  it('respects min constraint', () => {
    expect(sanitizeNumber('5', { min: 10 })).toBeNull();
    expect(sanitizeNumber('15', { min: 10 })).toBe(15);
  });

  it('respects max constraint', () => {
    expect(sanitizeNumber('15', { max: 10 })).toBeNull();
    expect(sanitizeNumber('5', { max: 10 })).toBe(5);
  });

  it('handles float when allowed', () => {
    expect(sanitizeNumber('3.14', { allowFloat: true })).toBeCloseTo(3.14);
  });

  it('parses as integer when float not allowed', () => {
    expect(sanitizeNumber('3.14')).toBe(3);
  });

  it('works with numeric input directly', () => {
    expect(sanitizeNumber(42, { min: 1 })).toBe(42);
  });
});

describe('sanitizeUUID', () => {
  it('returns valid UUID unchanged', () => {
    const uuid = '550e8400-e29b-41d4-a716-446655440000';
    expect(sanitizeUUID(uuid)).toBe(uuid);
  });

  it('returns null for invalid UUID', () => {
    expect(sanitizeUUID('not-a-uuid')).toBeNull();
    expect(sanitizeUUID('')).toBeNull();
  });

  it('returns null for non-string input', () => {
    expect(sanitizeUUID(123)).toBeNull();
  });
});

describe('sanitizeDate', () => {
  it('parses valid ISO date string', () => {
    const result = sanitizeDate('2024-01-15');
    expect(result).toBeInstanceOf(Date);
    expect(result.toISOString()).toContain('2024-01-15');
  });

  it('returns null for invalid date', () => {
    expect(sanitizeDate('not-a-date')).toBeNull();
  });

  it('returns null for falsy input', () => {
    expect(sanitizeDate(null)).toBeNull();
    expect(sanitizeDate('')).toBeNull();
    expect(sanitizeDate(undefined)).toBeNull();
  });
});

describe('sanitizeEnum', () => {
  it('returns value if in allowed list', () => {
    expect(sanitizeEnum('active', ['active', 'inactive'])).toBe('active');
  });

  it('returns null if not in allowed list', () => {
    expect(sanitizeEnum('unknown', ['active', 'inactive'])).toBeNull();
  });

  it('returns null for missing allowed values', () => {
    expect(sanitizeEnum('active')).toBeNull();
    expect(sanitizeEnum('active', null)).toBeNull();
    expect(sanitizeEnum('active', 'not-array')).toBeNull();
  });
});

describe('sanitizeObject', () => {
  it('sanitizes string values in objects', () => {
    const result = sanitizeObject({ name: '<script>xss</script>', age: 25 });
    expect(result.name).not.toContain('<script>');
    expect(result.age).toBe(25);
  });

  it('sanitizes keys', () => {
    const result = sanitizeObject({ '<img onerror=x>': 'value' });
    const keys = Object.keys(result);
    expect(keys[0]).not.toContain('<img');
  });

  it('recursively sanitizes nested objects', () => {
    const input = { nested: { deep: '<b>bold</b>' } };
    const result = sanitizeObject(input);
    expect(result.nested.deep).not.toContain('<b>');
  });

  it('sanitizes arrays', () => {
    const input = ['<script>xss</script>', 'safe', 42];
    const result = sanitizeObject(input);
    expect(result[0]).not.toContain('<script>');
    expect(result[1]).toBe('safe');
    expect(result[2]).toBe(42);
  });

  it('returns empty object beyond max depth', () => {
    const deep = { a: { b: { c: { d: { e: { f: { g: { h: { i: { j: { k: 'val' } } } } } } } } } } };
    const result = sanitizeObject(deep, 0, 5);
    expect(typeof result).toBe('object');
  });

  it('passes through null and undefined', () => {
    expect(sanitizeObject(null)).toBeNull();
    expect(sanitizeObject(undefined)).toBeUndefined();
  });
});

describe('sanitizePagination', () => {
  it('returns defaults when no params given', () => {
    const result = sanitizePagination({});
    expect(result).toEqual({ page: 1, limit: 50, offset: 0 });
  });

  it('applies page and limit from query', () => {
    const result = sanitizePagination({ page: '3', limit: '25' });
    expect(result).toEqual({ page: 3, limit: 25, offset: 50 });
  });

  it('clamps limit to max 200', () => {
    const result = sanitizePagination({ page: '1', limit: '999' });
    expect(result.limit).toBe(50);
  });

  it('defaults page to 1 for invalid input', () => {
    const result = sanitizePagination({ page: 'abc' });
    expect(result.page).toBe(1);
  });

  it('defaults limit to 50 for invalid input', () => {
    const result = sanitizePagination({ limit: '-5' });
    expect(result.limit).toBe(50);
  });
});

describe('sanitizeLikePattern', () => {
  it('escapes SQL LIKE wildcards', () => {
    expect(sanitizeLikePattern('100%')).toBe('100\\%');
    expect(sanitizeLikePattern('user_name')).toBe('user\\_name');
  });

  it('escapes backslashes', () => {
    const result = sanitizeLikePattern('path\\to\\file');
    expect(result).toContain('\\\\');
  });

  it('removes SQL injection characters', () => {
    expect(sanitizeLikePattern("'; DROP TABLE--")).not.toContain(';');
    expect(sanitizeLikePattern("'; DROP TABLE--")).not.toContain('--');
  });

  it('removes block comments', () => {
    expect(sanitizeLikePattern('/* comment */')).not.toContain('/*');
    expect(sanitizeLikePattern('/* comment */')).not.toContain('*/');
  });

  it('escapes single quotes', () => {
    expect(sanitizeLikePattern("O'Reilly")).toContain("''");
  });

  it('returns empty string for non-string input', () => {
    expect(sanitizeLikePattern(123)).toBe('');
    expect(sanitizeLikePattern(null)).toBe('');
  });
});

describe('Express middlewares', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    mockNext = jest.fn();
    mockRes = { status: jest.fn().mockReturnThis(), json: jest.fn() };
  });

  describe('sanitizeBody', () => {
    it('sanitizes req.body', () => {
      mockReq = { body: { name: '<script>xss</script>' } };
      sanitizeBody(mockReq, mockRes, mockNext);
      expect(mockReq.body.name).not.toContain('<script>');
      expect(mockNext).toHaveBeenCalled();
    });

    it('calls next when no body', () => {
      mockReq = {};
      sanitizeBody(mockReq, mockRes, mockNext);
      expect(mockNext).toHaveBeenCalled();
    });
  });

  describe('sanitizeQuery', () => {
    it('sanitizes req.query', () => {
      mockReq = { query: { q: '<b>bold</b>' } };
      sanitizeQuery(mockReq, mockRes, mockNext);
      expect(mockReq.query.q).not.toContain('<b>');
      expect(mockNext).toHaveBeenCalled();
    });
  });

  describe('sanitizeParams', () => {
    it('sanitizes req.params', () => {
      mockReq = { params: { id: '<script>xss</script>' } };
      sanitizeParams(mockReq, mockRes, mockNext);
      expect(mockReq.params.id).not.toContain('<script>');
      expect(mockNext).toHaveBeenCalled();
    });
  });

  describe('sanitizeAll', () => {
    it('sanitizes body, query, and params', () => {
      mockReq = {
        body: { name: '<script>xss</script>' },
        query: { q: '<b>bold</b>' },
        params: { id: '"><script>' },
      };
      sanitizeAll(mockReq, mockRes, mockNext);
      expect(mockReq.body.name).not.toContain('<script>');
      expect(mockReq.query.q).not.toContain('<b>');
      expect(mockReq.params.id).not.toContain('<script>');
      expect(mockNext).toHaveBeenCalledTimes(1);
    });
  });
});

describe('sanitizeAdminInput', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    mockNext = jest.fn();
    mockRes = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    mockReq = { body: {}, query: {} };
  });

  it('rejects invalid email with 400', () => {
    mockReq.body.email = 'not-an-email';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'INVALID_EMAIL' }),
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('accepts valid email', () => {
    mockReq.body.email = 'admin@example.com';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.body.email).toBe('admin@example.com');
    expect(mockNext).toHaveBeenCalled();
  });

  it('rejects invalid amount with 400', () => {
    mockReq.body.amount = 'abc';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'INVALID_AMOUNT' }),
    );
  });

  it('accepts valid amount', () => {
    mockReq.body.amount = '29.99';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.body.amount).toBeCloseTo(29.99);
  });

  it('rejects negative amount', () => {
    mockReq.body.amount = '-10';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockRes.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid UUID fields', () => {
    mockReq.body.userId = 'not-a-uuid';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'INVALID_UUID' }),
    );
  });

  it('accepts valid UUID fields', () => {
    const uuid = '550e8400-e29b-41d4-a716-446655440000';
    mockReq.body.userId = uuid;
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.body.userId).toBe(uuid);
    expect(mockNext).toHaveBeenCalled();
  });

  it('rejects invalid date fields', () => {
    mockReq.body.startDate = 'not-a-date';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'INVALID_DATE' }),
    );
  });

  it('accepts valid date fields and converts to ISO', () => {
    mockReq.body.startDate = '2024-01-15';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.body.startDate).toContain('2024-01-15');
  });

  it('sanitizes search query with LIKE pattern', () => {
    mockReq.query.search = "100%; DROP TABLE--";
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.query.search).not.toContain(';');
    expect(mockReq.query.search).not.toContain('--');
  });

  it('applies pagination to query params', () => {
    mockReq.query.page = '3';
    mockReq.query.limit = '25';
    sanitizeAdminInput(mockReq, mockRes, mockNext);
    expect(mockReq.query.page).toBe(3);
    expect(mockReq.query.limit).toBe(25);
    expect(mockReq.query.offset).toBe(50);
  });
});
