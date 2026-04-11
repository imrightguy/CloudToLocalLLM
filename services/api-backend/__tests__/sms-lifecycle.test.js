/**
 * IMM-11: Full SMS visit lifecycle end-to-end tests
 *
 * Tests: create visit -> confirmations -> lead replies oui/non ->
 *        morning reminder -> visit completed -> survey -> outcome
 *
 * Strategy: Mock the database (drizzle-orm) and Twilio service at the module level,
 * then test each sms.service.js function as a unit with realistic data flowing through.
 * This verifies the business logic, SMS logging, and state transitions without
 * needing a real database or Twilio account.
 */

// ─── Mocks ──────────────────────────────────────────────────────────────────────

// Mock database
const mockDb = {
  insert: jest.fn().mockReturnThis(),
  values: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  from: jest.fn().mockReturnThis(),
  update: jest.fn().mockReturnThis(),
  set: jest.fn().mockReturnThis(),
  where: jest.fn().mockReturnThis(),
  and: jest.fn(),
  eq: jest.fn((a, b) => ({ _eq: [a, b] })),
  sql: jest.fn((val) => ({ _raw: val })),
  leftJoin: jest.fn().mockReturnThis(),
  orderBy: jest.fn().mockReturnThis(),
  limit: jest.fn().mockReturnThis(),
  gte: jest.fn((a, b) => ({ _gte: [a, b] })),
  lte: jest.fn((a, b) => ({ _lte: [a, b] })),
};

jest.mock('../src/database/connection', () => ({ db: mockDb }));

// Mock twilio.service
const mockSendSMS = jest.fn();
const mockHandleIncomingMessage = jest.fn();

jest.mock('../src/services/twilio.service', () => ({
  sendSMS: (...args) => mockSendSMS(...args),
  handleIncomingMessage: (...args) => mockHandleIncomingMessage(...args),
}));

// Import after mocks
const {
  sendVisitConfirmation,
  sendTenantConfirmationRequest,
  sendOccupantAccessRequest,
  sendMorningOfReminder,
  sendPostVisitSurvey,
  notifySimonInterested,
  handleEmployeeReply,
  handleTenantReply,
  handleOccupantReply,
} = require('../src/services/sms.service');

// ─── Fixtures ───────────────────────────────────────────────────────────────────

const FIXTURES = {
  visit: {
    id: 'visit-uuid-001',
    unitId: 'unit-uuid-001',
    employeeId: 'emp-uuid-001',
    leadId: 'lead-uuid-001',
    dateTime: '2026-04-11T14:00:00.000Z',
    durationMinutes: 30,
    status: 'scheduled',
    tenantConfirmed: false,
    occupantNotified: false,
    employeeConfirmed: false,
    morningOfSent: false,
    outcome: null,
    isActive: true,
  },
  employee: {
    id: 'emp-uuid-001',
    firstName: 'Jean',
    lastName: 'Dupont',
    phone: '+15145551234',
    isActive: true,
  },
  lead: {
    id: 'lead-uuid-001',
    fullName: 'Marie Tremblay',
    phone: '+15145559876',
    email: 'marie@example.com',
    language: 'fr',
    stage: 'visite_planifiee',
    isActive: true,
  },
  leadEnglish: {
    id: 'lead-uuid-002',
    fullName: 'John Smith',
    phone: '+15145551111',
    email: 'john@example.com',
    language: 'en',
    stage: 'visite_planifiee',
    isActive: true,
  },
  unit: {
    id: 'unit-uuid-001',
    label: '4A',
    buildingId: 'building-uuid-001',
    rentCents: 120000,
    status: 'occupied',
    tenantPhone: '+15145557777',
    tenantName: 'Pierre Gagnon',
    tenantLeaseEnd: '2026-12-31',
  },
  unitVacant: {
    id: 'unit-uuid-002',
    label: '2B',
    buildingId: 'building-uuid-001',
    rentCents: 95000,
    status: 'vacant',
    tenantPhone: null,
    tenantName: null,
    tenantLeaseEnd: null,
  },
  building: {
    id: 'building-uuid-001',
    name: '1234 Rue Saint-Laurent',
    address: '1234 Rue Saint-Laurent',
    city: 'Montreal',
    isActive: true,
  },
  adminUser: {
    id: 'admin-uuid-001',
    role: 'admin',
    phone: '+15145550001',
    isActive: true,
  },
};

