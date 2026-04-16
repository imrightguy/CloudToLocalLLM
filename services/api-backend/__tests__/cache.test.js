const { cache, get, set, del, flush, getStats } = require('../src/utils/cache');

beforeEach(() => {
  flush();
});

afterAll(() => {
  cache.close();
});

describe('cache', () => {
  it('exports a NodeCache instance', () => {
    expect(cache).toBeDefined();
    expect(typeof cache.get).toBe('function');
    expect(typeof cache.set).toBe('function');
  });
});

describe('get / set', () => {
  it('stores and retrieves a value', () => {
    set('foo', 'bar');
    expect(get('foo')).toBe('bar');
  });

  it('returns undefined for missing keys', () => {
    expect(get('nonexistent')).toBeUndefined();
  });

  it('overwrites an existing key', () => {
    set('k', 1);
    set('k', 2);
    expect(get('k')).toBe(2);
  });

  it('stores objects and arrays', () => {
    const obj = { a: 1, b: [2, 3] };
    set('obj', obj);
    expect(get('obj')).toEqual(obj);
  });

  it('respects a custom TTL (seconds)', (done) => {
    set('ttl-key', 'val', 1);
    expect(get('ttl-key')).toBe('val');
    setTimeout(() => {
      expect(get('ttl-key')).toBeUndefined();
      done();
    }, 1100);
  });
});

describe('del', () => {
  it('removes a key', () => {
    set('rm', 'me');
    del('rm');
    expect(get('rm')).toBeUndefined();
  });

  it('returns the number of deleted keys', () => {
    set('a', 1);
    set('b', 2);
    expect(del('a')).toBe(1);
    expect(del('nonexistent')).toBe(0);
  });
});

describe('flush', () => {
  it('removes all keys', () => {
    set('x', 1);
    set('y', 2);
    flush();
    expect(get('x')).toBeUndefined();
    expect(get('y')).toBeUndefined();
  });
});

describe('getStats', () => {
  it('returns stats object with expected keys', () => {
    set('s1', 1);
    const stats = getStats();
    expect(stats).toHaveProperty('hits');
    expect(stats).toHaveProperty('misses');
    expect(stats).toHaveProperty('keys');
    expect(stats).toHaveProperty('ksize');
    expect(stats).toHaveProperty('vsize');
    expect(stats.keys).toBeGreaterThanOrEqual(1);
  });
});
