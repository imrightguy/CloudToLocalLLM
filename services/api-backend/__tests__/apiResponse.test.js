const {
  successResponse,
  errorResponse,
  generatePaginationMetadata,
  validateFilters,
  getPagination,
  asyncHandler,
  addSearch,
  addSort,
} = require('../src/utils/apiResponse');

describe('successResponse', () => {
  it('returns basic success with data and default message', () => {
    const result = successResponse({ data: { id: 1 } });
    expect(result).toEqual({
      success: true,
      data: { id: 1 },
      message: 'Operation successful',
    });
  });

  it('includes custom message', () => {
    const result = successResponse({ data: [], message: 'Items found' });
    expect(result.message).toBe('Items found');
  });

  it('includes metadata when provided', () => {
    const meta = { total: 100, page: 1 };
    const result = successResponse({ data: [], metadata: meta });
    expect(result.metadata).toEqual(meta);
  });

  it('omits metadata when null', () => {
    const result = successResponse({ data: [], metadata: null });
    expect(result).not.toHaveProperty('metadata');
  });
});

describe('errorResponse', () => {
  it('returns error with default code', () => {
    const result = errorResponse({ message: 'Something broke' });
    expect(result).toEqual({
      success: false,
      error: {
        message: 'Something broke',
        code: 'INTERNAL_ERROR',
        details: null,
      },
    });
  });

  it('accepts custom code and details', () => {
    const result = errorResponse({
      message: 'Invalid input',
      code: 'VALIDATION_ERROR',
      details: { field: 'email' },
    });
    expect(result.error.code).toBe('VALIDATION_ERROR');
    expect(result.error.details).toEqual({ field: 'email' });
  });
});

describe('generatePaginationMetadata', () => {
  it('calculates pages correctly', () => {
    const meta = generatePaginationMetadata({ total: 55, page: 2, limit: 20 });
    expect(meta).toEqual({
      total: 55,
      page: 2,
      limit: 20,
      totalPages: 3,
      hasNext: true,
      hasPrev: true,
      offset: 20,
    });
  });

  it('defaults to page 1, limit 20', () => {
    const meta = generatePaginationMetadata({ total: 100 });
    expect(meta.page).toBe(1);
    expect(meta.limit).toBe(20);
    expect(meta.totalPages).toBe(5);
  });

  it('handles exact division', () => {
    const meta = generatePaginationMetadata({ total: 40, page: 2, limit: 20 });
    expect(meta.totalPages).toBe(2);
    expect(meta.hasNext).toBe(false);
    expect(meta.hasPrev).toBe(true);
  });

  it('handles zero total', () => {
    const meta = generatePaginationMetadata({ total: 0 });
    expect(meta.totalPages).toBe(0);
    expect(meta.hasNext).toBe(false);
    expect(meta.hasPrev).toBe(false);
  });
});

describe('validateFilters', () => {
  it('returns only allowed filters', () => {
    const req = { query: { filters: { status: 'active', name: 'test', junk: 'drop' } } };
    const result = validateFilters(req, ['status', 'name']);
    expect(result).toEqual({ status: 'active', name: 'test' });
  });

  it('returns empty object when no filters in query', () => {
    const req = { query: {} };
    const result = validateFilters(req, ['status']);
    expect(result).toEqual({});
  });

  it('returns empty object when no allowed filters match', () => {
    const req = { query: { filters: { bad: 'value' } } };
    const result = validateFilters(req, ['good']);
    expect(result).toEqual({});
  });
});

describe('getPagination', () => {
  it('returns correct offset and limit', () => {
    const result = getPagination(3, 25);
    expect(result).toEqual({ offset: 50, limit: 25 });
  });

  it('clamps limit to 100 max', () => {
    const result = getPagination(1, 999);
    expect(result.limit).toBe(100);
  });

  it('clamps limit to 1 min', () => {
    const result = getPagination(1, 0);
    expect(result.limit).toBe(1);
  });

  it('clamps page to 1 min', () => {
    const result = getPagination(-5, 10);
    expect(result.offset).toBe(0);
  });

  it('defaults to page 1, limit 20', () => {
    const result = getPagination();
    expect(result).toEqual({ offset: 0, limit: 20 });
  });
});

