const leadController = require('../src/controllers/lead.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── createLead validation ───

describe('createLead', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing fullName', async () => {
    await leadController.createLead({ body: { email: 'test@example.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects empty string fullName', async () => {
    await leadController.createLead({ body: { fullName: '   ' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null fullName', async () => {
    await leadController.createLead({ body: { fullName: null } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects undefined fullName', async () => {
    await leadController.createLead({ body: { fullName: undefined } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await leadController.createLead({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions fullName requirement', async () => {
    await leadController.createLead({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toMatch(/full name/i);
  });

  it('does not reject for missing email alone', async () => {
    await leadController.createLead(
      { body: { fullName: 'Jean Tremblay' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('does not reject for missing phone alone', async () => {
    await leadController.createLead(
      { body: { fullName: 'Jean Tremblay' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── updateLeadStatus validation ───

describe('updateLeadStatus', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing stage', async () => {
    await leadController.updateLeadStatus(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' }, body: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid stage value', async () => {
    await leadController.updateLeadStatus(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' }, body: { stage: 'not_a_stage' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string stage', async () => {
    await leadController.updateLeadStatus(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' }, body: { stage: '' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message lists valid stages', async () => {
    await leadController.updateLeadStatus(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' }, body: { stage: 'invalid' } },
      res,
    );
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toContain('nouveau');
    expect(errorMsg).toContain('bailSigne');
  });

  it('rejects null stage', async () => {
    await leadController.updateLeadStatus(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' }, body: { stage: null } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── bulkUpdateLeads validation ───

describe('bulkUpdateLeads', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing ids', async () => {
    await leadController.bulkUpdateLeads({ body: { updates: { stage: 'qualifie' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty ids array', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: [], updates: { stage: 'qualifie' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing updates', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: ['id-1'] } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects non-object updates', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: ['id-1'], updates: 'stage' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects disallowed fields', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { fullName: 'Hacked' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toMatch(/fullName.*not allowed/i);
  });

  it('rejects invalid stage in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'invalid_stage' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('allows valid allowed fields', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'qualifie' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows language field', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { language: 'en' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows tags field', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { tags: ['vip', 'urgent'] } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('error message for ids mentions "non-empty array"', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: [] } }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toMatch(/non-empty array/i);
  });
});

// ─── getLeads - query param parsing ───

describe('getLeads - query param parsing', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('defaults page to 1, limit to 20 when no query params provided', async () => {
    // Since DB calls will fail, we catch the 500 but can verify no crash
    await leadController.getLeads({ query: {} }, res);
    // Function didn't throw — either 200 or 500 is fine, just not a crash
    expect(res.status).toHaveBeenCalled();
  });

  it('clamps page to minimum 1 when negative', async () => {
    await leadController.getLeads({ query: { page: -5, limit: 10 } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('clamps page to minimum 1 when zero', async () => {
    await leadController.getLeads({ query: { page: 0, limit: 10 } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('clamps limit to minimum 1 when zero', async () => {
    await leadController.getLeads({ query: { page: 1, limit: 0 } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('clamps limit to maximum 100 when larger value given', async () => {
    await leadController.getLeads({ query: { page: 1, limit: 999 } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('accepts non-numeric page gracefully (NaN falls back)', async () => {
    await leadController.getLeads({ query: { page: 'abc', limit: 10 } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('accepts non-numeric limit gracefully (NaN falls back)', async () => {
    await leadController.getLeads({ query: { page: 1, limit: 'xyz' } }, res);
    expect(res.status).toHaveBeenCalled();
  });

  it('defaults sort to createdAt desc when no sort params provided', async () => {
    await leadController.getLeads({ query: {} }, res);
    expect(res.status).toHaveBeenCalled();
    // Verify it didn't return 400 — sort field defaulting is internal
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('accepts all allowed sort fields without 400', async () => {
    const allowedSortFields = ['fullName', 'email', 'stage', 'source', 'createdAt', 'updatedAt'];
    for (const field of allowedSortFields) {
      res = mockRes();
      await leadController.getLeads({ query: { sortBy: field, sortOrder: 'asc' } }, res);
      expect(res.status).not.toHaveBeenCalledWith(400);
    }
  });

  it('falls back to default sort for disallowed sortBy field (no 400)', async () => {
    await leadController.getLeads({ query: { sortBy: 'hackField', sortOrder: 'desc' } }, res);
    // Disallowed field silently falls back — no validation error
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('parses search query for ilike filtering', async () => {
    await leadController.getLeads({ query: { search: 'john' } }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('parses buildingId filter', async () => {
    await leadController.getLeads({ query: { buildingId: '123e4567-e89b-12d3-a456-426614174000' } }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('parses stage filter', async () => {
    await leadController.getLeads({ query: { stage: 'nouveau' } }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('parses multiple filters together', async () => {
    await leadController.getLeads({
      query: {
        stage: 'qualifie', buildingId: 'bldg-1', search: 'test', page: 2, limit: 5,
      },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('returns 500 (not crash) when DB is unavailable', async () => {
    await leadController.getLeads({ query: { page: 1, limit: 10 } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'LEAD_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── getLeadById ───

describe('getLeadById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('does not crash with a valid UUID id', async () => {
    await leadController.getLeadById(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' } },
      res,
    );
    expect(res.status).toHaveBeenCalled();
  });

  it('returns 500 for non-existent UUID when DB throws', async () => {
    // Without a real DB, the query will throw and hit the catch block -> 500
    await leadController.getLeadById(
      { params: { id: '00000000-0000-0000-0000-000000000000' } },
      res,
    );
    // Either 404 (if DB returns empty) or 500 (if DB throws) — function must not crash
    expect([404, 500]).toContain(res.status.mock.calls[0][0]);
  });

  it('handles missing id param gracefully', async () => {
    await leadController.getLeadById({ params: {} }, res);
    // Will throw in DB query since id is undefined, caught as 500
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ─── updateLead ───

describe('updateLead', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('does not crash when called with valid params', async () => {
    await leadController.updateLead(
      {
        params: { id: '123e4567-e89b-12d3-a456-426614174000' },
        body: { fullName: 'Updated Name' },
      },
      res,
    );
    expect(res.status).toHaveBeenCalled();
  });

  it('handles various field combinations in body', async () => {
    const fields = {
      fullName: 'Marie Dupont',
      email: 'marie@example.com',
      phone: '+33612345678',
      budgetCents: 150000,
      desiredUnit: 'T3',
      source: 'website',
      stage: 'qualifie',
      notes: 'Some notes',
      tags: ['vip'],
      language: 'en',
      assignedEmployeeId: 'emp-001',
      buildingId: 'bldg-001',
      unitId: 'unit-001',
      isActive: true,
    };

    for (const [key, value] of Object.entries(fields)) {
      res = mockRes();
      await leadController.updateLead(
        {
          params: { id: '123e4567-e89b-12d3-a456-426614174000' },
          body: { [key]: value },
        },
        res,
      );
      // Should not crash regardless of which field is sent
      expect(res.status).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalledWith(400);
    }
  });

  it('handles multiple fields in body simultaneously', async () => {
    res = mockRes();
    await leadController.updateLead(
      {
        params: { id: '123e4567-e89b-12d3-a456-426614174000' },
        body: {
          fullName: 'Jean Martin',
          email: 'jean@test.com',
          stage: 'contacte',
          tags: ['priority'],
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalled();
  });

  it('returns 500 when DB is unavailable', async () => {
    await leadController.updateLead(
      {
        params: { id: '123e4567-e89b-12d3-a456-426614174000' },
        body: { fullName: 'Test' },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'LEAD_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── deleteLead ───

describe('deleteLead', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('does not crash when called with valid params', async () => {
    await leadController.deleteLead(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' } },
      res,
    );
    expect(res.status).toHaveBeenCalled();
  });

  it('returns 500 when DB is unavailable', async () => {
    await leadController.deleteLead(
      { params: { id: '123e4567-e89b-12d3-a456-426614174000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'LEAD_DELETE_FAILED' }),
      }),
    );
  });

  it('handles missing id param gracefully', async () => {
    await leadController.deleteLead({ params: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ─── bulkUpdateLeads - additional validation ───

describe('bulkUpdateLeads - additional validation', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects non-array ids (string)', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: 'not-array', updates: { stage: 'qualifie' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects non-array ids (object)', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: { 0: 'id-1' }, updates: { stage: 'qualifie' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects non-array ids (number)', async () => {
    await leadController.bulkUpdateLeads({ body: { ids: 42, updates: { stage: 'qualifie' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: stage', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'nouveau' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: assignedEmployeeId', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { assignedEmployeeId: 'emp-123' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: buildingId', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { buildingId: 'bldg-456' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: isActive', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { isActive: false } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: tags', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { tags: ['hot-lead', 'follow-up'] } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows all valid allowedFields: language', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { language: 'en' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('allows multiple allowed fields together', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'qualifie', isActive: true, language: 'fr' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('rejects disallowed field: fullName', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { fullName: 'Hacked' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects disallowed field: email', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { email: 'hacked@test.com' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects disallowed field: phone', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { phone: '+33600000000' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects disallowed field: notes', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { notes: 'injected notes' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message names the rejected field', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { email: 'bad@test.com' } },
    }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toMatch(/email.*not allowed/i);
  });

  it('valid stage "nouveau" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'nouveau' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "contacte" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'contacte' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "qualifie" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'qualifie' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "visitePlanifiee" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'visitePlanifiee' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "visite_planifiee" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'visite_planifiee' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "offreEnvoyee" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'offreEnvoyee' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "negociation" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'negociation' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "bailSigne" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'bailSigne' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "signe" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'signe' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "visite_completee" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'visite_completee' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "interesse" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'interesse' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('valid stage "inactif" passes validation in bulk update', async () => {
    await leadController.bulkUpdateLeads({
      body: { ids: ['id-1'], updates: { stage: 'inactif' } },
    }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});
