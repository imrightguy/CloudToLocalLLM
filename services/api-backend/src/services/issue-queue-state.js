const NON_TERMINAL_STATUSES = new Set([
  'todo',
  'backlog',
  'in_progress',
  'blocked',
  'in_review',
]);

const TERMINAL_STATUSES = new Set(['done', 'cancelled']);

const isOpenWorkStatus = (status) => NON_TERMINAL_STATUSES.has(status);

const summarizeIssueQueue = (issues = []) => {
  const openIssues = issues.filter((issue) => isOpenWorkStatus(issue.status));
  const terminalIssues = issues.filter((issue) => TERMINAL_STATUSES.has(issue.status));

  return {
    openCount: openIssues.length,
    terminalCount: terminalIssues.length,
    empty: openIssues.length === 0,
    openIssues,
    terminalIssues,
  };
};

module.exports = {
  NON_TERMINAL_STATUSES,
  TERMINAL_STATUSES,
  isOpenWorkStatus,
  summarizeIssueQueue,
};
