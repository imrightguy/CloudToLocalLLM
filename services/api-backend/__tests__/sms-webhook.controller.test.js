const {
  handleIncoming,
  handleStatus,
  handleSchedule,
} = require('../src/controllers/sms-webhook.controller');

// ─── Mocks ────────────────────────────────────────────────────────────────────
jest.mock('../src/services/sms.service', () => ({
  handleEmployeeReply: jest.fn(),
  handleTenantReply: jest.fn(),
  handleOccupantReply: jest.fn(),
  sendMorningOfReminder: jest.fn(),
  sendPostVisitSurvey: jest.fn(),
  getVisitsNeedingMorningReminder: jest.fn(),
  getVisitsNeedingPostSurvey: jest.fn(),
  getVisitsNeeding24hReminder: jest.fn(),
  getVisitsNeeding2hReminder: jest.fn(),
  queueVisit24hReminder: jest.fn(),
  queueVisit2hReminder: jest.fn(),
  getVisitsNeedingExpiry: jest.fn(),
  expireVisits: jest.fn(),
}));

jest.mock('../src/database/connection', () => ({
  db: {
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockResolvedValue(undefined),
  },
}));

jest.mock('../src/database/schema', () => ({
  smsLogsTable: {
    twilioSid: 'twilioSid', twilioStatus: 'twilioStatus', status: 'status', errorMessage: 'errorMessage', updatedAt: 'updatedAt',
  },
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
}));

// ─── Helpers ──────────────────────────────────────────────────────────────────
const smsService = require('../src/services/sms.service');
const { db } = require('../src/database/connection');
// must come after jest.mock('drizzle-orm') above
const { eq } = require('drizzle-orm');

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.type = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

const XML_RESPONSE = '<Response></Response>';

beforeEach(() => {
  jest.clearAllMocks();
});

