jest.mock('../../src/services/tenant-checklist.service', () => ({
  startChecklistSession: jest.fn(),
  resumeChecklistSession: jest.fn(),
  pauseChecklistSession: jest.fn(),
  submitChecklistSession: jest.fn(),
  getChecklistSessionSummary: jest.fn(),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const service = require('../../src/services/tenant-checklist.service');
const controller = require('../../src/controllers/tenant-checklist.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('tenant-checklist controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates a checklist session', async () => {
    service.startChecklistSession.mockResolvedValue({ session: { id: 'session-1' } });

    const res = mockRes();
    await controller.startChecklistSession({
      body: { unitId: 'unit-1', checklistType: 'move_in' },
      user: { id: 'user-1' },
    }, res);

    expect(service.startChecklistSession).toHaveBeenCalledWith(expect.objectContaining({
      unitId: 'unit-1',
      checklistType: 'move_in',
      createdByUserId: 'user-1',
    }));
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Session de checklist créée avec succès',
    }));
  });

  it('supports submit and summary routes', async () => {
    service.submitChecklistSession.mockResolvedValue({ session: { id: 'session-2', state: 'completed' } });
    service.getChecklistSessionSummary.mockResolvedValue({ session: { id: 'session-2' } });

    const submitRes = mockRes();
    await controller.submitChecklistSession({
      params: { id: 'session-2' },
      body: { forceComplete: true, stepUpdates: [], attachments: [], signatures: [] },
      user: { id: 'user-1' },
    }, submitRes);

    const summaryRes = mockRes();
    await controller.getManagerChecklistSessionSummary({ params: { id: 'session-2' } }, summaryRes);

    expect(service.submitChecklistSession).toHaveBeenCalledWith(expect.objectContaining({
      sessionId: 'session-2',
      submittedByUserId: 'user-1',
      forceComplete: true,
    }));
    expect(service.getChecklistSessionSummary).toHaveBeenCalledWith({ sessionId: 'session-2' });
    expect(summaryRes.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Résumé gestionnaire de checklist récupéré avec succès',
    }));
  });
});
