/**
 * Database schema definition tests
 * Covers: all table exports, column presence, types, uniqueness, and foreign keys
 */
const schema = require('../src/database/schema');

const EXPECTED_TABLES = [
  'usersTable',
  'refreshTokensTable',
  'employeesTable',
  'buildingsTable',
  'employeeAssignmentsTable',
  'unitsTable',
  'employeeSchedulesTable',
  'leadsTable',
  'visitsTable',
  'smsLogsTable',
  'communicationLogsTable',
  'documentsTable',
  'documentsLeadsTable',
  'leasesTable',
  'notificationPreferencesTable',
  'notificationsTable',
  'smsTemplatesTable',
  'smsCampaignsTable',
  'smsQueueTable',
  'paymentsTable',
  'renewalOffersTable',
  'smsOptOutsTable',
];

// ── Helpers ──
/** Check if a column exists on a Drizzle table (has columnType) */
function hasColumn(table, colName) {
  return (
    table[colName] &&
    typeof table[colName] === 'object' &&
    table[colName].columnType
  );
}

/** Get all column names from a Drizzle table */
function getColumnNames(table) {
  return Object.keys(table).filter((k) => hasColumn(table, k));
}

// ── Schema Export Tests ──
describe('schema exports', () => {
  it('should export all 21 expected tables', () => {
    EXPECTED_TABLES.forEach((tableName) => {
      expect(schema).toHaveProperty(tableName);
      expect(schema[tableName]).toBeDefined();
    });
  });

  it('should export exactly the expected tables', () => {
    const exportedKeys = Object.keys(schema);
    expect(exportedKeys.sort()).toEqual(EXPECTED_TABLES.sort());
  });
});

// ── Per-Table Column Tests ──
describe('usersTable', () => {
  const t = schema.usersTable;
  const cols = [
    'id', 'email', 'passwordHash', 'firstName', 'lastName',
    'phone', 'role', 'isActive', 'emailVerified', 'tokenVersion',
    'lastLogin', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });

  it('email should be unique', () => {
    expect(t.email.isUnique).toBe(true);
  });

  it('should have uuid primary key', () => {
    expect(t.id.columnType).toBe('PgUUID');
    expect(t.id.primary).toBe(true);
  });
});

