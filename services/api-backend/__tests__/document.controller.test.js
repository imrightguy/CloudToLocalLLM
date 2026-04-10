const documentController = require('../src/controllers/document.controller');

const mockDb = {
  select: jest.fn(),
  insert: jest.fn(),
  update: jest.fn(),
};

jest.mock('../src/database/connection', () => ({
  db: mockDb,
}));

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function mockChain(returnVal) {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.returning = jest.fn().mockResolvedValue(returnVal);
  chain.values = jest.fn().mockReturnValue(chain);
  chain.set = jest.fn().mockReturnValue(chain);

  if (Array.isArray(returnVal)) {
    chain.then = (resolve) => Promise.resolve(returnVal).then(resolve);
  }

  return chain;
}

// ─── uploadDocument validation ───

describe('uploadDocument', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('rejects missing name', async () => {
    await documentController.uploadDocument(
      { body: { type: 'lease', url: 'https://example.com/doc.pdf' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects missing type', async () => {
    await documentController.uploadDocument(
      { body: { name: 'Lease Agreement', url: 'https://example.com/doc.pdf' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing url', async () => {
    await documentController.uploadDocument(
      { body: { name: 'Lease Agreement', type: 'lease' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await documentController.uploadDocument({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null name', async () => {
    await documentController.uploadDocument(
      { body: { name: null, type: 'lease', url: 'https://example.com/doc.pdf' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects undefined name', async () => {
    await documentController.uploadDocument(
      { body: { name: undefined, type: 'lease', url: 'https://example.com/doc.pdf' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions all required fields', async () => {
    await documentController.uploadDocument({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toContain('name');
    expect(errorMsg).toContain('type');
    expect(errorMsg).toContain('url');
  });

  it('returns 201 on successful upload', async () => {
    const fakeDoc = { id: 'doc-1', name: 'Lease.pdf', type: 'lease', url: 'https://example.com/lease.pdf', status: 'pending' };
    mockDb.insert.mockReturnValue(mockChain([fakeDoc]));

    await documentController.uploadDocument(
      { body: { name: 'Lease.pdf', type: 'lease', url: 'https://example.com/lease.pdf' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: fakeDoc,
      }),
    );
  });
});

// ─── searchDocuments validation ───

describe('searchDocuments', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('rejects missing search query q', async () => {
    await documentController.searchDocuments({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({
          message: expect.stringContaining('q'),
          code: 'VALIDATION_ERROR',
        }),
      }),
    );
  });

  it('rejects empty q parameter', async () => {
    await documentController.searchDocuments({ query: { q: '' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns documents on successful search', async () => {
    const fakeCount = mockChain([{ count: 1 }]);
    const fakeDocs = mockChain([{ id: 'doc-1', name: 'Lease.pdf' }]);
    mockDb.select
      .mockReturnValueOnce(fakeCount)
      .mockReturnValueOnce(fakeDocs);

    await documentController.searchDocuments({ query: { q: 'lease' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: [{ id: 'doc-1', name: 'Lease.pdf' }],
        metadata: expect.objectContaining({ total: 1 }),
      }),
    );
  });
});

// ─── getDocumentById ───

describe('getDocumentById', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('returns 404 when document not found', async () => {
    mockDb.select.mockReturnValue(mockChain([]));

    await documentController.getDocumentById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_NOT_FOUND' }),
      }),
    );
  });

  it('returns document with lead links when found', async () => {
    const fakeDoc = { id: 'doc-1', name: 'Lease.pdf', type: 'lease' };
    const fakeLeads = [{ leadId: 'lead-1', assignedAt: '2024-01-01' }];

    mockDb.select
      .mockReturnValueOnce(mockChain([fakeDoc]))
      .mockReturnValueOnce(mockChain(fakeLeads));

    await documentController.getDocumentById({ params: { id: 'doc-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({ ...fakeDoc, leads: fakeLeads }),
      }),
    );
  });
});

// ─── updateDocument ───

describe('updateDocument', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('returns 404 when document not found', async () => {
    mockDb.select.mockReturnValue(mockChain([]));

    await documentController.updateDocument(
      { params: { id: 'nonexistent' }, body: { name: 'Updated' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_NOT_FOUND' }),
      }),
    );
  });

  it('returns updated document on success', async () => {
    const existing = { id: 'doc-1', name: 'Old.pdf', type: 'lease' };
    const updated = { id: 'doc-1', name: 'New.pdf', type: 'lease', updatedAt: expect.any(Date) };

    mockDb.select.mockReturnValue(mockChain([existing]));
    mockDb.update.mockReturnValue(mockChain([updated]));

    await documentController.updateDocument(
      { params: { id: 'doc-1' }, body: { name: 'New.pdf' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({ name: 'New.pdf' }),
      }),
    );
  });
});

// ─── deleteDocument ───

describe('deleteDocument', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('returns 404 when document not found', async () => {
    mockDb.select.mockReturnValue(mockChain([]));

    await documentController.deleteDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_NOT_FOUND' }),
      }),
    );
  });

  it('soft-deletes document on success', async () => {
    const existing = { id: 'doc-1', name: 'Lease.pdf' };
    mockDb.select.mockReturnValue(mockChain([existing]));
    mockDb.update.mockReturnValue(mockChain([]));

    await documentController.deleteDocument({ params: { id: 'doc-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: null,
      }),
    );
  });
});

// ─── approveDocument ───

describe('approveDocument', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('returns 404 when document not found', async () => {
    mockDb.select.mockReturnValue(mockChain([]));

    await documentController.approveDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_NOT_FOUND' }),
      }),
    );
  });

  it('returns 400 when already approved', async () => {
    const existing = { id: 'doc-1', status: 'approved' };
    mockDb.select.mockReturnValue(mockChain([existing]));

    await documentController.approveDocument({ params: { id: 'doc-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_ALREADY_APPROVED' }),
      }),
    );
  });

  it('approves document on success', async () => {
    const existing = { id: 'doc-1', status: 'pending' };
    const approved = { id: 'doc-1', status: 'approved' };
    mockDb.select.mockReturnValue(mockChain([existing]));
    mockDb.update.mockReturnValue(mockChain([approved]));

    await documentController.approveDocument({ params: { id: 'doc-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({ status: 'approved' }),
      }),
    );
  });
});

// ─── rejectDocument ───

describe('rejectDocument', () => {
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    res = mockRes();
  });

  it('returns 404 when document not found', async () => {
    mockDb.select.mockReturnValue(mockChain([]));

    await documentController.rejectDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_NOT_FOUND' }),
      }),
    );
  });

  it('returns 400 when already rejected', async () => {
    const existing = { id: 'doc-1', status: 'rejected' };
    mockDb.select.mockReturnValue(mockChain([existing]));

    await documentController.rejectDocument({ params: { id: 'doc-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_ALREADY_REJECTED' }),
      }),
    );
  });

  it('rejects document on success', async () => {
    const existing = { id: 'doc-1', status: 'pending' };
    const rejected = { id: 'doc-1', status: 'rejected' };
    mockDb.select.mockReturnValue(mockChain([existing]));
    mockDb.update.mockReturnValue(mockChain([rejected]));

    await documentController.rejectDocument({ params: { id: 'doc-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({ status: 'rejected' }),
      }),
    );
  });
});
