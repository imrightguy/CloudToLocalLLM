const {
  renovationRecordSchema,
  updateRenovationRecordSchema,
  renovationTaskSchema,
  updateRenovationTaskSchema,
  renovationOrderSchema,
  updateRenovationOrderSchema,
  receivingEventSchema,
  surplusItemSchema,
  updateRenovationSurplusItemSchema,
  workerIntakeRecordSchema,
  updateWorkerIntakeRecordSchema,
  VALID_RENOVATION_STATUSES,
  VALID_RENOVATION_STATUS_TRANSITIONS,
  VALID_RENOVATION_READINESS_STATES,
  VALID_RENOVATION_READINESS_TRANSITIONS,
  VALID_RENOVATION_TASK_STATUSES,
  VALID_RENOVATION_TASK_TRANSITIONS,
  VALID_RENOVATION_ORDER_STATUSES,
  VALID_RENOVATION_ORDER_TRANSITIONS,
  VALID_RENOVATION_SURPLUS_STATUSES,
  VALID_RENOVATION_SURPLUS_TRANSITIONS,
  VALID_RENOVATION_INTAKE_MESSAGE_KINDS,
  VALID_RENOVATION_INTAKE_STATUSES,
  VALID_RENOVATION_INTAKE_STATUS_TRANSITIONS,
} = require('../../src/models/renovation');

describe('renovation model status rules', () => {
  it('defines the expected renovation lifecycle states', () => {
    expect(VALID_RENOVATION_STATUSES).toEqual([
      'planned',
      'active',
      'blocked',
      'ready_for_leasing',
      'completed',
      'archived',
    ]);

    expect(VALID_RENOVATION_STATUS_TRANSITIONS).toEqual({
      planned: ['active', 'blocked', 'archived'],
      active: ['blocked', 'ready_for_leasing', 'archived'],
      blocked: ['active', 'ready_for_leasing', 'archived'],
      ready_for_leasing: ['completed', 'archived'],
      completed: ['archived'],
      archived: [],
    });
  });

  it('defines the expected readiness bridge states', () => {
    expect(VALID_RENOVATION_READINESS_STATES).toEqual([
      'not_started',
      'in_progress',
      'blocked',
      'ready_to_list',
      'ready_for_leasing',
      'ready',
    ]);

    expect(VALID_RENOVATION_READINESS_TRANSITIONS).toEqual({
      not_started: ['in_progress'],
      in_progress: ['blocked', 'ready_to_list'],
      blocked: ['in_progress', 'ready_to_list'],
      ready_to_list: ['ready_for_leasing'],
      ready_for_leasing: ['ready'],
      ready: [],
    });
  });

  it('defines the expected task, order, surplus, and intake transitions', () => {
    expect(VALID_RENOVATION_TASK_STATUSES).toEqual(['todo', 'in_progress', 'blocked', 'done', 'cancelled']);
    expect(VALID_RENOVATION_TASK_TRANSITIONS).toEqual({
      todo: ['in_progress', 'blocked', 'cancelled'],
      in_progress: ['blocked', 'done', 'cancelled'],
      blocked: ['in_progress', 'cancelled'],
      done: [],
      cancelled: [],
    });

    expect(VALID_RENOVATION_ORDER_STATUSES).toEqual(['draft', 'ordered', 'partially_received', 'received', 'cancelled']);
    expect(VALID_RENOVATION_ORDER_TRANSITIONS).toEqual({
      draft: ['ordered', 'cancelled'],
      ordered: ['partially_received', 'received', 'cancelled'],
      partially_received: ['received', 'cancelled'],
      received: [],
      cancelled: [],
    });

    expect(VALID_RENOVATION_SURPLUS_STATUSES).toEqual(['available', 'reserved', 'used', 'discarded']);
    expect(VALID_RENOVATION_SURPLUS_TRANSITIONS).toEqual({
      available: ['reserved', 'used', 'discarded'],
      reserved: ['available', 'used', 'discarded'],
      used: [],
      discarded: [],
    });

    expect(VALID_RENOVATION_INTAKE_MESSAGE_KINDS).toEqual([
      'update',
      'missing_material',
      'blocker',
      'completion',
      'surplus',
      'general_note',
    ]);
    expect(VALID_RENOVATION_INTAKE_STATUSES).toEqual(['new', 'triaged', 'linked', 'resolved', 'dismissed']);
    expect(VALID_RENOVATION_INTAKE_STATUS_TRANSITIONS).toEqual({
      new: ['triaged', 'linked', 'resolved', 'dismissed'],
      triaged: ['linked', 'resolved', 'dismissed'],
      linked: ['resolved', 'dismissed'],
      resolved: [],
      dismissed: [],
    });
  });

  it('requires the core renovation record fields', () => {
    const { error, value } = renovationRecordSchema.validate({
      unitId: 'b3a1c84c-0b69-4a7f-b6f9-d3c88d4d1a11',
      title: 'Apartment 3B renovation',
    });

    expect(error).toBeUndefined();
    expect(value.status).toBe('planned');
    expect(value.readinessState).toBe('not_started');
  });

  it('rejects empty task updates and accepts valid ones', () => {
    expect(updateRenovationRecordSchema.validate({}).error).toBeTruthy();
    expect(updateRenovationTaskSchema.validate({}).error).toBeTruthy();
    expect(updateRenovationOrderSchema.validate({}).error).toBeTruthy();
    expect(updateRenovationSurplusItemSchema.validate({}).error).toBeTruthy();
    expect(updateWorkerIntakeRecordSchema.validate({}).error).toBeTruthy();
    expect(updateWorkerIntakeRecordSchema.validate({
      mediaUrls: ['https://example.com/photo-2.jpg'],
      mediaContentTypes: ['image/jpeg'],
      twilioMessageSid: 'SM124',
    }).error).toBeUndefined();

    expect(renovationTaskSchema.validate({
      renovationRecordId: 'f5dfe9d0-1c93-4e52-a0f4-fd4d7d6e7d7a',
      title: 'Paint bedroom',
    }).error).toBeUndefined();

    expect(renovationOrderSchema.validate({
      renovationRecordId: 'f5dfe9d0-1c93-4e52-a0f4-fd4d7d6e7d7a',
      vendorName: 'Home Depot',
      itemName: 'Paint',
      quantityOrdered: 3,
    }).error).toBeUndefined();

    expect(receivingEventSchema.validate({ quantityReceived: 1 }).error).toBeUndefined();
    expect(surplusItemSchema.validate({
      renovationRecordId: 'f5dfe9d0-1c93-4e52-a0f4-fd4d7d6e7d7a',
      itemName: 'Extra trim',
      quantityAvailable: 2,
    }).error).toBeUndefined();
    expect(workerIntakeRecordSchema.validate({
      renovationRecordId: 'f5dfe9d0-1c93-4e52-a0f4-fd4d7d6e7d7a',
      sourcePhone: '+151****0123',
      messageBody: 'Need more screws',
      twilioMessageSid: 'SM123',
      mediaUrls: ['https://example.com/photo-1.jpg'],
      mediaContentTypes: ['image/jpeg'],
    }).error).toBeUndefined();
  });
});
