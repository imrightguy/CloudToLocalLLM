const { db } = require('../database/connection');
const { documentsTable, documentsLeadsTable } = require('../database/schema');
const { eq, and, desc, ilike, sql } = require('drizzle-orm');

// ─── Upload Document ───
exports.uploadDocument = async (req, res) => {
  try {
    const { name, type, category, fileSize, mimeType, url, referenceId, referenceType, metadata, uploadedBy } = req.body;

    if (!name || !type || !url) {
      return res.status(400).json({
        success: false,
        error: { message: 'name, type, and url are required', code: 'VALIDATION_ERROR' },
      });
    }

    const [document] = await db.insert(documentsTable).values({
      name,
      type,
      category: category || null,
      fileSize: fileSize || null,
      mimeType: mimeType || null,
      url,
      status: 'pending',
      referenceId: referenceId || null,
      referenceType: referenceType || null,
      metadata: metadata || {},
      uploadedBy: uploadedBy || null,
      isActive: true,
    }).returning();

    res.status(201).json({
      success: true,
      data: document,
      message: 'Document uploaded successfully',
    });
  } catch (error) {
    console.error('Error uploading document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_UPLOAD_FAILED' },
    });
  }
};

// ─── Get Documents ───
exports.getDocuments = async (req, res) => {
  try {
    const { referenceId, referenceType, type, category, status, uploadedBy, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const conditions = [eq(documentsTable.isActive, true)];
    if (referenceId) conditions.push(eq(documentsTable.referenceId, referenceId));
    if (referenceType) conditions.push(eq(documentsTable.referenceType, referenceType));
    if (type) conditions.push(eq(documentsTable.type, type));
    if (category) conditions.push(eq(documentsTable.category, category));
    if (status) conditions.push(eq(documentsTable.status, status));
    if (uploadedBy) conditions.push(eq(documentsTable.uploadedBy, uploadedBy));

    // Count
    const countResult = await db.select({ count: sql`count(*)::int` })
      .from(documentsTable)
      .where(and(...conditions));
    const total = countResult[0]?.count || 0;

    // Data
    const documents = await db.select()
      .from(documentsTable)
      .where(and(...conditions))
      .orderBy(desc(documentsTable.createdAt))
      .limit(parseInt(limit))
      .offset(offset);

    const totalPages = Math.ceil(total / parseInt(limit));

    res.json({
      success: true,
      data: documents,
      message: 'Documents retrieved successfully',
      metadata: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages,
        hasMore: parseInt(page) < totalPages,
      },
    });
  } catch (error) {
    console.error('Error fetching documents:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_FETCH_FAILED' },
    });
  }
};

// ─── Get Document By ID ───
exports.getDocumentById = async (req, res) => {
  try {
    const { id } = req.params;

    const [document] = await db.select()
      .from(documentsTable)
      .where(eq(documentsTable.id, id))
      .limit(1);

    if (!document) {
      return res.status(404).json({
        success: false,
        error: { message: 'Document not found', code: 'DOCUMENT_NOT_FOUND' },
      });
    }

    // Fetch associated lead IDs
    const leadLinks = await db.select({ leadId: documentsLeadsTable.leadId, assignedAt: documentsLeadsTable.assignedAt })
      .from(documentsLeadsTable)
      .where(eq(documentsLeadsTable.documentId, id));

    const result = { ...document, leads: leadLinks };

    res.json({
      success: true,
      data: result,
      message: 'Document retrieved successfully',
    });
  } catch (error) {
    console.error('Error fetching document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_FETCH_FAILED' },
    });
  }
};

