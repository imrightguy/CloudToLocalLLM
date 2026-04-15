const {
  handleEmployeeReply,
  sendLeadArrivalNotification,
  sendLeadFeedbackRequest,
} = require('../src/services/sms.service');

const mockState = {
  limitResults: [],
  limitIndex: 0,
};

const chain = {};

const resetChain = () => {
  chain.select = jest.fn(() => chain);
  chain.from = jest.fn(() => chain);
  chain.leftJoin = jest.fn(() => chain);
  chain.where = jest.fn(() => chain);
  chain.orderBy = jest.fn(() => chain);
  chain.limit = jest.fn(() => {
    const idx = mockState.limitIndex;
    mockState.limitIndex++;
    const result = idx < mockState.limitResults.length
      ? mockState.limitResults[idx]
      : [];
    return Promise.resolve(result);
  });
  chain.insert = jest.fn(() => chain);
  chain.values = jest.fn(() => Promise.resolve(undefined));
  chain.update = jest.fn(() => chain);
  chain.set = jest.fn(() => chain);
};

resetChain();

jest.mock('../src/database/connection', () => ({
  db: chain,
}));

jest.mock('../src/services/twilio.service', () => ({
  sendSMS: jest.fn().mockResolvedValue({ success: true, sid: 'SM123', status: 'sent' }),
  handleIncomingMessage: jest.fn(),
  initTwilio: jest.fn(),
}));

jest.mock('../src/database/schema', () => ({
  visitsTable: { id: 'id', employeeId: 'employeeId', leadId: 'leadId', status: 'status', isActive: 'isActive', dateTime: 'dateTime', tenantConfirmed: 'tenantConfirmed', employeeConfirmed: 'employeeConfirmed', morningOfSent: 'morningOfSent', outcome: 'outcome', updatedAt: 'updatedAt', unitId: 'unitId' },
  smsLogsTable: {},
  employeesTable: { id: 'id', phone: 'phone', firstName: 'firstName', lastName: 'lastName' },
  leadsTable: { id: 'id', phone: 'phone', fullName: 'fullName', stage: 'stage', language: 'language' },
  unitsTable: { id: 'id', tenantPhone: 'tenantPhone', tenantLeaseEnd: 'tenantLeaseEnd', label: 'label', buildingId: 'buildingId', status: 'status' },
  buildingsTable: { id: 'id', name: 'name', address: 'address', city: 'city' },
  usersTable: {},
  smsTemplatesTable: {},
  smsCampaignsTable: {},
  smsQueueTable: {},
  leasesTable: {},
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { db } = require('../src/database/connection');
const { sendSMS, handleIncomingMessage } = require('../src/services/twilio.service');

const mockVisit = (overrides = {}) => ({
  id: 'visit-1',
  employeeId: 'emp-1',
  leadId: 'lead-1',
  unitId: 'unit-1',
  status: 'confirmed',
  isActive: true,
  tenantConfirmed: false,
  employeeConfirmed: false,
  morningOfSent: false,
  outcome: null,
  dateTime: new Date(Date.now() + 3600000),
  ...overrides,
});

const mockEmployee = { id: 'emp-1', phone: '+15145550001', firstName: 'Marc', lastName: 'Dupont' };
const mockLead = { id: 'lead-1', phone: '+15145559876', fullName: 'Jean Tremblay', language: 'fr' };
const mockUnit = { id: 'unit-1', label: '4A', buildingId: 'bld-1', tenantPhone: null, tenantLeaseEnd: null, status: 'vacant' };
const mockBuilding = { id: 'bld-1', name: '123 rue Sherbrooke', address: '123 rue Sherbrooke', city: 'Montreal' };

beforeEach(() => {
  jest.clearAllMocks();
  mockState.limitResults = [];
  mockState.limitIndex = 0;
  resetChain();
});

describe('handleEmployeeReply - ACCEPT', () => {
  it('accept confirms a scheduled visit and sends tenant confirmation', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'yes', raw: 'accept' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'scheduled' })],
    ];

    const result = await handleEmployeeReply('+15145550001', 'accept');
    expect(result.success).toBe(true);
    expect(result.action).toBe('visit_confirmed');
    expect(result.visitId).toBe('visit-1');
    expect(db.update).toHaveBeenCalled();
  });
});

