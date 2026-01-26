# MCP Tools Documentation

This document provides detailed documentation and usage guidelines for the Model Context Protocol (MCP) tools available in this environment.

## Table of Contents

- [Sequential Thinking](#sequential-thinking)
- [Playwright](#playwright)
- [Context7](#context7)
- [n8n MCP](#n8n-mcp)

---

## Sequential Thinking

**Server:** `sequentialthinking`
**Tool:** `sequentialthinking`

### Description

A detailed tool for dynamic and reflective problem-solving through thoughts. This tool helps analyze problems through a flexible thinking process that can adapt and evolve. Each thought can build on, question, or revise previous insights as understanding deepens.

### When to use this tool

- Breaking down complex problems into steps
- Planning and design with room for revision
- Analysis that might need course correction
- Problems where the full scope might not be clear initially
- Problems that require a multi-step solution
- Tasks that need to maintain context over multiple steps
- Situations where irrelevant information needs to be filtered out

### Key features

- You can adjust total_thoughts up or down as you progress
- You can question or revise previous thoughts
- You can add more thoughts even after reaching what seemed like the end
- You can express uncertainty and explore alternative approaches
- Not every thought needs to build linearly - you can branch or backtrack
- Generates a solution hypothesis
- Verifies the hypothesis based on the Chain of Thought steps
- Repeats the process until satisfied
- Provides a correct answer

### Parameters

- `thought` (string, required): Your current thinking step, which can include:
  - Regular analytical steps
  - Revisions of previous thoughts
  - Questions about previous decisions
  - Realizations about needing more analysis
  - Changes in approach
  - Hypothesis generation
  - Hypothesis verification
- `nextThoughtNeeded` (boolean, required): True if you need more thinking, even if at what seemed like the end
- `thoughtNumber` (integer, required): Current number in sequence (can go beyond initial total if needed)
- `totalThoughts` (integer, required): Current estimate of thoughts needed (can be adjusted up/down)
- `isRevision` (boolean, optional): A boolean indicating if this thought revises previous thinking
- `revisesThought` (integer, optional): If is_revision is true, which thought number is being reconsidered
- `branchFromThought` (integer, optional): If branching, which thought number is the branching point
- `branchId` (string, optional): Identifier for the current branch (if any)
- `needsMoreThoughts` (boolean, optional): If reaching end but realizing more thoughts needed

### Example

```json
{
  "thought": "I need to analyze the user's request and break it down into steps.",
  "nextThoughtNeeded": true,
  "thoughtNumber": 1,
  "totalThoughts": 3
}
```

---

## Playwright

**Server:** `playwright`

### Description

Provides browser automation capabilities for testing, scraping, and interacting with web pages.

### Key Tools

- `browser_navigate`: Navigate to a URL.
- `browser_click`: Click an element.
- `browser_type`: Type text into an input field.
- `browser_take_screenshot`: Capture a screenshot of the page.
- `browser_evaluate`: Execute JavaScript on the page.

### Usage

Use this tool for:

- End-to-end testing of web applications.
- Verifying UI elements and interactions.
- Automating browser-based tasks.

### Example (Navigate)

```json
{
  "url": "https://example.com"
}
```

---

## Context7

**Server:** `context7`

### Description

Retrieves up-to-date documentation and code examples for libraries and frameworks.

### Key Tools

- `resolve-library-id`: Find the correct library ID for a given name.
- `get-library-docs`: Fetch documentation for a specific library.

### Usage

Use this tool when you need:

- Accurate API references.
- Code examples for specific libraries.
- To understand how to use a third-party package.

### Workflow

1. Call `resolve-library-id` with the library name.
2. Use the returned `context7CompatibleLibraryID` to call `get-library-docs`.

### Example (Get Docs)

```json
{
  "context7CompatibleLibraryID": "/vercel/next.js",
  "mode": "code",
  "topic": "routing"
}
```

---

## n8n MCP

**Server:** `n8n-mcp`

### Description

Integrates with n8n for workflow automation, allowing you to manage workflows, nodes, and executions.

### Key Tools

- `list_workflows`: List available workflows.
- `n8n_get_workflow`: Retrieve details of a specific workflow.
- `n8n_trigger_webhook_workflow`: Trigger a workflow via webhook.
- `list_nodes`: List available n8n nodes.

### Usage

Use this tool to:

- Automate complex tasks using n8n workflows.
- Manage and monitor n8n executions.
- Integrate external services via n8n nodes.

### Example (List Workflows)

```json
{
  "limit": 10,
  "active": true
}
