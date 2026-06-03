# Cline MCP Tools: Workflow and Rules

This document outlines the rules and standard operating procedures for utilizing the available Model Context Protocol (MCP) tools to enhance task execution, planning, and interaction with external services.

## I. General Principles

1. **Universal Documentation-First Methodology**: **ALL** tasks (simple or complex) MUST begin with a review of relevant project documentation and `.kiro/steering/` files. This ensures all actions as Kilocode align with the specific git workflows, CI/CD guidelines, and architectural structures defined in the project.
2. **Mandatory Primary Framework**: The `sequentialthinking` MCP is the **MANDATORY** primary framework for every complex task. It must be used to ensure systematic reasoning, iterative analysis, and self-correction.
3. **Minimize External Steering**: By autonomously applying the documentation-first methodology and the sequential thinking framework, Kilocode minimizes the need for external steering while maintaining technical excellence.
4. **Atomic Operations**: Each tool call is an atomic step. Execute one tool at a time and wait for a successful response.
5. **Schema Adherence**: Always consult the tool's input schema to ensure correct formatting and parameter usage.

## II. Focus and Task Management

1. **Task Progress Checklist**: For every task, maintain and update a `task_progress` checklist (or `update_todo_list`). This ensures a clear roadmap and transparent progress tracking.
2. **Single-Minded Execution**: I will focus on completing one step or sub-task at a time, as defined in the `task_progress` checklist. I will avoid context switching or attempting to address multiple unrelated issues simultaneously.
3. **Regular Re-evaluation**: Periodically, I will re-evaluate the current task and its progress against the overall objective. If the current approach is not leading to the desired outcome, I will pause, analyze, and adjust the strategy.
4. **Proactive Clarification**: If I encounter any ambiguity, missing information, or unclear instructions, I will immediately use `ask_followup_question` to seek clarification from the user. I will not make assumptions that could lead to incorrect or inefficient work.
5. **Ignore Irrelevant Information**: I will actively filter out and ignore any information that is not directly relevant to the current task or sub-task. This includes extraneous details in `environment_details` or conversational tangents.

---

## III. Core Workflow: Structured Task Management

For any request that requires multiple steps, changes to several files, or a sequence of dependent actions, I will use the `task_progress` parameter in my tool calls to outline and track progress. Upon completion of the task, I will use the `attempt_completion` tool.

### Task Management Workflow

1. **Documentation-First Phase (UNIVERSAL)**:
    * **Action**: Review relevant documentation in `docs/` and `.kiro/steering/` **BEFORE** any tool execution.
    * **Preemptive Updates**: Appropriate documentation updates **MUST precede code changes**. This ensures the design and requirements are clarified first.
    * **Tool**: `read_file`, `list_files`, `codebase_search`, `write_to_file`, `apply_diff`.
    * **Action**: Explicitly reference the documentation reviewed and updated in the initial analysis to maintain a cohesive source of truth.

2. **Planning Phase (PLAN/ARCHITECT MODE)**:
    * **Action**: Gather information and ask clarifying questions using `ask_followup_question`.
    * **Tool**: `plan_mode_respond` or `update_todo_list`.
    * **Action**: Present a detailed plan, including a task checklist.

3. **Reasoning & Analysis Framework (MANDATORY for Complex Tasks)**:
    * **Condition**: Required for all complex problems, architectural decisions, or systematic debugging.
    * **Tool**: `sequentialthinking`.
    * **Action**: Break down the problem, hypothesize solutions, and iteratively verify assumptions. Use this as the primary framework for all technical problem-solving.

4. **Execution Cycle (ACT/CODE MODE)**:
    * **Action**: Once the user approves the plan and switches to `ACT MODE`, I will execute the steps outlined in the `task_progress` checklist.
    * **Tool**: Any available tool (standard or MCP)
    * **Action**: I will perform the necessary actions to complete each step, updating the `task_progress` checklist with each tool call.

5. **Completion**:
    * **Condition**: After all steps in the `task_progress` checklist are completed.
    * **Tool**: `attempt_completion`
    * **Action**: I will present the final result of the task to the user, including the completed `task_progress` checklist.

---

## III. MCP Tool-Specific Rules & Use Cases