// ═══════════════════════════════════════════════════════════════════════════════
// handleIncoming
// ═══════════════════════════════════════════════════════════════════════════════
describe('handleIncoming', () => {
  const from = '+33612345678';
  const body = 'Oui, je confirme';
  const sid = 'SM123456789';

  // ── Validation ─────────────────────────────────────────────────────────────
  it('returns 400 if From is missing', async () => {
    const req = { body: { Body: body, MessageSid: sid } };
    const res = mockRes();
    await handleIncoming(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.send).toHaveBeenCalledWith('Missing required fields');
  });

  it('returns 200 XML if Body is missing but media is present', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockResolvedValue({ success: false, error: 'Lead not found' });
    smsService.handleOccupantReply.mockResolvedValue({ success: false, error: 'Occupant not found' });

    const req = { body: { From: from, MessageSid: sid, NumMedia: '1', MediaUrl0: 'https://example.com/photo.jpg', MediaContentType0: 'image/jpeg' } };
    const res = mockRes();
    await handleIncoming(req, res);

    expect(smsService.handleEmployeeReply).toHaveBeenCalledWith(from, '');
    expect(smsService.handleTenantReply).toHaveBeenCalledWith(from, '');
    expect(smsService.handleOccupantReply).toHaveBeenCalledWith(from, '');
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 400 if both From and Body are missing', async () => {
    const req = { body: { MessageSid: sid } };
    const res = mockRes();
    await handleIncoming(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.send).toHaveBeenCalledWith('Missing required fields');
  });

  // ── Employee path ──────────────────────────────────────────────────────────
  it('returns 200 XML when employee reply is processed successfully', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: true, action: 'confirmed', visitId: 'v1' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(smsService.handleEmployeeReply).toHaveBeenCalledWith(from, body);
    expect(smsService.handleTenantReply).not.toHaveBeenCalled();
    expect(smsService.handleOccupantReply).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  // ── Tenant path ────────────────────────────────────────────────────────────
  it('returns 200 XML when employee not found but tenant reply succeeds', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockResolvedValue({ success: true, action: 'declined', visitId: 'v2' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(smsService.handleEmployeeReply).toHaveBeenCalledWith(from, body);
    expect(smsService.handleTenantReply).toHaveBeenCalledWith(from, body);
    expect(smsService.handleOccupantReply).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 200 XML when employee has no active visit but tenant reply succeeds', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'No active visit found' });
    smsService.handleTenantReply.mockResolvedValue({ success: true, action: 'rescheduled', visitId: 'v3' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(smsService.handleTenantReply).toHaveBeenCalledWith(from, body);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  // ── Occupant path ──────────────────────────────────────────────────────────
  it('returns 200 XML when employee and tenant not found but occupant succeeds', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockResolvedValue({ success: false, error: 'Lead not found' });
    smsService.handleOccupantReply.mockResolvedValue({ success: true, action: 'granted', visitId: 'v4' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(smsService.handleEmployeeReply).toHaveBeenCalledWith(from, body);
    expect(smsService.handleTenantReply).toHaveBeenCalledWith(from, body);
    expect(smsService.handleOccupantReply).toHaveBeenCalledWith(from, body);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 200 XML when tenant has no active visit but occupant succeeds', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'No active visit found' });
    smsService.handleTenantReply.mockResolvedValue({ success: false, error: 'No active visit found' });
    smsService.handleOccupantReply.mockResolvedValue({ success: true, action: 'granted', visitId: 'v5' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(smsService.handleOccupantReply).toHaveBeenCalledWith(from, body);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  // ── Unrecognised sender ────────────────────────────────────────────────────
  it('returns 200 XML when all handlers fail (unrecognised sender)', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockResolvedValue({ success: false, error: 'Lead not found' });
    smsService.handleOccupantReply.mockResolvedValue({ success: false, error: 'Occupant not found' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 200 XML when employee fails with unexpected error (no matching error string)', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Something unexpected' });
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    // Should not proceed to tenant since error string doesn't match routing conditions
    expect(smsService.handleTenantReply).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  // ── Catch block (unexpected exception) ─────────────────────────────────────
  it('returns 200 XML when handleEmployeeReply throws', async () => {
    smsService.handleEmployeeReply.mockRejectedValue(new Error('DB connection lost'));
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 200 XML when handleTenantReply throws', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockRejectedValue(new Error('Timeout'));
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });

  it('returns 200 XML when handleOccupantReply throws', async () => {
    smsService.handleEmployeeReply.mockResolvedValue({ success: false, error: 'Employee not found' });
    smsService.handleTenantReply.mockResolvedValue({ success: false, error: 'Lead not found' });
    smsService.handleOccupantReply.mockRejectedValue(new Error('Crash'));
    const req = { body: { From: from, Body: body, MessageSid: sid } };
    const res = mockRes();

    await handleIncoming(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
    expect(res.send).toHaveBeenCalledWith(XML_RESPONSE);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// handleStatus
// ═══════════════════════════════════════════════════════════════════════════════
describe('handleStatus', () => {
  const sid = 'SM987654321';

  // ── Validation ─────────────────────────────────────────────────────────────
  it('returns 400 if MessageSid is missing', async () => {
    const req = { body: { SmsStatus: 'delivered' } };
    const res = mockRes();

    await handleStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.send).toHaveBeenCalledWith('Missing MessageSid');
    expect(db.update).not.toHaveBeenCalled();
  });

  // ── Status mapping ─────────────────────────────────────────────────────────
  const statusCases = [
    { twilioStatus: 'queued', expectedMapped: 'queued' },
    { twilioStatus: 'sent', expectedMapped: 'sent' },
    { twilioStatus: 'delivered', expectedMapped: 'delivered' },
    { twilioStatus: 'undelivered', expectedMapped: 'failed' },
    { twilioStatus: 'failed', expectedMapped: 'failed' },
    { twilioStatus: 'read', expectedMapped: 'read' },
    { twilioStatus: 'some_unknown_status', expectedMapped: 'some_unknown_status' },
    { twilioStatus: undefined, expectedMapped: 'unknown' },
  ];

  it.each(statusCases)(
    'maps Twilio status "$twilioStatus" → "$expectedMapped"',
    async ({ twilioStatus, expectedMapped }) => {
      const req = { body: { MessageSid: sid, SmsStatus: twilioStatus } };
      const res = mockRes();

      await handleStatus(req, res);

      expect(db.update).toHaveBeenCalledWith(expect.any(Object));
      expect(db.set).toHaveBeenCalledWith(
        expect.objectContaining({
          twilioStatus: twilioStatus || null,
          status: expectedMapped,
          errorMessage: null,
          updatedAt: expect.any(Date),
        }),
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.send).toHaveBeenCalledWith('OK');
    },
  );

  it('accepts MessageStatus as a fallback field', async () => {
    const req = { body: { MessageSid: sid, MessageStatus: 'delivered' } };
    const res = mockRes();

    await handleStatus(req, res);

    expect(db.set).toHaveBeenCalledWith(
      expect.objectContaining({
        twilioStatus: 'delivered',
        status: 'delivered',
        errorMessage: null,
        updatedAt: expect.any(Date),
      }),
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('OK');
  });

  it('includes ErrorMessage when provided', async () => {
    const errMsg = 'Carrier rejected';
    const req = { body: { MessageSid: sid, SmsStatus: 'failed', ErrorMessage: errMsg } };
    const res = mockRes();

    await handleStatus(req, res);

    expect(db.set).toHaveBeenCalledWith(
      expect.objectContaining({
        errorMessage: errMsg,
      }),
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('passes MessageSid to the where clause via eq', async () => {
    const req = { body: { MessageSid: sid, SmsStatus: 'delivered' } };
    const res = mockRes();

    await handleStatus(req, res);

    expect(eq).toHaveBeenCalledWith('twilioSid', sid);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('OK');
  });

  // ── Error handling ─────────────────────────────────────────────────────────
  it('returns 200 "OK" when DB update throws', async () => {
    db.where.mockRejectedValueOnce(new Error('Connection refused'));
    const req = { body: { MessageSid: sid, SmsStatus: 'delivered' } };
    const res = mockRes();

    await handleStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('OK');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// handleSchedule
// ═══════════════════════════════════════════════════════════════════════════════
describe('handleSchedule', () => {
  // ── Validation ─────────────────────────────────────────────────────────────
  it('returns 400 if action is missing', async () => {
    const req = { body: {} };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'INVALID_ACTION' }),
      }),
    );
    expect(smsService.sendMorningOfReminder).not.toHaveBeenCalled();
    expect(smsService.sendPostVisitSurvey).not.toHaveBeenCalled();
    expect(smsService.queueVisit24hReminder).not.toHaveBeenCalled();
    expect(smsService.queueVisit2hReminder).not.toHaveBeenCalled();
    expect(smsService.expireVisits).not.toHaveBeenCalled();
  });

  it('returns 400 for invalid action', async () => {
    const req = { body: { action: 'delete_everything' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'INVALID_ACTION' }),
      }),
    );
  });

  it('returns 400 for reminder_24h, reminder_2h, expire_confirmations when action is invalid', async () => {
    const req = { body: { action: 'bad_action' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(smsService.queueVisit24hReminder).not.toHaveBeenCalled();
    expect(smsService.queueVisit2hReminder).not.toHaveBeenCalled();
    expect(smsService.expireVisits).not.toHaveBeenCalled();
  });

  // ── morning_reminder with visitId ──────────────────────────────────────────
  it('calls sendMorningOfReminder with visitId and returns result', async () => {
    smsService.sendMorningOfReminder.mockResolvedValue({ success: true, messageId: 'msg1' });
    const req = { body: { action: 'morning_reminder', visitId: 'v1' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.sendMorningOfReminder).toHaveBeenCalledWith('v1');
    expect(smsService.sendMorningOfReminder).toHaveBeenCalledTimes(1);
    expect(smsService.getVisitsNeedingMorningReminder).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'morning_reminder',
        processed: 1,
        results: [{ visitId: 'v1', success: true, messageId: 'msg1' }],
      },
    });
  });

  // ── post_survey with visitId ───────────────────────────────────────────────
  it('calls sendPostVisitSurvey with visitId and returns result', async () => {
    smsService.sendPostVisitSurvey.mockResolvedValue({ success: true, messageId: 'msg2' });
    const req = { body: { action: 'post_survey', visitId: 'v2' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.sendPostVisitSurvey).toHaveBeenCalledWith('v2');
    expect(smsService.sendPostVisitSurvey).toHaveBeenCalledTimes(1);
    expect(smsService.getVisitsNeedingPostSurvey).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'post_survey',
        processed: 1,
        results: [{ visitId: 'v2', success: true, messageId: 'msg2' }],
      },
    });
  });

  // ── morning_reminder full sweep (no visitId) ───────────────────────────────
  it('runs full morning reminder sweep when no visitId', async () => {
    smsService.getVisitsNeedingMorningReminder.mockResolvedValue([
      { id: 'v1' },
      { id: 'v2' },
    ]);
    smsService.sendMorningOfReminder
      .mockResolvedValueOnce({ success: true, messageId: 'm1' })
      .mockResolvedValueOnce({ success: false, error: 'No phone number' });
    const req = { body: { action: 'morning_reminder' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.getVisitsNeedingMorningReminder).toHaveBeenCalledTimes(1);
    expect(smsService.sendMorningOfReminder).toHaveBeenCalledTimes(2);
    expect(smsService.sendMorningOfReminder).toHaveBeenCalledWith('v1');
    expect(smsService.sendMorningOfReminder).toHaveBeenCalledWith('v2');
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'morning_reminder',
        processed: 2,
        results: [
          { visitId: 'v1', success: true, messageId: 'm1' },
          { visitId: 'v2', success: false, error: 'No phone number' },
        ],
      },
    });
  });

  // ── post_survey full sweep (no visitId) ───────────────────────────────────
  it('runs full post survey sweep when no visitId', async () => {
    smsService.getVisitsNeedingPostSurvey.mockResolvedValue([
      { id: 'v3' },
    ]);
    smsService.sendPostVisitSurvey.mockResolvedValue({ success: true, messageId: 'm3' });
    const req = { body: { action: 'post_survey' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.getVisitsNeedingPostSurvey).toHaveBeenCalledTimes(1);
    expect(smsService.sendPostVisitSurvey).toHaveBeenCalledWith('v3');
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'post_survey',
        processed: 1,
        results: [{ visitId: 'v3', success: true, messageId: 'm3' }],
      },
    });
  });

  // ── Full sweep with empty visit list ───────────────────────────────────────
  it('returns 0 processed when sweep finds no visits', async () => {
    smsService.getVisitsNeedingMorningReminder.mockResolvedValue([]);
    const req = { body: { action: 'morning_reminder' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.sendMorningOfReminder).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: expect.objectContaining({
        action: 'morning_reminder',
        processed: 0,
        results: [],
      }),
    });
  });

  // ── Error handling ─────────────────────────────────────────────────────────
  it('returns 500 when sendMorningOfReminder throws', async () => {
    smsService.sendMorningOfReminder.mockRejectedValue(new Error('Twilio API down'));
    const req = { body: { action: 'morning_reminder', visitId: 'v1' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
    });
  });

  it('returns 500 when getVisitsNeedingMorningReminder throws', async () => {
    smsService.getVisitsNeedingMorningReminder.mockRejectedValue(new Error('DB timeout'));
    const req = { body: { action: 'morning_reminder' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
      }),
    );
  });

  it('returns 500 when sendPostVisitSurvey throws in sweep', async () => {
    smsService.getVisitsNeedingPostSurvey.mockResolvedValue([{ id: 'v1' }]);
    smsService.sendPostVisitSurvey.mockRejectedValue(new Error('Provider error'));
    const req = { body: { action: 'post_survey' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
      }),
    );
  });

  // ── reminder_24h with visitId ────────────────────────────────────────────────
  it('calls queueVisit24hReminder with visitId and returns result', async () => {
    smsService.queueVisit24hReminder.mockResolvedValue({ success: true });
    const req = { body: { action: 'reminder_24h', visitId: 'v1' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.queueVisit24hReminder).toHaveBeenCalledWith('v1');
    expect(smsService.queueVisit24hReminder).toHaveBeenCalledTimes(1);
    expect(smsService.getVisitsNeeding24hReminder).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'reminder_24h',
        processed: 1,
        results: [{ visitId: 'v1', success: true }],
      },
    });
  });

  // ── reminder_24h full sweep ─────────────────────────────────────────────────
  it('runs full 24h reminder sweep when no visitId', async () => {
    smsService.getVisitsNeeding24hReminder.mockResolvedValue([
      { id: 'v1' },
      { id: 'v2' },
    ]);
    smsService.queueVisit24hReminder
      .mockResolvedValueOnce({ success: true })
      .mockResolvedValueOnce({ success: false, error: 'Missing context' });
    const req = { body: { action: 'reminder_24h' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.getVisitsNeeding24hReminder).toHaveBeenCalledTimes(1);
    expect(smsService.queueVisit24hReminder).toHaveBeenCalledTimes(2);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'reminder_24h',
        processed: 2,
        results: [
          { visitId: 'v1', success: true },
          { visitId: 'v2', success: false, error: 'Missing context' },
        ],
      },
    });
  });

  // ── reminder_2h with visitId ─────────────────────────────────────────────────
  it('calls queueVisit2hReminder with visitId and returns result', async () => {
    smsService.queueVisit2hReminder.mockResolvedValue({ success: true });
    const req = { body: { action: 'reminder_2h', visitId: 'v3' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.queueVisit2hReminder).toHaveBeenCalledWith('v3');
    expect(smsService.queueVisit2hReminder).toHaveBeenCalledTimes(1);
    expect(smsService.getVisitsNeeding2hReminder).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'reminder_2h',
        processed: 1,
        results: [{ visitId: 'v3', success: true }],
      },
    });
  });

  // ── reminder_2h full sweep ──────────────────────────────────────────────────
  it('runs full 2h reminder sweep when no visitId', async () => {
    smsService.getVisitsNeeding2hReminder.mockResolvedValue([{ id: 'v4' }]);
    smsService.queueVisit2hReminder.mockResolvedValue({ success: true });
    const req = { body: { action: 'reminder_2h' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.getVisitsNeeding2hReminder).toHaveBeenCalledTimes(1);
    expect(smsService.queueVisit2hReminder).toHaveBeenCalledWith('v4');
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'reminder_2h',
        processed: 1,
        results: [{ visitId: 'v4', success: true }],
      },
    });
  });

  // ── expire_confirmations ─────────────────────────────────────────────────────
  it('calls expireVisits and returns result', async () => {
    smsService.expireVisits.mockResolvedValue({ expired: 3 });
    const req = { body: { action: 'expire_confirmations' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.expireVisits).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'expire_confirmations',
        expired: 3,
      },
    });
  });

  it('returns 0 expired when no visits need expiry', async () => {
    smsService.expireVisits.mockResolvedValue({ expired: 0 });
    const req = { body: { action: 'expire_confirmations' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(smsService.expireVisits).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        action: 'expire_confirmations',
        expired: 0,
      },
    });
  });

  it('returns 500 when expireVisits throws', async () => {
    smsService.expireVisits.mockRejectedValue(new Error('DB connection lost'));
    const req = { body: { action: 'expire_confirmations' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
      }),
    );
  });

  it('returns 500 when queueVisit24hReminder throws', async () => {
    smsService.queueVisit24hReminder.mockRejectedValue(new Error('Twilio error'));
    const req = { body: { action: 'reminder_24h', visitId: 'v1' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
      }),
    );
  });

  it('returns 500 when queueVisit2hReminder throws', async () => {
    smsService.queueVisit2hReminder.mockRejectedValue(new Error('Twilio error'));
    const req = { body: { action: 'reminder_2h', visitId: 'v1' } };
    const res = mockRes();

    await handleSchedule(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'SCHEDULE_FAILED' }),
      }),
    );
  });
});
