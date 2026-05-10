const {
  NON_TERMINAL_STATUSES,
  TERMINAL_STATUSES,
  isOpenWorkStatus,
  summarizeIssueQueue,
} = require('../src/services/issue-queue-state');

describe('issue-queue-state', () => {
  it('treats blocked and in_review work as open so the queue is not empty', () => {
    expect(isOpenWorkStatus('blocked')).toBe(true);
    expect(isOpenWorkStatus('in_review')).toBe(true);
    expect(isOpenWorkStatus('todo')).toBe(true);
    expect(isOpenWorkStatus('backlog')).toBe(true);
    expect(isOpenWorkStatus('in_progress')).toBe(true);
    expect(isOpenWorkStatus('done')).toBe(false);
    expect(isOpenWorkStatus('cancelled')).toBe(false);
  });

  it('summarizes open and terminal issue states separately', () => {
    const result = summarizeIssueQueue([
      { id: 'IMM-451', status: 'blocked' },
      { id: 'IMM-514', status: 'in_progress' },
      { id: 'IMM-999', status: 'done' },
      { id: 'IMM-998', status: 'cancelled' },
      { id: 'IMM-997', status: 'in_review' },
    ]);

    expect(result).toEqual({
      openCount: 3,
      terminalCount: 2,
      empty: false,
      openIssues: [
        { id: 'IMM-451', status: 'blocked' },
        { id: 'IMM-514', status: 'in_progress' },
        { id: 'IMM-997', status: 'in_review' },
      ],
      terminalIssues: [
        { id: 'IMM-999', status: 'done' },
        { id: 'IMM-998', status: 'cancelled' },
      ],
    });
  });

  it('reports the queue as empty only when all issues are terminal', () => {
    const result = summarizeIssueQueue([
      { id: 'IMM-100', status: 'done' },
      { id: 'IMM-101', status: 'cancelled' },
    ]);

    expect(result.empty).toBe(true);
    expect(result.openCount).toBe(0);
    expect(result.terminalCount).toBe(2);
  });

  it('exports the canonical status sets', () => {
    expect(NON_TERMINAL_STATUSES).toEqual(new Set([
      'todo',
      'backlog',
      'in_progress',
      'blocked',
      'in_review',
    ]));
    expect(TERMINAL_STATUSES).toEqual(new Set(['done', 'cancelled']));
  });
});
