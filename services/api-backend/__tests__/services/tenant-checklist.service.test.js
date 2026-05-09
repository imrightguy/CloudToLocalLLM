jest.mock('../../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
    transaction: jest.fn(),
  },
}));

const { db } = require('../../src/database/connection');
const {
  startChecklistSession,
  submitChecklistSession,
  getChecklistSessionSummary,
  resumeChecklistSession,
  pauseChecklistSession,
} = require('../../src/services/tenant-checklist.service');
const { buildChecklistTemplate } = require('../../src/models/tenant-checklist');

const makeSelectChain = (rows) => {
  const chain = {
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue(rows),
  };
  chain.then = (resolve, reject) => Promise.resolve(rows).then(resolve, reject);
  return chain;
};

const makeTrackedSelectChain = (rows, tracker) => {
  const run = () => new Promise((resolve, reject) => {
    tracker.active += 1;
    if (tracker.active > 1) {
      reject(new Error('Concurrent query detected during checklist graph load'));
      return;
    }
    setImmediate(() => {
      tracker.active -= 1;
      resolve(rows);
    });
  });

  const chain = {
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockImplementation(() => run()),
  };
  chain.then = (resolve, reject) => run().then(resolve, reject);
  return chain;
};

const mockSessionGraph = (rows) => {
  let selectCall = 0;
  db.select.mockImplementation(() => makeSelectChain(rows[selectCall++ % rows.length]));
};

const makeInsertChain = (returningRows = []) => ({
  values: jest.fn().mockReturnValue({
    returning: jest.fn().mockResolvedValue(returningRows),
  }),
});

const buildGraphSequence = (snapshots) => snapshots.flatMap((snapshot) => [
  [snapshot.session],
  [snapshot.unit],
  snapshot.steps,
  snapshot.attachments || [],
  snapshot.signatures || [],
  snapshot.events || [],
]);

