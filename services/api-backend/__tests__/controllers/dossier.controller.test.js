jest.mock('../../src/services/dossier.service', () => ({
  createDossierCase: jest.fn(),
  getDossierCaseById: jest.fn(),
  reviewDossierCase: jest.fn(),
  exportDossierCase: jest.fn(),
  listDossierCases: jest.fn(),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const dossierService = require('../../src/services/dossier.service');
const dossierController = require('../../src/controllers/dossier.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('dossier controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates a dossier case from the selected tenant, unit, and problem category', async () => {
    dossierService.createDossierCase.mockResolvedValue({
      id: 'case-1',
      status: 'draft',
      factualSummary: 'Résumé factuel',
    });

    const res = mockRes();
    await dossierController.createDossierCase(
      {
        params: { companyId: 'company-1' },
        body: {
          leadId: 'lead-1',
          unitId: 'unit-1',
          problemCategory: 'maintenance',
        },
        user: { id: 'user-1' },
      },
      res,
    );

    expect(dossierService.createDossierCase).toHaveBeenCalledWith({
      companyId: 'company-1',
      leadId: 'lead-1',
      unitId: 'unit-1',
      problemCategory: 'maintenance',
      incidentWindowStart: undefined,
      incidentWindowEnd: undefined,
      createdByUserId: 'user-1',
    });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'case-1' }),
    }));
  });

  it('marks a dossier case as reviewed', async () => {
    dossierService.reviewDossierCase.mockResolvedValue({
      id: 'case-1',
      status: 'approved',
      reviewNotes: 'Reviewed by manager',
    });

    const res = mockRes();
    await dossierController.reviewDossierCase(
      {
        params: { companyId: 'company-1', id: 'case-1' },
        body: { status: 'approved', reviewNotes: 'Reviewed by manager' },
        user: { id: 'user-1' },
      },
      res,
    );

    expect(dossierService.reviewDossierCase).toHaveBeenCalledWith({
      companyId: 'company-1',
      dossierCaseId: 'case-1',
      status: 'approved',
      reviewNotes: 'Reviewed by manager',
      reviewedByUserId: 'user-1',
    });
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'approved' }),
    }));
  });
});