// ─── Update Document ───
exports.updateDocument = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, type, category, fileSize, mimeType, url, status, referenceId, referenceType, metadata } = req.body;

    const [existing] = await db.select()
      .from(documentsTable)
      .where(eq(documentsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Document not found', code: 'DOCUMENT_NOT_FOUND' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (name !== undefined) updateData.name = name;
    if (type !== undefined) updateData.type = type;
    if (category !== undefined) updateData.category = category;
    if (fileSize !== undefined) updateData.fileSize = fileSize;
    if (mimeType !== undefined) updateData.mimeType = mimeType;
    if (url !== undefined) updateData.url = url;
    if (status !== undefined) updateData.status = status;
    if (referenceId !== undefined) updateData.referenceId = referenceId;
    if (referenceType !== undefined) updateData.referenceType = referenceType;
    if (metadata !== undefined) updateData.metadata = metadata;

    const [updated] = await db.update(documentsTable)
      .set(updateData)
      .where(eq(documentsTable.id, id))
      .returning();

    res.json({
      success: true,
      data: updated,
      message: 'Document updated successfully',
    });
  } catch (error) {
    console.error('Error updating document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Document (soft delete) ───
exports.deleteDocument = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(documentsTable)
      .where(eq(documentsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Document not found', code: 'DOCUMENT_NOT_FOUND' },
      });
    }

    await db.update(documentsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(documentsTable.id, id));

    res.json({
      success: true,
      data: null,
      message: 'Document deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_DELETE_FAILED' },
    });
  }
};

// ─── Approve Document ───
exports.approveDocument = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(documentsTable)
      .where(eq(documentsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Document not found', code: 'DOCUMENT_NOT_FOUND' },
      });
    }

    if (existing.status === 'approved') {
      return res.status(400).json({
        success: false,
        error: { message: 'Document is already approved', code: 'DOCUMENT_ALREADY_APPROVED' },
      });
    }

    const [approved] = await db.update(documentsTable)
      .set({ status: 'approved', updatedAt: new Date() })
      .where(eq(documentsTable.id, id))
      .returning();

    res.json({
      success: true,
      data: approved,
      message: 'Document approved successfully',
    });
  } catch (error) {
    console.error('Error approving document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_APPROVAL_FAILED' },
    });
  }
};

// ─── Reject Document ───
exports.rejectDocument = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(documentsTable)
      .where(eq(documentsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Document not found', code: 'DOCUMENT_NOT_FOUND' },
      });
    }

    if (existing.status === 'rejected') {
      return res.status(400).json({
        success: false,
        error: { message: 'Document is already rejected', code: 'DOCUMENT_ALREADY_REJECTED' },
      });
    }

    const [rejected] = await db.update(documentsTable)
      .set({ status: 'rejected', updatedAt: new Date() })
      .where(eq(documentsTable.id, id))
      .returning();

    res.json({
      success: true,
      data: rejected,
      message: 'Document rejected successfully',
    });
  } catch (error) {
    console.error('Error rejecting document:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_REJECTION_FAILED' },
    });
  }
};

// ─── Search Documents ───
exports.searchDocuments = async (req, res) => {
  try {
    const { q, type, category, status, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    if (!q) {
      return res.status(400).json({
        success: false,
        error: { message: 'Search query "q" is required', code: 'VALIDATION_ERROR' },
      });
    }

    const escaped = q.replace(/[%_\\]/g, '\\$&');
    const conditions = [
      eq(documentsTable.isActive, true),
      ilike(documentsTable.name, `%${escaped}%`),
    ];
    if (type) conditions.push(eq(documentsTable.type, type));
    if (category) conditions.push(eq(documentsTable.category, category));
    if (status) conditions.push(eq(documentsTable.status, status));

    // Count
    const countResult = await db.select({ count: sql`count(*)::int` })
      .from(documentsTable)
      .where(and(...conditions));
    const total = countResult[0]?.count || 0;

    // Data
    const documents = await db.select()
      .from(documentsTable)
      .where(and(...conditions))
      .orderBy(desc(documentsTable.createdAt))
      .limit(parseInt(limit))
      .offset(offset);

    const totalPages = Math.ceil(total / parseInt(limit));

    res.json({
      success: true,
      data: documents,
      message: 'Document search completed',
      metadata: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages,
        hasMore: parseInt(page) < totalPages,
        query: q,
      },
    });
  } catch (error) {
    console.error('Error searching documents:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'DOCUMENT_SEARCH_FAILED' },
    });
  }
};
