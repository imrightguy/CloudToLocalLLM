const { hasVerificationEvidence } = require('../../src/models/renovation');

describe('hasVerificationEvidence', () => {
  it('rejects missing or empty evidence', () => {
    expect(hasVerificationEvidence()).toBe(false);
    expect(hasVerificationEvidence([])).toBe(false);
    expect(hasVerificationEvidence([{ type: 'tests', summary: '   ' }])).toBe(false);
    expect(hasVerificationEvidence([{ type: 'notes', summary: 'ok' }])).toBe(false);
  });

  it('accepts explicit verification evidence', () => {
    expect(hasVerificationEvidence([
      { type: 'tests', summary: 'Jest schema test passed' },
      { type: 'artifact', summary: 'Uploaded screenshot', reference: '/tmp/evidence.png' },
    ])).toBe(true);
  });
});