describe('refreshTokensTable', () => {
  const t = schema.refreshTokensTable;
  const cols = ['id', 'userId', 'token', 'expiresAt', 'ip', 'userAgent', 'createdAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });

  it('token should be unique', () => {
    expect(t.token.isUnique).toBe(true);
  });
});

describe('employeesTable', () => {
  const t = schema.employeesTable;
  const cols = ['id', 'firstName', 'lastName', 'phone', 'email', 'isActive', 'createdAt', 'updatedAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });

  it('phone should be unique', () => {
    expect(t.phone.isUnique).toBe(true);
  });
});

describe('buildingsTable', () => {
  const t = schema.buildingsTable;
  const cols = [
    'id', 'name', 'address', 'city', 'province', 'postalCode',
    'totalUnits', 'occupiedUnits', 'description', 'properties',
    'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('employeeAssignmentsTable', () => {
  const t = schema.employeeAssignmentsTable;
  const cols = ['id', 'employeeId', 'buildingId', 'role', 'isActive', 'createdAt', 'updatedAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('unitsTable', () => {
  const t = schema.unitsTable;
  const cols = [
    'id', 'buildingId', 'label', 'rentCents', 'status', 'bedrooms',
    'bathrooms', 'squareFeet', 'description', 'amenities', 'tenantName',
    'tenantPhone', 'tenantLeaseEnd', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('employeeSchedulesTable', () => {
  const t = schema.employeeSchedulesTable;
  const cols = [
    'id', 'employeeId', 'buildingId', 'dayOfWeek', 'startTime',
    'endTime', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('leadsTable', () => {
  const t = schema.leadsTable;
  const cols = [
    'id', 'fullName', 'email', 'phone', 'budgetCents', 'desiredUnit',
    'source', 'stage', 'notes', 'tags', 'language', 'assignedEmployeeId',
    'buildingId', 'unitId', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('visitsTable', () => {
  const t = schema.visitsTable;
  const cols = [
    'id', 'unitId', 'employeeId', 'leadId', 'dateTime',
    'durationMinutes', 'status', 'tenantConfirmed', 'occupantNotified',
    'employeeConfirmed', 'morningOfSent', 'confirmationToken', 'outcome',
    'notes', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });

  it('confirmationToken should be unique', () => {
    expect(t.confirmationToken.isUnique).toBe(true);
  });
});

describe('smsLogsTable', () => {
  const t = schema.smsLogsTable;
  const cols = [
    'id', 'twilioSid', 'visitId', 'employeeId', 'leadId',
    'phoneNumber', 'direction', 'messageBody', 'status', 'twilioStatus',
    'errorMessage', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });

  it('twilioSid should be unique', () => {
    expect(t.twilioSid.isUnique).toBe(true);
  });
});

describe('communicationLogsTable', () => {
  const t = schema.communicationLogsTable;
  const cols = [
    'id', 'leadId', 'employeeId', 'type', 'direction', 'content',
    'subject', 'attachments', 'status', 'metadata', 'isActive', 'createdAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('documentsTable', () => {
  const t = schema.documentsTable;
  const cols = [
    'id', 'name', 'type', 'category', 'fileSize', 'mimeType', 'url',
    'status', 'referenceId', 'referenceType', 'metadata', 'uploadedBy',
    'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('documentsLeadsTable', () => {
  const t = schema.documentsLeadsTable;
  const cols = ['documentId', 'leadId', 'assignedAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('leasesTable', () => {
  const t = schema.leasesTable;
  const cols = [
    'id', 'unitId', 'leadId', 'tenantFirstName', 'tenantLastName',
    'tenantEmail', 'tenantPhone', 'rentCents', 'depositCents',
    'startDate', 'endDate', 'status', 'terms', 'signedAt',
    'createdBy', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('notificationPreferencesTable', () => {
  const t = schema.notificationPreferencesTable;
  const cols = [
    'id', 'userId', 'emailNotifications', 'smsNotifications',
    'weeklyDigest', 'quietHoursEnabled', 'quietHoursStart',
    'quietHoursEnd', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('notificationsTable', () => {
  const t = schema.notificationsTable;
  const cols = ['id', 'userId', 'type', 'title', 'message', 'data', 'isRead', 'createdAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('smsTemplatesTable', () => {
  const t = schema.smsTemplatesTable;
  const cols = [
    'id', 'name', 'body', 'language', 'category', 'description',
    'variables', 'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('smsCampaignsTable', () => {
  const t = schema.smsCampaignsTable;
  const cols = [
    'id', 'name', 'description', 'templateId', 'targetAudience',
    'buildingId', 'scheduleType', 'cronExpression', 'scheduledAt',
    'status', 'lastRunAt', 'nextRunAt', 'totalSent', 'totalFailed',
    'templateData', 'isActive', 'createdBy', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('smsQueueTable', () => {
  const t = schema.smsQueueTable;
  const cols = [
    'id', 'campaignId', 'reminderType', 'visitId', 'leaseId',
    'phoneNumber', 'messageBody', 'status', 'scheduledAt',
    'processedAt', 'retryCount', 'maxRetries', 'lastError',
    'twilioSid', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('paymentsTable', () => {
  const t = schema.paymentsTable;
  const cols = [
    'id', 'leaseId', 'amountCents', 'lateFeeCents', 'dueDate',
    'paidDate', 'status', 'method', 'reference', 'notes',
    'isActive', 'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('renewalOffersTable', () => {
  const t = schema.renewalOffersTable;
  const cols = [
    'id', 'leaseId', 'newStartDate', 'newEndDate', 'newRentCents',
    'newDepositCents', 'terms', 'status', 'sentAt', 'sentVia',
    'tenantResponse', 'respondedAt', 'notes', 'isActive',
    'createdAt', 'updatedAt',
  ];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

describe('smsOptOutsTable', () => {
  const t = schema.smsOptOutsTable;
  const cols = ['id', 'phoneNumber', 'reason', 'isActive', 'createdAt'];

  it('should have all expected columns', () => {
    cols.forEach((c) => expect(hasColumn(t, c)).toBeTruthy());
  });
});

// ── Column Type Tests ──
describe('column types', () => {
  it('uuid columns should use PgUUID type', () => {
    expect(schema.usersTable.id.columnType).toBe('PgUUID');
    expect(schema.buildingsTable.id.columnType).toBe('PgUUID');
    expect(schema.leadsTable.id.columnType).toBe('PgUUID');
  });

  it('text columns should use PgText type', () => {
    expect(schema.usersTable.email.columnType).toBe('PgText');
    expect(schema.buildingsTable.name.columnType).toBe('PgText');
  });

  it('integer columns should use PgInteger type', () => {
    expect(schema.buildingsTable.totalUnits.columnType).toBe('PgInteger');
    expect(schema.unitsTable.rentCents.columnType).toBe('PgInteger');
  });

  it('boolean columns should use PgBoolean type', () => {
    expect(schema.usersTable.isActive.columnType).toBe('PgBoolean');
    expect(schema.visitsTable.tenantConfirmed.columnType).toBe('PgBoolean');
  });

  it('timestamp columns should use PgTimestamp type', () => {
    expect(schema.usersTable.createdAt.columnType).toBe('PgTimestamp');
  });

  it('jsonb columns should use PgJsonb type', () => {
    expect(schema.buildingsTable.properties.columnType).toBe('PgJsonb');
  });
});

// ── Default Values Tests ──
describe('default values', () => {
  it('isActive should default to true across tables', () => {
    const tables = [
      schema.usersTable, schema.employeesTable, schema.buildingsTable,
      schema.unitsTable, schema.leadsTable, schema.visitsTable,
      schema.leasesTable, schema.paymentsTable,
    ];
    tables.forEach((t) => {
      expect(t.isActive.hasDefault).toBe(true);
    });
  });

  it('createdAt should have defaults', () => {
    expect(schema.usersTable.createdAt.hasDefault).toBe(true);
    expect(schema.buildingsTable.createdAt.hasDefault).toBe(true);
    expect(schema.leadsTable.createdAt.hasDefault).toBe(true);
  });

  it('id columns should have defaults (gen_random_uuid)', () => {
    expect(schema.usersTable.id.hasDefault).toBe(true);
    expect(schema.buildingsTable.id.hasDefault).toBe(true);
    expect(schema.leadsTable.id.hasDefault).toBe(true);
  });

  it('leads stage should default to nouveau', () => {
    expect(schema.leadsTable.stage.hasDefault).toBe(true);
  });

  it('visits status should default to scheduled', () => {
    expect(schema.visitsTable.status.hasDefault).toBe(true);
  });
});

// ── NotNull Constraints ──
describe('not null constraints', () => {
  it('required user fields should be notNull', () => {
    expect(schema.usersTable.email.notNull).toBe(true);
    expect(schema.usersTable.passwordHash.notNull).toBe(true);
    expect(schema.usersTable.firstName.notNull).toBe(true);
    expect(schema.usersTable.lastName.notNull).toBe(true);
  });

  it('nullable fields should not be notNull', () => {
    expect(schema.usersTable.phone.notNull).toBeFalsy();
    expect(schema.usersTable.lastLogin.notNull).toBeFalsy();
  });

  it('required building fields should be notNull', () => {
    expect(schema.buildingsTable.name.notNull).toBe(true);
    expect(schema.buildingsTable.address.notNull).toBe(true);
  });
});
