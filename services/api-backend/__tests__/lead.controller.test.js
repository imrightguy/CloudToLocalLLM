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
