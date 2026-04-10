const documentController = require('../src/controllers/document.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── uploadDocument validation ───

describe('uploadDocument', () => {
  let res;

  beforeEach(() => {
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
});

// ─── searchDocuments validation ───

describe('searchDocuments', () => {
  let res;

  beforeEach(() => {
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
});

// ─── getDocumentById ───

describe('getDocumentById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 500 when db query fails', async () => {
    await documentController.getDocumentById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── updateDocument ───

describe('updateDocument', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 500 when db query fails', async () => {
    await documentController.updateDocument(
      { params: { id: 'nonexistent' }, body: { name: 'Updated' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── deleteDocument ───

describe('deleteDocument', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 500 when db query fails', async () => {
    await documentController.deleteDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_DELETE_FAILED' }),
      }),
    );
  });
});

// ─── approveDocument ───

describe('approveDocument', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 500 when db query fails', async () => {
    await documentController.approveDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_APPROVAL_FAILED' }),
      }),
    );
  });
});

// ─── rejectDocument ───

describe('rejectDocument', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 500 when db query fails', async () => {
    await documentController.rejectDocument({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DOCUMENT_REJECTION_FAILED' }),
      }),
    );
  });
});
