jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../src/database/connection', () => ({
  db: {
    insert: jest.fn(),
    select: jest.fn(),
    update: jest.fn(),
  },
}));

jest.mock('../src/database/schema', () => {
  return {
    communicationLogsTable: {
      leadId: 'leadId',
      employeeId: 'employeeId',
      type: 'type',
      direction: 'direction',
      content: 'content',
      attachments: 'attachments',
      status: 'status',
      metadata: 'metadata',
      createdAt: 'createdAt',
    },
    communicationThreadsTable: {
      id: 'id',
      leadId: 'leadId',
      messageCount: 'messageCount',
      lastMessageAt: 'lastMessageAt',
      lastMessageType: 'lastMessageType',
      lastMessageDirection: 'lastMessageDirection',
      updatedAt: 'updatedAt',
    },
    leadsTable: {
      id: 'id',
      fullName: 'fullName',
      phone: 'phone',
      email: 'email',
      source: 'source',
      stage: 'stage',
    },
  };
});

const {
  CHANNEL_TYPES,
  DIRECTIONS,
  logCrossChannelMessage,
  findLeadByPhone,
  getPreferredChannel,
  getLeadConversationTimeline,
  getMessagesByChannel,
} = require('../src/services/conversation-router.service');

const { db } = require('../src/database/connection');

describe('CHANNEL_TYPES', () => {
  it('has SMS, WHATSAPP, FB_MESSENGER, EMAIL, PHONE', () => {
    expect(CHANNEL_TYPES.SMS).toBe('sms');
    expect(CHANNEL_TYPES.WHATSAPP).toBe('whatsapp');
    expect(CHANNEL_TYPES.FB_MESSENGER).toBe('fb_messenger');
    expect(CHANNEL_TYPES.EMAIL).toBe('email');
    expect(CHANNEL_TYPES.PHONE).toBe('phone');
  });
});

describe('DIRECTIONS', () => {
  it('has INBOUND and OUTBOUND', () => {
    expect(DIRECTIONS.INBOUND).toBe('inbound');
    expect(DIRECTIONS.OUTBOUND).toBe('outbound');
  });
});

describe('logCrossChannelMessage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns null when leadId is missing', async () => {
    const result = await logCrossChannelMessage({
      channel: CHANNEL_TYPES.WHATSAPP,
      direction: DIRECTIONS.INBOUND,
      content: 'hello',
    });
    expect(result).toBeNull();
  });

  it('returns null for unknown channel type', async () => {
    const result = await logCrossChannelMessage({
      leadId: 'lead-1',
      channel: 'telegram',
      direction: DIRECTIONS.INBOUND,
      content: 'hello',
    });
    expect(result).toBeNull();
  });

  it('inserts a communication log and updates thread', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 42 }]);
    const mockValues = jest.fn().mockReturnValue({ returning: mockReturning });
    db.insert.mockReturnValue({ values: mockValues });

    const mockUpdateSet = jest.fn().mockResolvedValue(undefined);
    const mockUpdateWhere = jest.fn().mockReturnValue({ set: mockUpdateSet });
    const mockSelectLimit = jest.fn().mockResolvedValue([{ id: 'thread-1', messageCount: 5 }]);
    const mockSelectOrderBy = jest.fn().mockReturnValue({ limit: mockSelectLimit });
    const mockSelectWhere = jest.fn().mockReturnValue({ orderBy: mockSelectOrderBy });
    const mockSelectFrom = jest.fn().mockReturnValue({ where: mockSelectWhere });
    db.select.mockReturnValue({ from: mockSelectFrom });

    const result = await logCrossChannelMessage({
      leadId: 'lead-1',
      channel: CHANNEL_TYPES.WHATSAPP,
      direction: DIRECTIONS.INBOUND,
      content: 'Hello from WhatsApp',
      status: 'received',
    });

    expect(db.insert).toHaveBeenCalled();
    expect(result).toBe(42);
  });

  it('handles insert errors gracefully', async () => {
    db.insert.mockImplementation(() => { throw new Error('DB error'); });
    const result = await logCrossChannelMessage({
      leadId: 'lead-1',
      channel: CHANNEL_TYPES.SMS,
      direction: DIRECTIONS.OUTBOUND,
      content: 'test',
    });
    expect(result).toBeNull();
  });
});