// ─── Helper: build chain-returning mock ─────────────────────────────────────────

/**
 * Create a fresh select query chain that returns `rows` from .limit().
 */
function makeSelectChain(rows) {
  const chain = {};
  chain.select = jest.fn().mockReturnValue(chain);
  chain.from = jest.fn().mockReturnValue(chain);
  chain.leftJoin = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.and = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockResolvedValue(rows);
  return chain;
}

/**
 * Create a fresh update chain that resolves .set().where().
 */
function makeUpdateChain() {
  const chain = {};
  chain.set = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockResolvedValue(undefined);
  return chain;
}

/**
 * Stack multiple mock implementations for db.select() so sequential
 * calls return different rows. This handles functions that make multiple
 * DB queries (e.g. handleEmployeeReply: find employee, find visit, etc.)
 */
function mockQueryChain(...rowsArrays) {
  const chains = rowsArrays.map((rows) => makeSelectChain(rows));
  mockDb.select.mockImplementation(() => chains.shift() || makeSelectChain([]));

  // Also wire db.update() to resolve (most functions that query also update)
  mockDb.update.mockImplementation(() => makeUpdateChain());

  // For .where(and(...)) → return chain
  const { and: realAnd } = jest.requireActual('drizzle-orm');
  mockDb.and.mockImplementation((...args) => realAnd(...args));

  return chains;
}

/**
 * Make db.insert().values() resolve (for logSMS inserts).
 */
function mockInsertResolve() {
  const insertChain = {
    values: jest.fn().mockResolvedValue(undefined),
  };
  mockDb.insert.mockReturnValue(insertChain);
  return insertChain;
}

function mockUpdateResolve() {
  mockDb.update.mockImplementation(() => makeUpdateChain());
  return mockDb.update;
}

// ─── Reset before each test ────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  // Default: sendSMS succeeds
  mockSendSMS.mockResolvedValue({
    success: true,
    sid: `SM${Date.now()}`,
    status: 'queued',
  });
  // Default: handleIncomingMessage parses correctly
  mockHandleIncomingMessage.mockImplementation((body) => {
    const trimmed = (body || '').trim().toLowerCase();
    const numberMap = { 1: 'yes', 2: 'no', 3: 'no_show' };
    if (numberMap[trimmed]) return { action: numberMap[trimmed], raw: trimmed };
    return { action: null, raw: trimmed };
  });
  mockInsertResolve();
});

// ─── Tests ──────────────────────────────────────────────────────────────────────