### A. Sequential Thinking

* **Server**: `github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking`
  * **Tool**: `sequentialthinking`
  * **Use Case**: For complex problem-solving, planning, and analysis that requires dynamic and reflective thought processes. This tool allows for breaking down problems, generating hypotheses, verifying them, and adapting the approach as understanding deepens.
  * **Rules**:
    * Start with an initial estimate of `total_thoughts` but be ready to adjust.
    * Feel free to question or revise previous thoughts using `isRevision` and `revisesThought`.
    * Add more thoughts if needed, even after reaching the estimated `total_thoughts`, by setting `nextThoughtNeeded` to `true`.
    * Express uncertainty and explore alternative approaches.
    * Mark thoughts that revise previous thinking or branch into new paths.
    * Generate a solution hypothesis when appropriate and verify it.
    * Only set `nextThoughtNeeded` to `false` when a satisfactory answer is reached.

### B. Azure Operations

* **Server**: `github.com/Azure/azure-mcp`
  * **Use Case**: For managing and interacting with various Azure services and resources. This includes documentation search, Azure Developer CLI (azd) operations, best practices, Kubernetes (AKS), App Configuration, App Service, Authorization, Cosmos DB, Function Apps, Key Vault, Monitor, SQL, Storage, and more.
  * **Rules**:
    * Always specify the `intent` parameter for Azure tools.
    * Use `learn=true` to discover available sub-commands and parameters for a specific tool.
    * Prioritize specific Azure tools (e.g., `aks`, `appservice`, `storage`) over generic CLI commands when managing Azure resources.
    * For documentation, use the `documentation` tool with a clear query.
    * For generating Azure CLI commands, use `extension_cli_generate`.
    * For installing Azure CLI tools, use `extension_cli_install`.

### C. GitHub Operations

* **Server**: `github.com/github/github-mcp-server`
  * **Use Case**: For seamless integration with GitHub repositories, including managing pull requests, issues, files, branches, releases, and user/team information.
  * **Rules**:
    * Always provide `owner` and `repo` parameters for repository-specific operations.
    * Use `create_or_update_file` for remote file modifications, providing the `sha` if updating an existing file.
    * Use `push_files` for committing multiple files in a single operation.
    * For code reviews, use `add_comment_to_pending_review` or `pull_request_review_write`.
    * For issue management, use `issue_read` and `issue_write`.
    * For searching, use `search_code`, `search_issues`, `search_pull_requests`, `search_repositories`, or `search_users` with appropriate queries.

---

## IV. CLI Tools Integration

In addition to MCP servers, I will leverage powerful command-line interface (CLI) tools for direct interaction with external services.

### A. GitHub CLI (`gh`)

* **Use Case**: For seamless integration with GitHub repositories. This includes managing pull requests, issues, gists, and repository actions directly from the command line.
* **Workflow**:
  * **Code Reviews**: I can check out pull requests, view diffs, and leave comments using `gh pr checkout`, `gh pr diff`, and `gh pr review`.
  * **Issue Management**: I can create, list, and view issues using `gh issue create`, `gh issue list`, and `gh issue view`.
  * **Automation**: I will use `gh` to script complex interactions with GitHub, such as creating a new repository and pushing code to it in a single flow.

### B. Google Cloud CLI (`gcloud`)

* **Use Case**: For managing resources and services on Google Cloud Platform (GCP). This is essential for tasks involving cloud infrastructure, deployments, and administration.
* **Workflow**:
  * **Deployments**: I will use `gcloud app deploy` or `gcloud run deploy` to deploy applications to App Engine or Cloud Run.
  * **Resource Management**: I can manage virtual machines, storage buckets, and databases using commands like `gcloud compute instances`, `gcloud storage`, and `gcloud sql`.
  * **Authentication & Configuration**: I will ensure I am authenticated (`gcloud auth login`) and have the correct project configured (`gcloud config set project`) before performing any operations.

### C. Docker Best Practices for Flutter Web Apps

