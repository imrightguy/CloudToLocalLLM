const { VALID_LEAD_STAGES, USER_FACING_STAGES, SMS_FLOW_STAGES } = require('../src/constants/lead-stages');

describe('Lead stage constants', () => {
  it('VALID_LEAD_STAGES is frozen (immutable)', () => {
    expect(Object.isFrozen(VALID_LEAD_STAGES)).toBe(true);
  });

  it('USER_FACING_STAGES is frozen', () => {
    expect(Object.isFrozen(USER_FACING_STAGES)).toBe(true);
  });

  it('SMS_FLOW_STAGES is frozen', () => {
    expect(Object.isFrozen(SMS_FLOW_STAGES)).toBe(true);
  });

  it('VALID_LEAD_STAGES is the union of user-facing and SMS-flow stages', () => {
    const expected = [...USER_FACING_STAGES, ...SMS_FLOW_STAGES];
    expect([...VALID_LEAD_STAGES].sort()).toEqual([...new Set(expected)].sort());
  });

  it('contains the default stage (nouveau)', () => {
    expect(VALID_LEAD_STAGES).toContain('nouveau');
  });

  it('contains all expected user-facing pipeline stages', () => {
    const expectedPipeline = [
      'nouveau', 'contacte', 'qualifie',
      'visitePlanifiee', 'visite_planifiee',
      'offreEnvoyee', 'negociation', 'bailSigne', 'signe',
    ];
    for (const stage of expectedPipeline) {
      expect(USER_FACING_STAGES).toContain(stage);
    }
  });

  it('contains all expected SMS-flow stages', () => {
    const expectedSms = ['visite_completee', 'interesse', 'inactif'];
    for (const stage of expectedSms) {
      expect(SMS_FLOW_STAGES).toContain(stage);
    }
  });

  it('has no duplicates in VALID_LEAD_STAGES', () => {
    const unique = new Set(VALID_LEAD_STAGES);
    expect(unique.size).toBe(VALID_LEAD_STAGES.length);
  });

  it('no overlap between user-facing and SMS-flow stages', () => {
    const overlap = USER_FACING_STAGES.filter(s => SMS_FLOW_STAGES.includes(s));
    expect(overlap).toEqual([]);
  });
});