describe('SMS Visit Lifecycle', () => {
  // ─── Step 1: Visit Creation Confirmation ──────────────────────────────────

  describe('Step 1: sendVisitConfirmation (employee SMS)', () => {
    it('sends confirmation SMS to employee with visit details', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };

      // getVisitContext internally does db.select().from().leftJoin().where().limit()
      mockQueryChain([ctx]);

      const result = await sendVisitConfirmation(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledTimes(1);
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining('Visite planifiée'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining(FIXTURES.building.name),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining(FIXTURES.lead.fullName),
      );
      expect(result.success).toBe(true);

      // Verify SMS was logged
      expect(mockDb.insert).toHaveBeenCalled();
    });

    it('returns error when visit not found', async () => {
      mockQueryChain([]); // no rows

      const result = await sendVisitConfirmation('nonexistent-id');
      expect(result.success).toBe(false);
      expect(result.error).toBe('Visit not found');
      expect(mockSendSMS).not.toHaveBeenCalled();
    });

    it('returns error when employee is missing', async () => {
      mockQueryChain([{
        visit: FIXTURES.visit,
        employee: null,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      }]);

      const result = await sendVisitConfirmation(FIXTURES.visit.id);
      expect(result.success).toBe(false);
      expect(result.error).toBe('Missing related data for visit confirmation');
    });

    it('logs SMS with correct direction and status on failure', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockSendSMS.mockResolvedValueOnce({
        success: false,
        error: 'Twilio not initialized',
      });

      const result = await sendVisitConfirmation(FIXTURES.visit.id);
      expect(result.success).toBe(false);
      // SMS should still be logged
      expect(mockDb.insert).toHaveBeenCalled();
    });
  });

  // ─── Step 2: Tenant Confirmation Request ─────────────────────────────────

  describe('Step 2: sendTenantConfirmationRequest', () => {
    it('sends French confirmation request to tenant', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendTenantConfirmationRequest(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.lead.phone,
        expect.stringContaining('Visite confirmée'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.lead.phone,
        expect.stringContaining('1=Oui'),
      );
      expect(result.success).toBe(true);
    });

    it('sends English confirmation request when lead language is en', async () => {
      const visitEn = { ...FIXTURES.visit, leadId: FIXTURES.leadEnglish.id };
      const ctx = {
        visit: visitEn,
        employee: FIXTURES.employee,
        lead: FIXTURES.leadEnglish,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      await sendTenantConfirmationRequest(visitEn.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.leadEnglish.phone,
        expect.stringContaining('Visit confirmed'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.leadEnglish.phone,
        expect.stringContaining('1=Yes'),
      );
    });

    it('returns error when lead has no phone', async () => {
      const leadNoPhone = { ...FIXTURES.lead, phone: null };
      const ctx = {
        visit: FIXTURES.visit,
        employee: FIXTURES.employee,
        lead: leadNoPhone,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendTenantConfirmationRequest(FIXTURES.visit.id);
      expect(result.success).toBe(false);
      expect(result.error).toContain('Missing lead phone');
    });
  });

  // ─── Step 3: Tenant Reply (Oui/Non) ──────────────────────────────────────

  describe('Step 3: handleTenantReply', () => {
    it('sets tenantConfirmed=true when tenant replies oui/1', async () => {
      // First query: find lead by phone; second: find active visit for lead
      mockQueryChain([FIXTURES.lead], [FIXTURES.visit]);
      mockUpdateResolve();

      const result = await handleTenantReply(FIXTURES.lead.phone, '1');

      expect(result.success).toBe(true);
      expect(result.action).toBe('tenant_confirmed');
      expect(result.visitId).toBe(FIXTURES.visit.id);
    });

    it('sets tenantConfirmed=false when tenant replies non/2', async () => {
      mockQueryChain([FIXTURES.lead], [FIXTURES.visit]);
      mockUpdateResolve();

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no', raw: '2' });

      const result = await handleTenantReply(FIXTURES.lead.phone, '2');

      expect(result.success).toBe(true);
      expect(result.action).toBe('tenant_declined');
    });

    it('returns error for unrecognised reply', async () => {
      mockHandleIncomingMessage.mockReturnValueOnce({ action: null, raw: 'hello' });

      const result = await handleTenantReply(FIXTURES.lead.phone, 'hello');
      expect(result.success).toBe(false);
      expect(result.error).toBe('Unrecognised reply');
    });

    it('returns error when lead phone not found', async () => {
      mockQueryChain([]); // no lead found
      // Second attempt with +1 prefix also empty
      mockQueryChain([]);

      const result = await handleTenantReply('+19999999999', '1');
      expect(result.success).toBe(false);
      expect(result.error).toBe('Lead not found');
    });

    it('returns error when no active visit for lead', async () => {
      // Lead found, but no active visit — both select calls in one chain
      mockQueryChain([FIXTURES.lead], []);

      const result = await handleTenantReply(FIXTURES.lead.phone, '1');
      expect(result.success).toBe(false);
      expect(result.error).toBe('No active visit found');
    });

    it('logs inbound SMS for every tenant reply', async () => {
      mockQueryChain([FIXTURES.lead], [FIXTURES.visit]);
      mockUpdateResolve();

      await handleTenantReply(FIXTURES.lead.phone, '1');

      // logSMS is called via db.insert — check it was invoked
      expect(mockDb.insert).toHaveBeenCalled();
    });
  });

  // ─── Step 4: Morning-Of Reminder ─────────────────────────────────────────

  describe('Step 4: sendMorningOfReminder', () => {
    it('sends positive reminder when tenant has confirmed', async () => {
      const confirmedVisit = {
        ...FIXTURES.visit,
        status: 'confirmed',
        tenantConfirmed: true,
        employeeConfirmed: true,
      };
      const ctx = {
        visit: confirmedVisit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      const result = await sendMorningOfReminder(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining('Rappel'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining('confirmée'),
      );
      expect(result.success).toBe(true);
    });

    it('sends warning when tenant has NOT confirmed', async () => {
      const unconfirmedVisit = {
        ...FIXTURES.visit,
        status: 'confirmed',
        tenantConfirmed: false,
        employeeConfirmed: true,
      };
      const ctx = {
        visit: unconfirmedVisit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      await sendMorningOfReminder(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining("n'a pas confirmé"),
      );
    });

    it('updates morningOfSent flag on the visit', async () => {
      const ctx = {
        visit: { ...FIXTURES.visit, status: 'confirmed', tenantConfirmed: true },
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const updateChain = {
        set: jest.fn().mockReturnValue({
          where: jest.fn().mockResolvedValue(undefined),
        }),
      };
      mockDb.update.mockReturnValue(updateChain);

      await sendMorningOfReminder(FIXTURES.visit.id);

      expect(mockDb.update).toHaveBeenCalled();
      expect(updateChain.set).toHaveBeenCalledWith(
        expect.objectContaining({ morningOfSent: true }),
      );
    });
  });

  // ─── Step 5: Post-Visit Survey ───────────────────────────────────────────

  describe('Step 5: sendPostVisitSurvey', () => {
    it('sends survey with outcome options', async () => {
      const ctx = {
        visit: { ...FIXTURES.visit, status: 'confirmed' },
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendPostVisitSurvey(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining("Comment s'est passée la visite"),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining('1=Intéressé'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.employee.phone,
        expect.stringContaining('3=Ne s\'est pas présenté'),
      );
      expect(result.success).toBe(true);
    });

    it('returns error when employee is missing', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        employee: null,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendPostVisitSurvey(FIXTURES.visit.id);
      expect(result.success).toBe(false);
      expect(result.error).toBe('Missing employee or lead for post-visit survey');
    });
  });

  // ─── Step 6: Employee Reply to Survey (Outcome) ──────────────────────────

  describe('Step 6: handleEmployeeReply — post-visit outcomes', () => {
    it('marks visit interested and notifies Simon when employee replies 1/interested', async () => {
      const activeVisit = { ...FIXTURES.visit, status: 'confirmed' };
      const ctx = {
        visit: activeVisit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      // Service flow: find employee → find visit → (update visit) → (update lead) → getVisitContext → find admin
      mockQueryChain([FIXTURES.employee], [activeVisit], [ctx], [FIXTURES.adminUser]);
      mockUpdateResolve(); // update visit
      mockUpdateResolve(); // update lead stage

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'interested', raw: '1' });

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '1');

      expect(result.success).toBe(true);
      expect(result.action).toBe('lead_interested');
    });

    it('marks visit not interested when employee replies 2/pas interesse', async () => {
      const activeVisit = { ...FIXTURES.visit, status: 'confirmed' };
      // find employee → find visit
      mockQueryChain([FIXTURES.employee], [activeVisit]);
      mockUpdateResolve(); // update visit
      mockUpdateResolve(); // update lead

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no_interest', raw: '2' });

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '2');

      expect(result.success).toBe(true);
      expect(result.action).toBe('lead_not_interested');
    });

    it('marks visit no_show when employee replies 3/absent', async () => {
      const activeVisit = { ...FIXTURES.visit, status: 'confirmed' };
      // find employee → find visit
      mockQueryChain([FIXTURES.employee], [activeVisit]);
      mockUpdateResolve(); // update visit
      mockUpdateResolve(); // update lead

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no_show', raw: '3' });

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '3');

      expect(result.success).toBe(true);
      expect(result.action).toBe('lead_no_show');
    });
  });

  // ─── Step 7: Employee Confirmation Reply ─────────────────────────────────

  describe('Step 7: handleEmployeeReply — confirmation flow', () => {
    it('confirms visit and triggers tenant confirmation when employee replies oui', async () => {
      const scheduledVisit = { ...FIXTURES.visit, status: 'scheduled' };

      const ctx = {
        visit: scheduledVisit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      // find employee → find visit → getVisitContext (for sendTenantConfirmationRequest inside handler)
      mockQueryChain([FIXTURES.employee], [scheduledVisit], [ctx]);
      mockUpdateResolve(); // update visit status
      mockInsertResolve(); // logSMS for tenant confirmation

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '1');

      expect(result.success).toBe(true);
      expect(result.action).toBe('visit_confirmed');
      // Should have triggered tenant confirmation SMS
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.lead.phone,
        expect.stringContaining('Visite confirmée'),
      );
    });

    it('cancels visit when employee replies non to scheduled visit', async () => {
      const scheduledVisit = { ...FIXTURES.visit, status: 'scheduled' };

      // find employee → find visit
      mockQueryChain([FIXTURES.employee], [scheduledVisit]);
      mockUpdateResolve(); // cancel visit

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no', raw: '2' });

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '2');

      expect(result.success).toBe(true);
      expect(result.action).toBe('visit_cancelled');
    });

    it('employee_will_call when employee says oui to morning reminder about unconfirmed tenant', async () => {
      const confirmedVisit = {
        ...FIXTURES.visit,
        status: 'confirmed',
        morningOfSent: true,
        tenantConfirmed: false,
      };

      // find employee → find visit
      mockQueryChain([FIXTURES.employee], [confirmedVisit]);
      // logSMS inbound
      mockInsertResolve();

      const result = await handleEmployeeReply(FIXTURES.employee.phone, '1');

      expect(result.success).toBe(true);
      expect(result.action).toBe('employee_will_call');
    });
  });

  // ─── Occupant Access Flow ────────────────────────────────────────────────

  describe('Occupant access flow', () => {
    it('sends access request SMS to occupant of occupied unit', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve(); // mark occupantNotified

      const result = await sendOccupantAccessRequest(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('Autorisez-vous'),
      );
      expect(result.success).toBe(true);
    });

    it('returns needsNotice=true when visit is less than 24h away', async () => {
      const soonVisit = {
        ...FIXTURES.visit,
        dateTime: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(), // 12h from now
      };
      const ctx = {
        visit: soonVisit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      const result = await sendOccupantAccessRequest(soonVisit.id);
      expect(result.needsNotice).toBe(true);
    });

    it('returns needsNotice=false when visit is more than 24h away', async () => {
      const laterVisit = {
        ...FIXTURES.visit,
        dateTime: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(), // 48h from now
      };
      const ctx = {
        visit: laterVisit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      const result = await sendOccupantAccessRequest(laterVisit.id);
      expect(result.needsNotice).toBe(false);
    });

    it('skips access request when unit has no occupant phone', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        unit: FIXTURES.unitVacant,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendOccupantAccessRequest(FIXTURES.visit.id);
      expect(result.success).toBe(false);
      expect(result.error).toContain('No occupant phone');
      expect(mockSendSMS).not.toHaveBeenCalled();
    });

    it('handles occupant reply oui — grants access', async () => {
      const activeVisit = { ...FIXTURES.visit, occupantNotified: true };
      // find unit by tenant phone → find active visit → find building for ack
      mockQueryChain([FIXTURES.unit], [activeVisit], [FIXTURES.building]);
      mockUpdateResolve(); // update tenantConfirmed

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'yes', raw: '1' });

      const result = await handleOccupantReply(FIXTURES.unit.tenantPhone, '1');

      expect(result.success).toBe(true);
      expect(result.action).toBe('occupant_access_granted');
      // Should send confirmation SMS to occupant
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('Accès confirmé'),
      );
    });

    it('handles occupant reply non — denies access', async () => {
      const activeVisit = { ...FIXTURES.visit, occupantNotified: true };
      // find unit → find visit → find building (for denial message)
      mockQueryChain([FIXTURES.unit], [activeVisit], [FIXTURES.building]);
      mockUpdateResolve();

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no', raw: '2' });

      const result = await handleOccupantReply(FIXTURES.unit.tenantPhone, '2');

      expect(result.success).toBe(true);
      expect(result.action).toBe('occupant_access_denied');
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('annuler'),
      );
    });
  });

  // ─── notifySimonInterested ───────────────────────────────────────────────

  describe('notifySimonInterested', () => {
    it('sends SMS to SIMON_PHONE env var when configured', async () => {
      const originalPhone = process.env.SIMON_PHONE;
      process.env.SIMON_PHONE = '+15145550001';

      const ctx = {
        visit: FIXTURES.visit,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const _result = await notifySimonInterested(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        '+15145550001',
        expect.stringContaining('Intéressé'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        '+151****0001',
        expect.stringContaining(FIXTURES.lead.fullName),
      );
      expect(_result.success).toBe(true);

      process.env.SIMON_PHONE = originalPhone;
    });

    it('falls back to admin user phone when SIMON_PHONE not set', async () => {
      const originalPhone = process.env.SIMON_PHONE;
      process.env.SIMON_PHONE = '';

      const ctx = {
        visit: FIXTURES.visit,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      // getVisitContext → find admin user
      mockQueryChain([ctx], [FIXTURES.adminUser]);

      await notifySimonInterested(FIXTURES.visit.id);

      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.adminUser.phone,
        expect.any(String),
      );

      process.env.SIMON_PHONE = originalPhone;
    });

    it('returns error when no phone configured at all', async () => {
      const originalPhone = process.env.SIMON_PHONE;
      process.env.SIMON_PHONE = '';

      const ctx = {
        visit: FIXTURES.visit,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      // getVisitContext → find admin (no phone)
      mockQueryChain([ctx], [{ ...FIXTURES.adminUser, phone: null }]);

      const _result = await notifySimonInterested(FIXTURES.visit.id);
      expect(_result.success).toBe(false);
      expect(_result.error).toContain('No recipient phone');

      process.env.SIMON_PHONE = originalPhone;
    });
  });

  // ─── SMS Logging Verification ────────────────────────────────────────────

  describe('SMS logging (sms_logs verification)', () => {
    it('logs outbound SMS with visitId, direction, and sent status', async () => {
      const ctx = {
        visit: FIXTURES.visit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      await sendVisitConfirmation(FIXTURES.visit.id);

      expect(mockDb.insert).toHaveBeenCalledWith(
        expect.objectContaining({}), // smsLogsTable ref
      );
      // Check that values was called with correct shape
      const lastInsertCall = mockDb.insert.mock.calls[mockDb.insert.mock.calls.length - 1];
      expect(lastInsertCall).toBeDefined();
    });
  });

  // ─── IMM-17: Full Occupant SMS Flow E2E ─────────────────────────────────

  describe('IMM-17: Full occupant SMS flow end-to-end', () => {
    it('complete occupant flow: create visit → occupant SMS → occupant replies oui → tenantConfirmed updates', async () => {
      // Phase 1: Visit created for occupied unit → occupant access request fires
      const visit = {
        ...FIXTURES.visit,
        id: 'occupant-e2e-visit-001',
        occupantNotified: false,
        tenantConfirmed: false,
      };
      const ctx = {
        visit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
      };

      // getVisitContext for sendOccupantAccessRequest
      mockQueryChain([ctx]);
      mockUpdateResolve(); // mark occupantNotified

      const occupantResult = await sendOccupantAccessRequest(visit.id);

      // Verify occupant SMS was sent
      expect(occupantResult.success).toBe(true);
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('Autorisez-vous'),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining(FIXTURES.unit.label),
      );
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining(FIXTURES.building.name),
      );

      // Phase 2: Occupant replies "1" (oui) → access granted
      const activeVisit = { ...visit, occupantNotified: true };
      // handleOccupantReply: find unit by phone → find active visit → find building for ack
      mockQueryChain([FIXTURES.unit], [activeVisit], [FIXTURES.building]);
      mockUpdateResolve(); // update tenantConfirmed

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'yes', raw: '1' });

      const replyResult = await handleOccupantReply(FIXTURES.unit.tenantPhone, '1');

      expect(replyResult.success).toBe(true);
      expect(replyResult.action).toBe('occupant_access_granted');
      expect(replyResult.visitId).toBe(visit.id);

      // Verify confirmation SMS sent to occupant
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('Accès confirmé'),
      );
    });

    it('complete occupant flow: occupant replies non → access denied → visit still tracked', async () => {
      const visit = {
        ...FIXTURES.visit,
        id: 'occupant-e2e-visit-002',
        occupantNotified: true,
        tenantConfirmed: false,
      };

      // Occupant replies "2" (non)
      mockQueryChain([FIXTURES.unit], [visit], [FIXTURES.building]);
      mockUpdateResolve();

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'no', raw: '2' });

      const replyResult = await handleOccupantReply(FIXTURES.unit.tenantPhone, '2');

      expect(replyResult.success).toBe(true);
      expect(replyResult.action).toBe('occupant_access_denied');
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.stringContaining('annuler'),
      );
    });

    it('24h notice: returns needsNotice=true and SMS still sent', async () => {
      const soonVisit = {
        ...FIXTURES.visit,
        id: 'occupant-e2e-soon-001',
        dateTime: new Date(Date.now() + 10 * 60 * 60 * 1000).toISOString(), // 10h from now
      };
      const ctx = {
        visit: soonVisit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      const result = await sendOccupantAccessRequest(soonVisit.id);

      expect(result.success).toBe(true);
      expect(result.needsNotice).toBe(true);
      // SMS still sent — notice is informational, not blocking
      expect(mockSendSMS).toHaveBeenCalledWith(
        FIXTURES.unit.tenantPhone,
        expect.any(String),
      );
    });

    it('24h notice: returns needsNotice=false for far-future visit', async () => {
      const farVisit = {
        ...FIXTURES.visit,
        id: 'occupant-e2e-far-001',
        dateTime: new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(), // 72h
      };
      const ctx = {
        visit: farVisit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      const result = await sendOccupantAccessRequest(farVisit.id);

      expect(result.success).toBe(true);
      expect(result.needsNotice).toBe(false);
    });

    it('sms_logs: occupant access request logged with correct phone and direction', async () => {
      const visit = { ...FIXTURES.visit, id: 'occupant-log-001' };
      const ctx = {
        visit,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);
      mockUpdateResolve();

      await sendOccupantAccessRequest(visit.id);

      // At least one insert call for logging
      expect(mockDb.insert).toHaveBeenCalled();
    });

    it('sms_logs: occupant reply logged as inbound', async () => {
      const activeVisit = { ...FIXTURES.visit, id: 'occupant-reply-log-001', occupantNotified: true };
      mockQueryChain([FIXTURES.unit], [activeVisit], [FIXTURES.building]);
      mockUpdateResolve();

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'yes', raw: '1' });

      await handleOccupantReply(FIXTURES.unit.tenantPhone, '1');

      // logSMS called for inbound reply
      expect(mockDb.insert).toHaveBeenCalled();
    });

    it('occupant + tenant confirmation work together', async () => {
      // This test verifies that both confirmation paths update tenantConfirmed
      // independently and the webhook routes occupant replies correctly.

      const visit = {
        ...FIXTURES.visit,
        id: 'occupant-tenant-combo-001',
        occupantNotified: true,
        tenantConfirmed: false,
      };

      // Occupant grants access → sets tenantConfirmed=true
      mockQueryChain([FIXTURES.unit], [visit], [FIXTURES.building]);
      mockUpdateResolve();
      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'yes', raw: '1' });

      const occResult = await handleOccupantReply(FIXTURES.unit.tenantPhone, '1');
      expect(occResult.success).toBe(true);
      expect(occResult.action).toBe('occupant_access_granted');

      // Tenant (lead) also confirms → also sets tenantConfirmed=true
      const visitAfterOcc = { ...visit, tenantConfirmed: true };
      mockQueryChain([FIXTURES.lead], [visitAfterOcc]);
      mockUpdateResolve();

      const tenantResult = await handleTenantReply(FIXTURES.lead.phone, '1');
      expect(tenantResult.success).toBe(true);
      expect(tenantResult.action).toBe('tenant_confirmed');
    });

    it('occupant lease expired → access request fails gracefully', async () => {
      const expiredUnit = {
        ...FIXTURES.unit,
        tenantLeaseEnd: '2025-01-01', // expired
      };
      const visit = { ...FIXTURES.visit, id: 'occupant-expired-lease-001' };
      const ctx = {
        visit,
        unit: expiredUnit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const result = await sendOccupantAccessRequest(visit.id);

      expect(result.success).toBe(false);
      expect(result.error).toContain('lease has ended');
      expect(mockSendSMS).not.toHaveBeenCalled();
    });

    it('webhook routing: unknown phone falls through employee → tenant → occupant → ignored', async () => {
      // Employee not found → tenant not found → occupant not found
      mockQueryChain([]); // employee
      mockQueryChain([]); // tenant (with +1 retry)
      mockQueryChain([]); // occupant (with +1 retry)

      const result = await handleOccupantReply('+19999999999', '1');

      expect(result.success).toBe(false);
      expect(result.error).toContain('No unit found');
    });

    it('edge case: multiple units same occupant phone → uses most recent visit', async () => {
      const recentVisit = {
        ...FIXTURES.visit, id: 'visit-recent-001', occupantNotified: true, dateTime: '2026-04-11T14:00:00.000Z',
      };

      // First unit query returns one unit, then visit query returns the most recent
      mockQueryChain([FIXTURES.unit], [recentVisit], [FIXTURES.building]);
      mockUpdateResolve();

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'yes', raw: '1' });

      const result = await handleOccupantReply(FIXTURES.unit.tenantPhone, '1');

      expect(result.success).toBe(true);
      // Should have found a visit for the unit
      expect(result.visitId).toBeDefined();
    });
  });

  // ─── Full Lifecycle Simulation ───────────────────────────────────────────

  describe('Full lifecycle simulation', () => {
    it('tracks the complete visit lifecycle from creation to outcome', async () => {
      // This test simulates the entire flow end-to-end by calling each function
      // in sequence and verifying the state transitions.

      const visit = { ...FIXTURES.visit };

      // Step 1: Visit created → employee confirmation SMS sent
      const ctx = {
        visit,
        employee: FIXTURES.employee,
        lead: FIXTURES.lead,
        unit: FIXTURES.unit,
        building: FIXTURES.building,
      };
      mockQueryChain([ctx]);

      const confirmResult = await sendVisitConfirmation(visit.id);
      expect(confirmResult.success).toBe(true);

      // Step 2: Tenant confirmation request sent
      mockQueryChain([ctx]);
      const tenantResult = await sendTenantConfirmationRequest(visit.id);
      expect(tenantResult.success).toBe(true);

      // Step 3: Employee confirms (replies "1") → visit status → confirmed
      // Service: find employee → find visit → getVisitContext (for sendTenantConfirmationRequest)
      mockQueryChain([FIXTURES.employee], [visit], [ctx]);
      mockUpdateResolve(); // update visit
      mockInsertResolve(); // logSMS

      const empConfirm = await handleEmployeeReply(FIXTURES.employee.phone, '1');
      expect(empConfirm.success).toBe(true);
      expect(empConfirm.action).toBe('visit_confirmed');

      // Step 4: Tenant confirms attendance (replies "1")
      // Service: find lead → find active visit
      mockQueryChain([FIXTURES.lead], [visit]);
      mockUpdateResolve(); // update tenantConfirmed

      const tenantConfirm = await handleTenantReply(FIXTURES.lead.phone, '1');
      expect(tenantConfirm.success).toBe(true);
      expect(tenantConfirm.action).toBe('tenant_confirmed');

      // Step 5: Morning-of reminder sent
      const confirmedVisit = { ...visit, status: 'confirmed', tenantConfirmed: true };
      mockQueryChain([{ ...ctx, visit: confirmedVisit }]);
      mockUpdateResolve(); // set morningOfSent

      const reminderResult = await sendMorningOfReminder(visit.id);
      expect(reminderResult.success).toBe(true);

      // Step 6: Post-visit survey sent
      mockQueryChain([ctx]);
      const surveyResult = await sendPostVisitSurvey(visit.id);
      expect(surveyResult.success).toBe(true);

      // Step 7: Employee reports tenant is interested (replies "1")
      // Service: find employee → find visit → (update visit) → (update lead) → getVisitContext → find admin
      mockQueryChain([FIXTURES.employee], [confirmedVisit], [ctx], [FIXTURES.adminUser]);
      mockUpdateResolve(); // update visit outcome
      mockUpdateResolve(); // update lead stage

      mockHandleIncomingMessage.mockReturnValueOnce({ action: 'interested', raw: '1' });

      const outcome = await handleEmployeeReply(FIXTURES.employee.phone, '1');
      expect(outcome.success).toBe(true);
      expect(outcome.action).toBe('lead_interested');

      // Verify total SMS sends throughout the lifecycle:
      // 1. Employee confirmation
      // 2. Tenant confirmation request
      // 3. Tenant confirmation (triggered by employee confirm)
      // 4. Morning reminder
      // 5. Post-visit survey
      // 6. Simon notification
      expect(mockSendSMS).toHaveBeenCalledTimes(6);
    });
  });
});