* **Standard Pattern**: Always use the standard multi-stage Docker build pattern for Flutter web applications.
* **Rules**:
  * **CRITICAL - Never run Flutter as root**: ALWAYS switch to non-root user BEFORE any Flutter commands (`flutter pub get`, `flutter build`, etc.). Add `USER 1000:1000` (or container default) BEFORE `RUN flutter` commands. Verify with `RUN whoami && id` if needed.
  * **Use COPY, not git clone**: Copy source files from build context using `COPY`, not `git clone`. This is faster, enables Docker layer caching, and follows standard Docker practices.
  * **Layer caching optimization**: Copy `pubspec.yaml` and `pubspec.lock` first, run `flutter pub get`, then copy the rest of the source. This caches dependencies unless pubspec changes.
  * **No user creation**: Never create users manually. Use the default non-root user that exists in the base container (e.g., Cirrus Flutter containers already have a default non-root user with UID 1000).
  * **Multi-stage builds**: Use separate build and runtime stages. Build with Flutter image, serve with lightweight nginx image.
  * **Example Pattern**:

      ```dockerfile
      FROM ghcr.io/cirruslabs/flutter:stable AS builder
      # CRITICAL: Switch to non-root BEFORE any Flutter commands
      USER 1000:1000
      WORKDIR /app
      COPY pubspec.yaml pubspec.lock ./
      RUN flutter pub get
      COPY . .
      RUN flutter build web --release
      
      FROM nginxinc/nginx-unprivileged:alpine
      COPY --from=builder --chown=nginx:nginx /app/build/web /usr/share/nginx/html
      ```

  * **Never run as root**: Always use the container's default non-root user. Never explicitly create users unless absolutely necessary and the container doesn't provide one.
  * **Verify non-root**: When debugging, add `RUN whoami && id` before Flutter commands to verify you're not root.

### D. Flutter Best Practices

* **Dependency Management**:
  * Always use `flutter pub get` to update dependencies, never manually edit `pubspec.lock`.
  * Use `flutter pub outdated` to identify packages that need updating.
  * Remove unused dependencies to keep the project lean.
  * Update discontinued packages (e.g., `js` package → use `dart:js_interop`).

