# Agent Branch + DevOps Merge Workflow Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Move ImmoGestion from loose shared-tree agent pushes to explicit per-agent branches with DevOps-owned merge control.

**Architecture:** Agents should never land work straight on `main`. They create or switch to `agent/*` branches, verify their slice, push that branch, and open a PR. DevOps owns the PR review/merge path and production release timing.

**Tech Stack:** git, gh CLI, GitHub Actions, repo docs/scripts.

---

### Task 1: Add a safe agent branch push helper

**Objective:** Make the normal agent path branch-first and block accidental pushes from `main`.

**Files:**
- Modify: `scripts/agent-push.sh`

**Steps:**
1. Add explicit branch support (`--branch`).
2. Refuse protected branches like `main` and `master` unless explicitly overridden.
3. Require agent branches to use `agent/*` by default.
4. Push with upstream tracking so later PR tooling works.

**Verification:**
- `bash -n scripts/agent-push.sh`
- temp repo test proving branch creation, commit, and push on `agent/*`
- temp repo test proving push from `main` is rejected

### Task 2: Add a PR helper for agent branches

**Objective:** Give agents a clean handoff path to DevOps without granting them merge ownership.

**Files:**
- Create: `scripts/agent-open-pr.sh`

**Steps:**
1. Build a small wrapper around `gh pr create`.
2. Default base branch to `main`.
3. Require current branch to be `agent/*` unless explicitly overridden.
4. Print the resulting PR URL for handoff.

**Verification:**
- `bash -n scripts/agent-open-pr.sh`
- `--help` output check

### Task 3: Add PR-side workflow checks

**Objective:** Surface branch-discipline mistakes early in GitHub checks.

**Files:**
- Create: `.github/workflows/branch-discipline.yml`
- Create: `.github/CODEOWNERS`

**Steps:**
1. Add a PR workflow targeting `main`.
2. Fail if the source branch is not `agent/*` or `devops/*`.
3. Add a repo-wide CODEOWNERS entry pointing to the DevOps owner.

**Verification:**
- YAML parse check
- read back workflow content

### Task 4: Document the operating rule

**Objective:** Make the new branch/merge ownership the explicit repo policy.

**Files:**
- Modify: `AGENTS.md`

**Steps:**
1. Add the branch naming rule.
2. Add the PR/merge ownership rule.
3. Add the command snippets for the new scripts.

**Verification:**
- read back changed sections
- ensure docs match actual script flags

### Task 5: Commit only the workflow-improvement slice

**Objective:** Land the repo/process improvement without sweeping unrelated dirty work.

**Files:**
- `scripts/agent-push.sh`
- `scripts/agent-open-pr.sh`
- `.github/workflows/branch-discipline.yml`
- `.github/CODEOWNERS`
- `docs/plans/2026-05-14-agent-branch-devops-merge.md`
- selective hunks from `AGENTS.md`

**Verification:**
- `git diff --cached --name-only`
- commit only the intended files/hunks
- push to `main` as the workflow bootstrap change