describe('findLeadByPhone', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns null for empty phone number', async () => {
    const result = await findLeadByPhone('');
    expect(result).toBeNull();
  });

  it('returns null for null input', async () => {
    const result = await findLeadByPhone(null);
    expect(result).toBeNull();
  });

  it('queries leads by cleaned phone number', async () => {
    const mockLimit = jest.fn().mockResolvedValue([{ id: 'lead-1', fullName: 'Test User' }]);
    const mockWhere = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await findLeadByPhone('+1 (514) 555-1234');
    expect(result).toEqual({ id: 'lead-1', fullName: 'Test User' });
  });

  it('returns null when no lead found', async () => {
    const mockLimit = jest.fn().mockResolvedValue([]);
    const mockWhere = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await findLeadByPhone('+15145559999');
    expect(result).toBeNull();
  });

  it('handles DB errors gracefully', async () => {
    db.select.mockImplementation(() => { throw new Error('DB down'); });
    const result = await findLeadByPhone('+15145551234');
    expect(result).toBeNull();
  });
});

describe('getLeadConversationTimeline', () => {
  it('returns empty array for null leadId', async () => {
    const result = await getLeadConversationTimeline(null);
    expect(result).toEqual([]);
  });

  it('queries communication logs ordered by date', async () => {
    const mockOffset = jest.fn().mockResolvedValue([{ id: 'log-1' }]);
    const mockLimit = jest.fn().mockReturnValue({ offset: mockOffset });
    const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockWhere = jest.fn().mockReturnValue({ orderBy: mockOrderBy });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await getLeadConversationTimeline('lead-1', { limit: 10, offset: 0 });
    expect(result).toEqual([{ id: 'log-1' }]);
  });
});

describe('getMessagesByChannel', () => {
  it('returns empty array for null leadId', async () => {
    const result = await getMessagesByChannel(null, 'sms');
    expect(result).toEqual([]);
  });

  it('returns empty array for null channel', async () => {
    const result = await getMessagesByChannel('lead-1', null);
    expect(result).toEqual([]);
  });

  it('queries by leadId and channel type', async () => {
    const mockLimit = jest.fn().mockResolvedValue([{ id: 'log-1', type: 'whatsapp' }]);
    const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockWhere = jest.fn().mockReturnValue({ orderBy: mockOrderBy });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await getMessagesByChannel('lead-1', 'whatsapp');
    expect(result).toEqual([{ id: 'log-1', type: 'whatsapp' }]);
  });
});

describe('getPreferredChannel', () => {
  it('returns null for null leadId', async () => {
    const result = await getPreferredChannel(null);
    expect(result).toBeNull();
  });

  it('returns the most used channel', async () => {
    const mockLimit = jest.fn().mockResolvedValue([{ type: 'whatsapp', count: '10' }]);
    const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockGroupBy = jest.fn().mockReturnValue({ orderBy: mockOrderBy });
    const mockWhere = jest.fn().mockReturnValue({ groupBy: mockGroupBy });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await getPreferredChannel('lead-1');
    expect(result).toBe('whatsapp');
  });

  it('returns null when no messages exist', async () => {
    const mockLimit = jest.fn().mockResolvedValue([]);
    const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockGroupBy = jest.fn().mockReturnValue({ orderBy: mockOrderBy });
    const mockWhere = jest.fn().mockReturnValue({ groupBy: mockGroupBy });
    const mockFrom = jest.fn().mockReturnValue({ where: mockWhere });
    db.select.mockReturnValue({ from: mockFrom });

    const result = await getPreferredChannel('lead-1');
    expect(result).toBeNull();
  });
});