describe('tenant-checklist.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    db.transaction.mockImplementation(async (callback) => callback(db));
    db.insert.mockImplementation(() => makeInsertChain([]));
    db.update.mockImplementation(() => ({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    }));
  });

  it('starts a checklist session and seeds the template steps', async () => {
    const session = {
      id: 'session-1',
      unitId: 'unit-1',
      leaseId: null,
      checklistType: 'move_in',
      state: 'in_progress',
      currentStepKey: 'identity_unit_confirmation',
      currentStepOrder: 1,
      tenantName: 'Marie Tremblay',
      tenantPhone: '(514) 555-0101',
      startedAt: new Date('2026-05-06T22:00:00.000Z'),
      resumedAt: new Date('2026-05-06T22:00:00.000Z'),
      pausedAt: null,
      submittedAt: null,
      completedAt: null,
      reviewedAt: null,
      createdAt: new Date('2026-05-06T22:00:00.000Z'),
      updatedAt: new Date('2026-05-06T22:00:00.000Z'),
      metadata: {},
    };
    const steps = buildChecklistTemplate('move_in').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-1',
      ...step,
    }));

    db.select
      .mockImplementationOnce(() => makeSelectChain([{ id: 'unit-1', label: '304', tenantName: 'Marie Tremblay', tenantPhone: '(514) 555-0101' }]))
      .mockImplementationOnce(() => makeSelectChain([session]))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'unit-1', label: '304', tenantName: 'Marie Tremblay', tenantPhone: '(514) 555-0101' }]))
      .mockImplementationOnce(() => makeSelectChain(steps))
      .mockImplementationOnce(() => makeSelectChain([]))
      .mockImplementationOnce(() => makeSelectChain([]))
      .mockImplementationOnce(() => makeSelectChain([]));

    db.insert
      .mockImplementationOnce(() => makeInsertChain([session]))
      .mockImplementationOnce(() => makeInsertChain([]))
      .mockImplementationOnce(() => makeInsertChain([]));

    const result = await startChecklistSession({
      unitId: 'unit-1',
      checklistType: 'move_in',
      tenantName: 'Marie Tremblay',
      tenantPhone: '(514) 555-0101',
      metadata: { source: 'portal' },
      createdByUserId: 'user-1',
    });

    expect(db.transaction).toHaveBeenCalledTimes(1);
    expect(db.insert).toHaveBeenCalledTimes(3);
    expect(result.session.state).toBe('in_progress');
    expect(result.steps).toHaveLength(5);
    expect(result.summary).toEqual(expect.objectContaining({
      stepCount: 5,
      completedStepCount: 0,
      attachmentCount: 0,
      signatureCount: 0,
      eventCount: 0,
    }));
  });

  it('loads the checklist summary serially inside a transaction during start', async () => {
    const tracker = { active: 0 };
    const session = {
      id: 'session-serial-1',
      unitId: 'unit-serial-1',
      leaseId: null,
      checklistType: 'move_in',
      state: 'in_progress',
      currentStepKey: 'identity_unit_confirmation',
      currentStepOrder: 1,
      tenantName: 'Marie Tremblay',
      tenantPhone: '(514) 555-0101',
      startedAt: new Date('2026-05-06T22:00:00.000Z'),
      resumedAt: new Date('2026-05-06T22:00:00.000Z'),
      pausedAt: null,
      submittedAt: null,
      completedAt: null,
      reviewedAt: null,
      createdAt: new Date('2026-05-06T22:00:00.000Z'),
      updatedAt: new Date('2026-05-06T22:00:00.000Z'),
      metadata: {},
    };
    const unit = { id: 'unit-serial-1', label: '304', tenantName: 'Marie Tremblay', tenantPhone: '(514) 555-0101' };
    const steps = buildChecklistTemplate('move_in').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-serial-1',
      ...step,
    }));

    db.select
      .mockImplementationOnce(() => makeSelectChain([unit]))
      .mockImplementationOnce(() => makeTrackedSelectChain([session], tracker))
      .mockImplementationOnce(() => makeTrackedSelectChain([unit], tracker))
      .mockImplementationOnce(() => makeTrackedSelectChain(steps, tracker))
      .mockImplementationOnce(() => makeTrackedSelectChain([], tracker))
      .mockImplementationOnce(() => makeTrackedSelectChain([], tracker))
      .mockImplementationOnce(() => makeTrackedSelectChain([], tracker));

    db.insert
      .mockImplementationOnce(() => makeInsertChain([session]))
      .mockImplementationOnce(() => makeInsertChain([]))
      .mockImplementationOnce(() => makeInsertChain([]));

    await expect(startChecklistSession({
      unitId: 'unit-serial-1',
      checklistType: 'move_in',
      tenantName: 'Marie Tremblay',
      tenantPhone: '(514) 555-0101',
      metadata: { source: 'portal' },
      createdByUserId: 'user-1',
    })).resolves.toEqual(expect.objectContaining({
      session: expect.objectContaining({ id: 'session-serial-1' }),
      summary: expect.objectContaining({ stepCount: 5 }),
    }));
  });

  it('returns a manager-friendly summary projection', async () => {
    const session = {
      id: 'session-2',
      unitId: 'unit-2',
      leaseId: 'lease-1',
      checklistType: 'move_out',
      state: 'completed',
      currentStepKey: null,
      currentStepOrder: 6,
      tenantName: 'Jean Tremblay',
      tenantPhone: '(438) 555-0101',
      startedAt: new Date('2026-05-06T20:00:00.000Z'),
      resumedAt: new Date('2026-05-06T20:10:00.000Z'),
      pausedAt: new Date('2026-05-06T20:20:00.000Z'),
      submittedAt: new Date('2026-05-06T20:30:00.000Z'),
      completedAt: new Date('2026-05-06T20:40:00.000Z'),
      reviewedAt: null,
      createdAt: new Date('2026-05-06T20:00:00.000Z'),
      updatedAt: new Date('2026-05-06T20:40:00.000Z'),
      metadata: {},
    };
    const steps = buildChecklistTemplate('move_out').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-2',
      ...step,
      status: step.stepKey === 'final_acknowledgment' ? 'completed' : 'pending',
    }));

    db.select
      .mockImplementationOnce(() => makeSelectChain([session]))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'unit-2', label: '12B' }]))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'lease-1', unitId: 'unit-2', tenantFirstName: 'Jean', tenantLastName: 'Tremblay' }]))
      .mockImplementationOnce(() => makeSelectChain(steps))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'attachment-1', sessionId: 'session-2', stepId: 'room_photos-id' }]))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'signature-1', sessionId: 'session-2', signatureType: 'tenant_confirmation' }]))
      .mockImplementationOnce(() => makeSelectChain([{ id: 'event-1', sessionId: 'session-2', eventType: 'session_submitted', createdAt: new Date('2026-05-06T20:30:00.000Z') }]));

    const result = await getChecklistSessionSummary({ sessionId: 'session-2' });

    expect(result).toEqual(expect.objectContaining({
      session: expect.objectContaining({
        id: 'session-2',
        state: 'completed',
        startedAt: '2026-05-06T20:00:00.000Z',
        completedAt: '2026-05-06T20:40:00.000Z',
      }),
      unit: expect.objectContaining({ id: 'unit-2', label: '12B' }),
      lease: expect.objectContaining({ id: 'lease-1', unitId: 'unit-2' }),
      steps: expect.any(Array),
      attachments: expect.any(Array),
      signatures: expect.any(Array),
      events: expect.any(Array),
      summary: expect.objectContaining({
        stepCount: 6,
        completedStepCount: 1,
        blockedStepCount: 0,
        pendingStepCount: 5,
        skippedStepCount: 0,
        attachmentCount: 1,
        signatureCount: 1,
        eventCount: 1,
        isComplete: true,
        isPaused: false,
        lastEventAt: '2026-05-06T20:30:00.000Z',
        currentStepKey: null,
        currentStepOrder: 6,
      }),
    }));
  });

  it('pauses and resumes in-progress sessions without losing progress', async () => {
    const baseSteps = buildChecklistTemplate('move_in').map((step, index) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-6',
      ...step,
      status: index === 0 ? 'completed' : index === 1 ? 'blocked' : index === 2 ? 'skipped' : 'pending',
    }));
    const pausedSteps = baseSteps;
    const initialSession = {
      id: 'session-6',
      unitId: 'unit-6',
      leaseId: null,
      checklistType: 'move_in',
      state: 'in_progress',
      currentStepKey: 'room_photos',
      currentStepOrder: 3,
      tenantName: 'Sarah Bouchard',
      tenantPhone: '(581) 555-0190',
      startedAt: new Date('2026-05-07T01:00:00.000Z'),
      resumedAt: new Date('2026-05-07T01:00:00.000Z'),
      pausedAt: null,
      submittedAt: null,
      completedAt: null,
      reviewedAt: null,
      createdAt: new Date('2026-05-07T01:00:00.000Z'),
      updatedAt: new Date('2026-05-07T01:00:00.000Z'),
      metadata: { source: 'portal' },
    };
    const pausedSession = {
      ...initialSession,
      state: 'paused',
      pausedAt: new Date('2026-05-07T01:12:00.000Z'),
      updatedAt: new Date('2026-05-07T01:12:00.000Z'),
      metadata: { source: 'portal', pauseReason: 'coffee break' },
    };
    const resumedSession = {
      ...pausedSession,
      state: 'in_progress',
      resumedAt: new Date('2026-05-07T01:18:00.000Z'),
      pausedAt: new Date('2026-05-07T01:12:00.000Z'),
      updatedAt: new Date('2026-05-07T01:18:00.000Z'),
      metadata: { source: 'portal', pauseReason: 'coffee break', resumedFrom: 'sms' },
    };

    mockSessionGraph(buildGraphSequence([
      {
        session: initialSession,
        unit: { id: 'unit-6', label: '21A' },
        steps: baseSteps,
        events: [
          { id: 'event-start', sessionId: 'session-6', eventType: 'session_started', createdAt: new Date('2026-05-07T01:00:00.000Z') },
        ],
      },
      {
        session: pausedSession,
        unit: { id: 'unit-6', label: '21A' },
        steps: pausedSteps,
        events: [
          { id: 'event-pause', sessionId: 'session-6', eventType: 'session_paused', createdAt: new Date('2026-05-07T01:12:00.000Z') },
          { id: 'event-start', sessionId: 'session-6', eventType: 'session_started', createdAt: new Date('2026-05-07T01:00:00.000Z') },
        ],
      },
    ]));

    const pausedResult = await pauseChecklistSession({
      sessionId: 'session-6',
      pausedByUserId: 'user-6',
      reason: 'coffee break',
      metadata: { pauseReason: 'coffee break' },
    });

    expect(pausedResult.session.state).toBe('paused');
    expect(pausedResult.session.pausedAt).toBe('2026-05-07T01:12:00.000Z');
    expect(pausedResult.summary).toEqual(expect.objectContaining({
      isPaused: true,
      lastEventAt: '2026-05-07T01:12:00.000Z',
      completedStepCount: 1,
      blockedStepCount: 1,
      pendingStepCount: 2,
      skippedStepCount: 1,
      currentStepKey: 'room_photos',
      currentStepOrder: 3,
    }));

    db.select.mockClear();
    db.insert.mockClear();
    db.update.mockClear();
    mockSessionGraph(buildGraphSequence([
      {
        session: pausedSession,
        unit: { id: 'unit-6', label: '21A' },
        steps: pausedSteps,
        events: [
          { id: 'event-pause', sessionId: 'session-6', eventType: 'session_paused', createdAt: new Date('2026-05-07T01:12:00.000Z') },
          { id: 'event-start', sessionId: 'session-6', eventType: 'session_started', createdAt: new Date('2026-05-07T01:00:00.000Z') },
        ],
      },
      {
        session: resumedSession,
        unit: { id: 'unit-6', label: '21A' },
        steps: pausedSteps,
        events: [
          { id: 'event-resume', sessionId: 'session-6', eventType: 'session_resumed', createdAt: new Date('2026-05-07T01:18:00.000Z') },
          { id: 'event-pause', sessionId: 'session-6', eventType: 'session_paused', createdAt: new Date('2026-05-07T01:12:00.000Z') },
          { id: 'event-start', sessionId: 'session-6', eventType: 'session_started', createdAt: new Date('2026-05-07T01:00:00.000Z') },
        ],
      },
    ]));

    const resumedResult = await resumeChecklistSession({
      sessionId: 'session-6',
      resumedByUserId: 'user-6',
      metadata: { resumedFrom: 'sms' },
    });

    expect(resumedResult.session.state).toBe('in_progress');
    expect(resumedResult.session.resumedAt).toBe('2026-05-07T01:18:00.000Z');
    expect(resumedResult.summary).toEqual(expect.objectContaining({
      isPaused: false,
      lastEventAt: '2026-05-07T01:18:00.000Z',
      completedStepCount: 1,
      blockedStepCount: 1,
      pendingStepCount: 2,
      skippedStepCount: 1,
      currentStepKey: 'room_photos',
      currentStepOrder: 3,
    }));
  });

  it('submits paused sessions as awaiting confirmation when steps remain incomplete', async () => {
    const steps = buildChecklistTemplate('move_out').map((step, index) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-7',
      ...step,
      status: index === 0 ? 'completed' : index === 1 ? 'blocked' : index === 2 ? 'skipped' : 'pending',
    }));
    const initialSession = {
      id: 'session-7',
      unitId: 'unit-7',
      leaseId: null,
      checklistType: 'move_out',
      state: 'paused',
      currentStepKey: 'damage_notes',
      currentStepOrder: 5,
      tenantName: 'Julien Roy',
      tenantPhone: '(418) 555-0191',
      startedAt: new Date('2026-05-07T02:00:00.000Z'),
      resumedAt: new Date('2026-05-07T02:05:00.000Z'),
      pausedAt: new Date('2026-05-07T02:10:00.000Z'),
      submittedAt: null,
      completedAt: null,
      reviewedAt: null,
      createdAt: new Date('2026-05-07T02:00:00.000Z'),
      updatedAt: new Date('2026-05-07T02:10:00.000Z'),
      metadata: { source: 'tenant-link' },
    };
    const submittedSession = {
      ...initialSession,
      state: 'awaiting_confirmation',
      submittedAt: new Date('2026-05-07T02:14:00.000Z'),
      updatedAt: new Date('2026-05-07T02:14:00.000Z'),
      metadata: { source: 'tenant-link', confirmationNote: 'Need landlord sign-off' },
    };

    mockSessionGraph(buildGraphSequence([
      {
        session: initialSession,
        unit: { id: 'unit-7', label: '43C' },
        steps,
        events: [
          { id: 'event-pause', sessionId: 'session-7', eventType: 'session_paused', createdAt: new Date('2026-05-07T02:10:00.000Z') },
          { id: 'event-start', sessionId: 'session-7', eventType: 'session_started', createdAt: new Date('2026-05-07T02:00:00.000Z') },
        ],
      },
      {
        session: initialSession,
        unit: { id: 'unit-7', label: '43C' },
        steps,
        events: [
          { id: 'event-pause', sessionId: 'session-7', eventType: 'session_paused', createdAt: new Date('2026-05-07T02:10:00.000Z') },
          { id: 'event-start', sessionId: 'session-7', eventType: 'session_started', createdAt: new Date('2026-05-07T02:00:00.000Z') },
        ],
      },
      {
        session: submittedSession,
        unit: { id: 'unit-7', label: '43C' },
        steps,
        events: [
          { id: 'event-submit', sessionId: 'session-7', eventType: 'session_submitted', createdAt: new Date('2026-05-07T02:14:00.000Z') },
          { id: 'event-pause', sessionId: 'session-7', eventType: 'session_paused', createdAt: new Date('2026-05-07T02:10:00.000Z') },
          { id: 'event-start', sessionId: 'session-7', eventType: 'session_started', createdAt: new Date('2026-05-07T02:00:00.000Z') },
        ],
      },
    ]));

    const result = await submitChecklistSession({
      sessionId: 'session-7',
      submittedByUserId: 'user-7',
      forceComplete: false,
      stepUpdates: [],
      attachments: [],
      signatures: [],
      metadata: { confirmationNote: 'Need landlord sign-off' },
    });

    expect(result.session.state).toBe('awaiting_confirmation');
    expect(result.session.submittedAt).toBe('2026-05-07T02:14:00.000Z');
    expect(result.session.completedAt).toBeNull();
    expect(result.summary).toEqual(expect.objectContaining({
      isComplete: false,
      isPaused: false,
      pendingStepCount: 3,
      blockedStepCount: 1,
      skippedStepCount: 1,
      completedStepCount: 1,
      lastEventAt: '2026-05-07T02:14:00.000Z',
      currentStepKey: 'damage_notes',
      currentStepOrder: 5,
    }));
  });

  it('rejects pause and resume attempts on completed sessions', async () => {
    const completedSession = {
      id: 'session-8',
      unitId: 'unit-8',
      leaseId: null,
      checklistType: 'move_in',
      state: 'completed',
      currentStepKey: null,
      currentStepOrder: 5,
      tenantName: 'Mélissa Gagné',
      tenantPhone: '(450) 555-0192',
      startedAt: new Date('2026-05-07T03:00:00.000Z'),
      resumedAt: new Date('2026-05-07T03:00:00.000Z'),
      pausedAt: null,
      submittedAt: new Date('2026-05-07T03:20:00.000Z'),
      completedAt: new Date('2026-05-07T03:20:00.000Z'),
      reviewedAt: null,
      createdAt: new Date('2026-05-07T03:00:00.000Z'),
      updatedAt: new Date('2026-05-07T03:20:00.000Z'),
      metadata: {},
    };
    const steps = buildChecklistTemplate('move_in').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-8',
      ...step,
      status: 'completed',
    }));

    mockSessionGraph([
      [completedSession],
      [{ id: 'unit-8', label: '9D' }],
      [steps],
      [],
      [],
      [{ id: 'event-8', sessionId: 'session-8', eventType: 'session_submitted', createdAt: new Date('2026-05-07T03:20:00.000Z') }],
    ]);

    await expect(pauseChecklistSession({
      sessionId: 'session-8',
      pausedByUserId: 'user-8',
      reason: 'should fail',
      metadata: {},
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'CHECKLIST_SESSION_NOT_PAUSABLE',
    });

    await expect(resumeChecklistSession({
      sessionId: 'session-8',
      resumedByUserId: 'user-8',
      metadata: {},
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'CHECKLIST_SESSION_NOT_RESUMABLE',
    });
  });

  it('rejects resume attempts on reviewed sessions', async () => {
    const reviewedSession = {
      id: 'session-4',
      unitId: 'unit-4',
      leaseId: null,
      checklistType: 'move_out',
      state: 'reviewed',
      currentStepKey: null,
      currentStepOrder: 6,
      tenantName: 'Lucie Morin',
      tenantPhone: '(418) 555-0144',
      startedAt: new Date('2026-05-06T22:00:00.000Z'),
      resumedAt: new Date('2026-05-06T22:10:00.000Z'),
      pausedAt: null,
      submittedAt: new Date('2026-05-06T22:20:00.000Z'),
      completedAt: new Date('2026-05-06T22:20:00.000Z'),
      reviewedAt: new Date('2026-05-06T22:30:00.000Z'),
      createdAt: new Date('2026-05-06T22:00:00.000Z'),
      updatedAt: new Date('2026-05-06T22:30:00.000Z'),
      metadata: {},
    };
    const unit = { id: 'unit-4', label: '18C' };
    const steps = buildChecklistTemplate('move_out').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-4',
      ...step,
    }));

    mockSessionGraph([
      [reviewedSession],
      [unit],
      steps,
      [],
      [],
      [],
    ]);

    await expect(resumeChecklistSession({
      sessionId: 'session-4',
      resumedByUserId: 'user-2',
      metadata: { source: 'retry' },
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'CHECKLIST_SESSION_NOT_RESUMABLE',
    });
  });

  it('rejects pause attempts on reviewed sessions', async () => {
    const reviewedSession = {
      id: 'session-5',
      unitId: 'unit-5',
      leaseId: null,
      checklistType: 'move_in',
      state: 'reviewed',
      currentStepKey: null,
      currentStepOrder: 5,
      tenantName: 'Anne Gagnon',
      tenantPhone: '(581) 555-0188',
      startedAt: new Date('2026-05-06T23:00:00.000Z'),
      resumedAt: new Date('2026-05-06T23:00:00.000Z'),
      pausedAt: null,
      submittedAt: new Date('2026-05-06T23:20:00.000Z'),
      completedAt: new Date('2026-05-06T23:20:00.000Z'),
      reviewedAt: new Date('2026-05-06T23:30:00.000Z'),
      createdAt: new Date('2026-05-06T23:00:00.000Z'),
      updatedAt: new Date('2026-05-06T23:30:00.000Z'),
      metadata: {},
    };
    const unit = { id: 'unit-5', label: '9D' };
    const steps = buildChecklistTemplate('move_in').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-5',
      ...step,
    }));

    mockSessionGraph([
      [reviewedSession],
      [unit],
      steps,
      [],
      [],
      [],
    ]);

    await expect(pauseChecklistSession({
      sessionId: 'session-5',
      pausedByUserId: 'user-3',
      reason: 'Interrupted',
      metadata: { source: 'retry' },
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'CHECKLIST_SESSION_NOT_PAUSABLE',
    });
  });

  it('rejects submit attempts after a session is completed', async () => {
    const completedSession = {
      id: 'session-3',
      unitId: 'unit-3',
      leaseId: null,
      checklistType: 'move_in',
      state: 'completed',
      currentStepKey: null,
      currentStepOrder: 5,
      tenantName: 'Sophie Roy',
      tenantPhone: '(450) 555-0199',
      startedAt: new Date('2026-05-06T21:00:00.000Z'),
      resumedAt: new Date('2026-05-06T21:00:00.000Z'),
      pausedAt: null,
      submittedAt: new Date('2026-05-06T21:20:00.000Z'),
      completedAt: new Date('2026-05-06T21:20:00.000Z'),
      reviewedAt: null,
      createdAt: new Date('2026-05-06T21:00:00.000Z'),
      updatedAt: new Date('2026-05-06T21:20:00.000Z'),
      metadata: {},
    };
    const unit = { id: 'unit-3', label: '5A' };
    const steps = buildChecklistTemplate('move_in').map((step) => ({
      id: `${step.stepKey}-id`,
      sessionId: 'session-3',
      ...step,
      status: step.stepKey === 'final_acknowledgment' ? 'completed' : 'pending',
    }));

    mockSessionGraph([
      [completedSession],
      [unit],
      steps,
      [],
      [],
      [],
    ]);

    await expect(submitChecklistSession({
      sessionId: 'session-3',
      submittedByUserId: 'user-1',
      forceComplete: false,
      stepUpdates: [],
      attachments: [],
      signatures: [],
      metadata: { source: 'retry' },
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'CHECKLIST_SESSION_IMMUTABLE',
      message: 'La session complétée est immuable',
    });
  });
});
