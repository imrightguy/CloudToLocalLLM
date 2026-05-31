import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from '@jest/globals';

describe('Review-only closure discipline policy', () => {
  const policyPath = resolve(
    process.cwd(),
    'docs/development/MCP_WORKFLOW_AND_RULES.md',
  );
  const policy = readFileSync(policyPath, 'utf8');

  it('keeps the canonical GitHub #322 self-close guard in place', () => {
    expect(policy).toContain('GitHub issue #322');
    expect(policy).toContain('Executors must not self-close such lanes as `done`.');
    expect(policy).toContain(
      'For GitHub issue #322, executor-created follow-on issues must remain non-terminal',
    );
    expect(policy).toContain(
      'The live executor write path is the Paperclip issue-status update call',
    );
    expect(policy).toContain(
      'while GitHub issue #322 remains open, that write path must reject any attempt to set a follow-on lane to `done`.',
    );
  });
});
