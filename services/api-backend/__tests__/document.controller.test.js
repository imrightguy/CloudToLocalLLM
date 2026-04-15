/**
 * Tests for document.controller.js
 * Covers validation, success paths, and error handling.
 */
jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    values: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue([]),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    delete: jest.fn().mockReturnThis(),
  },
}));

const { db } = require('../src/database/connection');
const {
  uploadDocument,
  getDocuments,
  getDocumentById,
  updateDocument,
  deleteDocument,
  approveDocument,
  rejectDocument,
} = require('../src/controllers/document.controller');

function mockRes() {
  const res = {};
  res.statusCode = 200;
  res.body = null;
  res.status = jest.fn((code) => { res.statusCode = code; return res; });
  res.json = jest.fn((data) => { res.body = data; return res; });
  return res;
}

describe('document.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset chain defaults
    db.select.mockReturnThis();
    db.from.mockReturnThis();
    db.where.mockReturnThis();
    db.limit.mockReturnThis();
    db.offset.mockReturnThis();
    db.orderBy.mockReturnThis();
    db.insert.mockReturnThis();
    db.values.mockReturnThis();
    db.returning.mockResolvedValue([]);
    db.update.mockReturnThis();
    db.set.mockReturnThis();
    db.delete.mockReturnThis();
  });

  // ─── uploadDocument ───

  describe('uploadDocument', () => {
    it('returns 400 when name is missing', async () => {
      const req = {
        body: { type: 'lease', url: 'https://example.com/doc.pdf' },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 when type is missing', async () => {
      const req = {
        body: { name: 'Lease.pdf', url: 'https://example.com/doc.pdf' },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.body.error.message).toMatch(/name.*type.*url/i);
    });

    it('returns 400 when url is missing', async () => {
      const req = {
        body: { name: 'Lease.pdf', type: 'lease' },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('returns 400 when all required fields are missing', async () => {
      const req = { body: {} };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 201 on successful upload with all fields', async () => {
      const mockDoc = {
        id: 'doc-1',
        name: 'Lease.pdf',
        type: 'lease',
        url: 'https://example.com/doc.pdf',
        status: 'pending',
        isActive: true,
      };

      db.returning.mockResolvedValue([mockDoc]);

      const req = {
        body: {
          name: 'Lease.pdf',
          type: 'lease',
          url: 'https://example.com/doc.pdf',
          category: 'legal',
          fileSize: 1024,
          mimeType: 'application/pdf',
          referenceId: 'lead-1',
          referenceType: 'lead',
          metadata: { pages: 5 },
          uploadedBy: 'user-1',
        },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe('Lease.pdf');
      expect(res.body.data.type).toBe('lease');
      expect(res.body.message).toBe('Document uploaded successfully');
      expect(db.insert).toHaveBeenCalled();
      expect(db.values).toHaveBeenCalled();
    });

    it('returns 201 on successful upload with only required fields', async () => {
      const mockDoc = {
        id: 'doc-2',
        name: 'Application.pdf',
        type: 'application',
        url: 'https://example.com/app.pdf',
        status: 'pending',
        isActive: true,
      };

      db.returning.mockResolvedValue([mockDoc]);

      const req = {
        body: {
          name: 'Application.pdf',
          type: 'application',
          url: 'https://example.com/app.pdf',
        },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('doc-2');
    });

    it('returns 500 on database error during upload', async () => {
      db.returning.mockRejectedValue(new Error('DB connection failed'));

      const req = {
        body: { name: 'Lease.pdf', type: 'lease', url: 'https://example.com/doc.pdf' },
      };
      const res = mockRes();

      await uploadDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('DOCUMENT_UPLOAD_FAILED');
    });
  });

  // ─── getDocuments ───

  describe('getDocuments', () => {
    it('returns documents list with metadata on success', async () => {
      const mockDocs = [
        { id: 'doc-1', name: 'Lease.pdf', isActive: true },
        { id: 'doc-2', name: 'Application.pdf', isActive: true },
      ];

      // First select call = count query, second = data query
      let selectCallCount = 0;
      db.select.mockImplementation(() => {
        selectCallCount++;
        if (selectCallCount === 1) {
          // Count query: select({count}).from().where() -> resolves
          return {
            from: jest.fn(() => ({
              where: jest.fn(() => Promise.resolve([{ count: 2 }])),
            })),
          };
        }
        // Data query: select().from().where().orderBy().limit().offset()
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => ({
              orderBy: jest.fn(() => ({
                limit: jest.fn(() => ({
                  offset: jest.fn(() => Promise.resolve(mockDocs)),
                })),
              })),
            })),
          })),
        };
      });

      const req = { query: { page: '1', limit: '20' } };
      const res = mockRes();

      await getDocuments(req, res);

      expect(res.json).toHaveBeenCalled();
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(2);
      expect(res.body.metadata).toBeDefined();
      expect(res.body.metadata.total).toBe(2);
      expect(res.body.metadata.page).toBe(1);
      expect(res.body.metadata.limit).toBe(20);
      expect(res.body.metadata.totalPages).toBe(1);
    });

    it('defaults page and limit when not provided', async () => {
      let callIdx = 0;
      db.select.mockImplementation(() => {
        callIdx++;
        if (callIdx === 1) {
          return { from: jest.fn(() => ({ where: jest.fn(() => Promise.resolve([{ count: 0 }])) })) };
        }
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => ({
              orderBy: jest.fn(() => ({ limit: jest.fn(() => ({ offset: jest.fn(() => Promise.resolve([])) })) })),
            })),
          })),
        };
      });

      const req = { query: {} };
      const res = mockRes();

      await getDocuments(req, res);

      expect(res.body.success).toBe(true);
      expect(res.body.metadata.page).toBe(1);
      expect(res.body.metadata.limit).toBe(20);
    });

    it('caps limit at 100', async () => {
      let callIdx = 0;
      db.select.mockImplementation(() => {
        callIdx++;
        if (callIdx === 1) {
          return { from: jest.fn(() => ({ where: jest.fn(() => Promise.resolve([{ count: 0 }])) })) };
        }
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => ({
              orderBy: jest.fn(() => ({ limit: jest.fn(() => ({ offset: jest.fn(() => Promise.resolve([])) })) })),
            })),
          })),
        };
      });

      const req = { query: { limit: '500' } };
      const res = mockRes();

      await getDocuments(req, res);

      expect(res.body.metadata.limit).toBe(100);
    });

    it('ensures minimum page is 1', async () => {
      let callIdx = 0;
      db.select.mockImplementation(() => {
        callIdx++;
        if (callIdx === 1) {
          return { from: jest.fn(() => ({ where: jest.fn(() => Promise.resolve([{ count: 0 }])) })) };
        }
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => ({
              orderBy: jest.fn(() => ({ limit: jest.fn(() => ({ offset: jest.fn(() => Promise.resolve([])) })) })),
            })),
          })),
        };
      });

      const req = { query: { page: '-5' } };
      const res = mockRes();

      await getDocuments(req, res);

      expect(res.body.metadata.page).toBe(1);
    });

    it('returns 500 on database error', async () => {
      db.select.mockImplementation(() => ({
        from: jest.fn(() => ({
          where: jest.fn(() => Promise.reject(new Error('DB error'))),
        })),
      }));

      const req = { query: {} };
      const res = mockRes();

      await getDocuments(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_FETCH_FAILED');
    });
  });

  // ─── getDocumentById ───

  describe('getDocumentById', () => {
    it('returns 404 when document not found', async () => {
      // Chain: select().from().where().limit() -> resolves []
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.resolve([])),
          })),
        })),
      });

      const req = { params: { id: 'nonexistent-id' } };
      const res = mockRes();

      await getDocumentById(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.body.error.code).toBe('DOCUMENT_NOT_FOUND');
    });

    it('returns document with lead links when found', async () => {
      const mockDoc = {
        id: 'doc-1',
        name: 'Lease.pdf',
        type: 'lease',
        isActive: true,
      };
      const mockLeadLinks = [
        { leadId: 'lead-1', assignedAt: '2026-01-01T00:00:00Z' },
      ];

      let selectCallCount = 0;
      db.select.mockImplementation((fields) => {
        selectCallCount++;
        if (selectCallCount === 1) {
          // Document lookup: select().from().where().limit()
          return {
            from: jest.fn(() => ({
              where: jest.fn(() => ({
                limit: jest.fn(() => Promise.resolve([mockDoc])),
              })),
            })),
          };
        }
        // Lead links lookup: select({fields}).from().where()
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => Promise.resolve(mockLeadLinks)),
          })),
        };
      });

      const req = { params: { id: 'doc-1' } };
      const res = mockRes();

      await getDocumentById(req, res);

      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe('doc-1');
      expect(res.body.data.leads).toEqual(mockLeadLinks);
    });

    it('returns document with empty leads when no links exist', async () => {
      const mockDoc = {
        id: 'doc-2',
        name: 'ID.pdf',
        type: 'identification',
        isActive: true,
      };

      let selectCallCount = 0;
      db.select.mockImplementation(() => {
        selectCallCount++;
        if (selectCallCount === 1) {
          return {
            from: jest.fn(() => ({
              where: jest.fn(() => ({
                limit: jest.fn(() => Promise.resolve([mockDoc])),
              })),
            })),
          };
        }
        return {
          from: jest.fn(() => ({
            where: jest.fn(() => Promise.resolve([])),
          })),
        };
      });

      const req = { params: { id: 'doc-2' } };
      const res = mockRes();

      await getDocumentById(req, res);

      expect(res.body.success).toBe(true);
      expect(res.body.data.leads).toEqual([]);
    });

    it('returns 500 on database error', async () => {
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.reject(new Error('DB error'))),
          })),
        })),
      });

      const req = { params: { id: 'doc-1' } };
      const res = mockRes();

      await getDocumentById(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_FETCH_FAILED');
    });
  });

  // ─── updateDocument ───

  describe('updateDocument', () => {
    it('returns 500 on database error', async () => {
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.reject(new Error('DB error'))),
          })),
        })),
      });

      const req = { params: { id: 'doc-1' }, body: { name: 'Updated' } };
      const res = mockRes();

      await updateDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_UPDATE_FAILED');
    });
  });

  // ─── deleteDocument ───

  describe('deleteDocument', () => {
    it('returns 500 on database error', async () => {
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.reject(new Error('DB error'))),
          })),
        })),
      });

      const req = { params: { id: 'doc-1' } };
      const res = mockRes();

      await deleteDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_DELETE_FAILED');
    });
  });

  // ─── approveDocument ───

  describe('approveDocument', () => {
    it('returns 500 on database error', async () => {
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.reject(new Error('DB error'))),
          })),
        })),
      });

      const req = { params: { id: 'doc-1' } };
      const res = mockRes();

      await approveDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_APPROVAL_FAILED');
    });
  });

  // ─── rejectDocument ───

  describe('rejectDocument', () => {
    it('returns 500 on database error', async () => {
      db.select.mockReturnValue({
        from: jest.fn(() => ({
          where: jest.fn(() => ({
            limit: jest.fn(() => Promise.reject(new Error('DB error'))),
          })),
        })),
      });

      const req = { params: { id: 'doc-1' } };
      const res = mockRes();

      await rejectDocument(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.body.error.code).toBe('DOCUMENT_REJECTION_FAILED');
    });
  });
});