* **Code Quality**:
  * Run `flutter analyze` before committing to catch linting errors.
  * Use `flutter format` to ensure consistent code formatting.
  * Prefer `debugPrint()` over `print()` for logging (respects Flutter's logging system).
  * Use platform-specific imports when necessary (`dart.library.html`, `dart.library.io`).

* **Build Practices**:
  * Use `flutter build web --release` for production builds.
  * Leverage `flutter pub get` caching by copying pubspec files first in Dockerfiles.
  * Always specify `--release` flag for production builds.

* **Authentication**:
  * Use Auth0 for web applications (no GCIP/Google Sign-In).
  * Use `dart:js_interop` for JavaScript interop (replaces deprecated `js` package).
  * Implement platform-specific auth services (Auth0WebService for web, others for mobile/desktop).

* **Web-Specific**:
  * Use `package:web/web.dart` for web platform detection and DOM manipulation.
  * Bridge JavaScript SDKs (like Auth0) through custom bridge files (`auth0-bridge.js`).
  * Handle redirect callbacks properly for OAuth flows.

### E. Version Management

* **Semantic Versioning Rules**:
  * Follow strict semantic versioning: `MAJOR.MINOR.PATCH`
  * **PATCH (4.1.x)**: Increment for bug fixes and minor fixes → 4.1.2, 4.1.3, 4.1.4...
  * **MINOR (4.x.0)**: Increment for feature updates and new features → 4.2.0, 4.3.0, 4.4.0...
  * **MAJOR (x.0.0)**: Increment for major changes, breaking changes, or new versions → 5.0.0, 6.0.0...
  * Current version location: `pubspec.yaml` (line 6)
  * Always update version when making changes, then commit with version bump message

* **Version Bump Decision Logic**:
  * Bug fix or minor correction? → Increment PATCH (4.1.2 → 4.1.3)
  * New feature or significant update? → Increment MINOR (4.1.2 → 4.2.0)
  * Breaking changes or major overhaul? → Increment MAJOR (4.1.2 → 5.0.0)
  * When user asks to "bump version", assess the scope of changes since last version

### F. Node.js Best Practices

* **Dependency Management**:
  * Use `npm ci` for production builds (faster, more reliable than `npm install`).
  * Use `npm install` for development (updates package.json and package-lock.json).
  * Never manually edit `package-lock.json`, let npm manage it.
  * Keep dependencies up to date with `npm outdated` and `npm update`.

* **Security**:
  * Run as non-root user in Docker containers (UID 1001 for Node.js apps).
  * Use `npm audit` to check for vulnerabilities.
  * Never hardcode secrets or API keys, use environment variables.
  * Validate and sanitize all user inputs.

* **Code Quality**:
  * Use structured logging (e.g., `winston`, `pino`) instead of `console.log`.
  * Implement proper error handling with try-catch blocks.
  * Use async/await instead of callbacks when possible.
  * Follow ESLint rules and fix linting errors before committing.

* **Docker Practices**:
  * Use multi-stage builds: build dependencies as root, then copy and run as non-root.
  * Copy `package*.json` first, run `npm ci`, then copy source code for better layer caching.
  * Use `node:24-alpine` or similar lightweight base images.
  * Example pattern:

      ```dockerfile
      FROM node:24-alpine AS base
      WORKDIR /app
      COPY package*.json ./
      RUN npm ci && chown -R 1001:1001 /app
      
      FROM node:24-alpine AS production
      RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
      WORKDIR /app
      COPY --from=base --chown=nodejs:nodejs /app/node_modules ./node_modules
      COPY --chown=nodejs:nodejs . .
      USER nodejs
      CMD ["npm", "start"]
      ```

* **API Development**:
  * Use Express.js middleware for authentication (e.g., `express-oauth2-jwt-bearer` for Auth0).
  * Implement proper CORS configuration for web clients.
  * Use environment variables for configuration (domain, audience, client IDs).
  * Validate JWT tokens before processing requests.

* **Performance**:
  * Use connection pooling for databases.
  * Implement request rate limiting.
  * Use compression middleware (e.g., `compression` package).
  * Cache static assets when appropriate.

### G. Paperclip Execution Lane Closure Discipline (#322 Fix)

* **Reference**: GitHub issue #322 — "Stop Paperclip execution lanes from self-closing as done"
* **Problem**: Paperclip executor agents were self-closing execution lanes to `done` prematurely, bypassing the review gate.
* **Root cause**: No repo-local guard prevented executors from writing a terminal `done` status to their own lanes when a canonical GitHub issue still required review or the lane only seeded child work.
* **Fix**: The following rules are now enforced repo-local:

1. **GitHub is the source of truth.** Executor-created Paperclip issues must not be self-closed to `done` unless the lane is explicitly designed for self-closure.
2. **Review-bound lanes stay non-terminal.** If a Paperclip execution lane is backed by a canonical GitHub issue, the executor-side issue must stay in an evidence-ready review state (`in_review`, `blocked`, or `cancelled`) until the review-authorized lane closes the canonical issue.
3. **Executor-created follow-on issues must remain non-terminal.** For GitHub issue #322, executor-created follow-on issues must remain non-terminal. Executors must not self-close such lanes as `done`.
4. **The live executor write path is the Paperclip issue-status update call.** It must not emit `done` on any lane without explicit review-authorization confirmation.
5. **Seeding-only lanes exit as `cancelled`, not `done`.** If a lane only seeds child work or emits handoff evidence but has no work of its own to complete, it must retire as `cancelled` or `blocked` rather than `done`.
6. **while GitHub issue #322 remains open, that write path must reject any attempt to set a follow-on lane to `done`.**
7. **Every new execution lane must link to its canonical GitHub issue** before any status change can be recorded as terminal.
8. **Verification before closure:** Operator-ready verification evidence must include: canonical GitHub issue link, current GitHub issue state, current Paperclip issue state, and the explicit review lane authorized to close the work.

### H. User Preferences & Communication Style

* **Terminal Output Formatting**:
  * Do NOT add decorative formatting to terminal commands (no colored text, emojis, or special formatting)
  * Keep terminal output clean and minimal
  * Avoid unnecessary visual enhancements that don't add functional value

* **Communication Style**:
  * Be direct and concise
  * Avoid flowery language or excessive enthusiasm
  * Focus on facts and actionable information
  * Skip unnecessary commentary or "beautiful" descriptions