describe('handleEmployeeReply - DECLINE', () => {
  it('decline cancels a scheduled visit', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'no', raw: 'decline' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'scheduled' })],
    ];

    const result = await handleEmployeeReply('+15145550001', 'decline');
    expect(result.success).toBe(true);
    expect(result.action).toBe('visit_cancelled');
    expect(db.update).toHaveBeenCalled();
  });
});

describe('handleEmployeeReply - ARRIVE', () => {
  it('arrive on confirmed visit sets in_progress and notifies lead', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'arrive', raw: 'arrive' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'confirmed' })],
      [{ visit: mockVisit({ status: 'confirmed' }), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
    ];

    const result = await handleEmployeeReply('+15145550001', 'arrive');
    expect(result.success).toBe(true);
    expect(result.action).toBe('employee_arrived');
    expect(result.visitId).toBe('visit-1');
    expect(db.update).toHaveBeenCalled();
    expect(sendSMS).toHaveBeenCalled();
  });

  it('arrive on scheduled visit returns invalid state', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'arrive', raw: 'arrive' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'scheduled' })],
    ];

    const result = await handleEmployeeReply('+15145550001', 'arrive');
    expect(result.success).toBe(false);
    expect(result.action).toBe('arrive_invalid_state');
  });
});

describe('handleEmployeeReply - TERMINE', () => {
  it('termine on in_progress visit sets completed and sends feedback + survey', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'termine', raw: 'termine' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'in_progress' })],
      [{ visit: mockVisit({ status: 'in_progress' }), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
      [{ visit: mockVisit({ status: 'in_progress' }), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
    ];

    const result = await handleEmployeeReply('+15145550001', 'termine');
    expect(result.success).toBe(true);
    expect(result.action).toBe('visit_completed');
    expect(result.visitId).toBe('visit-1');
  });

  it('termine on confirmed visit also completes', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'termine', raw: 'termine' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'confirmed' })],
      [{ visit: mockVisit({ status: 'confirmed' }), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
      [{ visit: mockVisit({ status: 'confirmed' }), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
    ];

    const result = await handleEmployeeReply('+15145550001', 'termine');
    expect(result.success).toBe(true);
    expect(result.action).toBe('visit_completed');
  });

  it('termine on scheduled visit returns invalid state', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'termine', raw: 'termine' });

    mockState.limitResults = [
      [mockEmployee],
      [mockVisit({ status: 'scheduled' })],
    ];

    const result = await handleEmployeeReply('+15145550001', 'termine');
    expect(result.success).toBe(false);
    expect(result.action).toBe('termine_invalid_state');
  });
});

describe('sendLeadArrivalNotification', () => {
  it('sends arrival SMS to lead with building name', async () => {
    mockState.limitResults = [
      [{ visit: mockVisit(), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
    ];

    const result = await sendLeadArrivalNotification('visit-1');
    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145559876',
      expect.stringContaining('arrivé'),
    );
  });

  it('returns error when visit not found', async () => {
    mockState.limitResults = [[]];

    const result = await sendLeadArrivalNotification('nonexistent');
    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });
});

describe('sendLeadFeedbackRequest', () => {
  it('sends feedback SMS to lead', async () => {
    mockState.limitResults = [
      [{ visit: mockVisit(), employee: mockEmployee, lead: mockLead, unit: mockUnit, building: mockBuilding }],
    ];

    const result = await sendLeadFeedbackRequest('visit-1');
    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145559876',
      expect.stringContaining('Satisfait'),
    );
  });

  it('returns error when visit not found', async () => {
    mockState.limitResults = [[]];

    const result = await sendLeadFeedbackRequest('nonexistent');
    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });
});