describe('asyncHandler', () => {
  it('calls next with error when async function rejects', async () => {
    const error = new Error('boom');
    const fn = jest.fn().mockRejectedValue(error);
    const next = jest.fn();
    const handler = asyncHandler(fn);

    await handler({}, {}, next);
    expect(next).toHaveBeenCalledWith(error);
  });

  it('does not call next on success', async () => {
    const fn = jest.fn().mockResolvedValue('ok');
    const next = jest.fn();
    const handler = asyncHandler(fn);

    await handler({}, {}, next);
    expect(next).not.toHaveBeenCalled();
  });
});

describe('addSearch', () => {
  it('returns queryBuilder unchanged when search is falsy', () => {
    const qb = { whereRaw: jest.fn().mockReturnThis() };
    const result = addSearch(qb, '', ['name']);
    expect(result).toBe(qb);
    expect(qb.whereRaw).not.toHaveBeenCalled();
  });

  it('returns queryBuilder unchanged when search is null', () => {
    const qb = { whereRaw: jest.fn().mockReturnThis() };
    const result = addSearch(qb, null, ['name']);
    expect(result).toBe(qb);
    expect(qb.whereRaw).not.toHaveBeenCalled();
  });

  it('calls whereRaw with LIKE conditions for each search field', () => {
    const qb = { whereRaw: jest.fn().mockReturnThis() };
    addSearch(qb, 'john', ['name', 'email']);

    expect(qb.whereRaw).toHaveBeenCalledTimes(1);
    const [rawClause, bindings] = qb.whereRaw.mock.calls[0];
    expect(rawClause).toContain('LOWER(name)');
    expect(rawClause).toContain('LOWER(email)');
    expect(rawClause).toContain(' OR ');
    expect(bindings).toEqual(['%john%', '%john%']);
  });

  it('lowercases the search term', () => {
    const qb = { whereRaw: jest.fn().mockReturnThis() };
    addSearch(qb, 'JOHN', ['name']);

    const bindings = qb.whereRaw.mock.calls[0][1];
    expect(bindings).toEqual(['%john%']);
  });
});

describe('addSort', () => {
  it('sorts by allowed field ascending by default', () => {
    const qb = { orderBy: jest.fn().mockReturnThis() };
    const result = addSort(qb, 'name', 'asc', ['name', 'createdAt']);

    expect(result).toBe(qb);
    expect(qb.orderBy).toHaveBeenCalledWith('name', 'asc');
  });

  it('sorts descending', () => {
    const qb = { orderBy: jest.fn().mockReturnThis() };
    addSort(qb, 'name', 'desc', ['name']);

    expect(qb.orderBy).toHaveBeenCalledWith('name', 'desc');
  });

  it('falls back to createdAt when sortBy is not in allowed fields', () => {
    const qb = { orderBy: jest.fn().mockReturnThis() };
    addSort(qb, 'hacked', 'asc', ['name', 'email']);

    expect(qb.orderBy).toHaveBeenCalledWith('createdAt', 'asc');
  });

  it('falls back to asc when sortOrder is invalid', () => {
    const qb = { orderBy: jest.fn().mockReturnThis() };
    addSort(qb, 'name', 'sideways', ['name']);

    expect(qb.orderBy).toHaveBeenCalledWith('name', 'asc');
  });

  it('uses defaults when no sort params provided', () => {
    const qb = { orderBy: jest.fn().mockReturnThis() };
    addSort(qb);

    expect(qb.orderBy).toHaveBeenCalledWith('createdAt', 'asc');
  });
});
