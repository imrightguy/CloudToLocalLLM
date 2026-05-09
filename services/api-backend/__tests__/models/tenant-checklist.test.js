const {
  buildChecklistTemplate,
  tenantChecklistStartSchema,
  tenantChecklistResumeSchema,
  tenantChecklistPauseSchema,
  tenantChecklistSubmitSchema,
  VALID_CHECKLIST_TYPES,
  VALID_SESSION_STATUSES,
  VALID_STEP_STATUSES,
} = require('../../src/models/tenant-checklist');

describe('tenant-checklist model', () => {
  it('exports the expected state vocabularies', () => {
    expect(VALID_CHECKLIST_TYPES).toEqual(['move_in', 'move_out']);
    expect(VALID_SESSION_STATUSES).toContain('awaiting_confirmation');
    expect(VALID_STEP_STATUSES).toEqual(['pending', 'completed', 'blocked', 'skipped']);
  });

  it('builds move-in steps in order', () => {
    const steps = buildChecklistTemplate('move_in');
    expect(steps).toHaveLength(5);
    expect(steps[0]).toEqual(expect.objectContaining({
      stepKey: 'identity_unit_confirmation',
      stepOrder: 1,
      status: 'pending',
    }));
    expect(steps[4]).toEqual(expect.objectContaining({
      stepKey: 'final_acknowledgment',
      stepOrder: 5,
    }));
  });

  it('builds move-out steps in order', () => {
    const steps = buildChecklistTemplate('move_out');
    expect(steps).toHaveLength(6);
    expect(steps[3]).toEqual(expect.objectContaining({
      stepKey: 'key_return',
      stepOrder: 4,
    }));
  });

  it('validates start payloads', () => {
    const { error, value } = tenantChecklistStartSchema.validate({
      unitId: '550e8400-e29b-41d4-a716-446655440000',
      checklistType: 'move_in',
      tenantName: 'Marie Tremblay',
    });

    expect(error).toBeUndefined();
    expect(value.metadata).toEqual({});
  });

  it('rejects invalid checklist types', () => {
    const { error } = tenantChecklistStartSchema.validate({
      unitId: '550e8400-e29b-41d4-a716-446655440000',
      checklistType: 'wrong',
    });

    expect(error).toBeDefined();
  });

  it('validates submit payloads with evidence and signatures', () => {
    const { error, value } = tenantChecklistSubmitSchema.validate({
      forceComplete: true,
      stepUpdates: [
        { stepKey: 'identity_unit_confirmation', status: 'completed' },
      ],
      attachments: [
        { stepKey: 'identity_unit_confirmation', url: 'https://example.com/photo.jpg' },
      ],
      signatures: [
        { signatureType: 'tenant_confirmation', signerName: 'Marie', method: 'typed' },
      ],
    });

    expect(error).toBeUndefined();
    expect(value.forceComplete).toBe(true);
    expect(value.stepUpdates).toHaveLength(1);
  });

  it('validates resume and pause payloads', () => {
    expect(tenantChecklistResumeSchema.validate({ resumedByUserId: '550e8400-e29b-41d4-a716-446655440001' }).error).toBeUndefined();
    expect(tenantChecklistPauseSchema.validate({ reason: 'Tenant stepped away' }).error).toBeUndefined();
  });
});
