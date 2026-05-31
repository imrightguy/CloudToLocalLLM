# Main Chat Cockpit Transport Review Gate

Date: 2026-05-09

Status: review gate only. Do not add cockpit sync transport until this gate is green.

Purpose: define the security bar for any future transport path that carries main chat cockpit timeline sync records between paired devices.

Threat model companion: `docs/plans/2026-05-09-main-chat-cockpit-transport-threat-model.md`.

Scope: this gate covers only the future transport design review. It does not add sockets, HTTP listeners, WebSockets, Tailscale transport, or sync routes.

Required security rules before transport coding may begin:

1. No unauthenticated listener.
   - Do not add a local listener that accepts cockpit sync traffic without authentication.
   - If a listener is introduced later, it must have an explicit auth gate from the first line of code.

2. No all-interface bind by default.
   - Default binds must stay loopback-only.
   - Binding to `0.0.0.0` or equivalent must be an explicit user choice, not the default.

3. No client-selected target IP or route authority.
   - A sync sender must not choose the destination IP, hostname, or route as the source of truth.
   - Destinations must come from a trusted paired-device inventory with pinned identity.

4. No unpaired-device writes.
   - An unpaired device must not be able to write cockpit timeline sync records into the trust store or local timeline repository.
   - Writes require a trusted paired-device identity and replay protection.

5. No user-JWT-as-device-auth.
   - A signed-in user token may identify the account, but it must not authorize device sync by itself.
   - Device sync requires a paired-device identity plus a verified device signature.

6. No raw local transport spill.
   - Do not ship full local paths, command lines, logs, prompt files, output files, or local-only secrets in transport payloads.

7. No mutable overwrite semantics.
   - Sync must remain append-only with deterministic record identity and replay checks.

Review gate evidence required before transport coding may begin:

- Transport-specific threat model written and checked in.
- Router hardening tests still green.
- Sync envelope and trust-store tests still green.
- No accidental listener or route exposure in the future sync path files.

Board discipline for executor lanes that point at this gate:

- The executor-side Paperclip issue stays review-bound until a review/approval
  lane closes the canonical GitHub issue.
- If the work only prepares evidence or seeds child work, the executor lane must
  retire as `cancelled` or `blocked`, not `done`.
- Completion evidence must name the canonical GitHub issue and the review lane
  that is authorized to close it.

Go / no-go rule:

- GO only when the threat model is present and the verification evidence above is green.
- Otherwise NO-GO for transport coding.
