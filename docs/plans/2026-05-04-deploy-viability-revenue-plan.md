# CloudToLocalLLM Deploy, Viability, and Revenue Plan

> **For Hermes:** Use subagent-driven-development skill to execute this plan in bounded slices. Do not widen scope without re-checking the launch gate at the end of each phase.

**Goal:** Ship CloudToLocalLLM as a Linux-first, tester-usable, sellable early product with a unified cockpit, usable voice companion, permissioned vision/desktop control, and a credible path to pilot revenue.

**Architecture:** Treat CloudToLocalLLM as a local-first operator cockpit, not a generic chat app. The launchable wedge is: secure runtime channel + single main chat/timeline + reopenable setup wizard + visible background work + low-latency voice sidecar + explicit vision/desktop permissions. Linux-first is the fastest viable release path; Windows remains important but must not block first revenue.

**Tech Stack:** Flutter desktop/web, Node backend services, GitHub Actions releases, packaging scripts for Linux (.tar.gz/.deb/AppImage + installer), Hermes/OpenClaw runtime integration, Tailscale-first private mesh.

---

## 0. Grounded current state

### Verified now
- Repo path: `/mnt/data/projects/CloudToLocalLLM`
- Product source-of-truth docs exist:
  - `SPEC.md`
  - `README.md`
  - `docs/architecture/HERMES_LOCAL_THINK_TRAIN.md`
  - `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PLAN.md`
  - `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PHASE_6_PLAN.md`
- Packaging/release scaffolding exists:
  - `.github/workflows/app-builds.yml`
  - `.github/workflows/deployment.yml`
  - `scripts/packaging/build_installer.sh`
  - `scripts/packaging/build_deb.sh`
  - `scripts/packaging/build_appimage.sh`
- Current working tree already contains substantial in-progress cockpit/voice/setup work.
- Live verification on RIGHT-PC succeeded:
  - targeted tests passed:
    - `test/services/hermes_manager/local_think_job_service_test.dart`
    - `test/services/hermes_manager/local_think_timeline_mapper_test.dart`
    - `test/widgets/hermes/main_chat_timeline_item_test.dart`
    - `test/services/onboarding/setup_wizard_service_test.dart`
    - `test/services/hermes_manager/hermes_gateway_control_service_test.dart`
  - targeted analyze passed:
    - onboarding
    - Hermes gateway control
    - local-think services
    - main chat timeline item
    - home layout
    - local voice input service
    - voice conversation status card
  - Linux debug build succeeded:
    - `build/linux/x64/debug/bundle/cloudtolocalllm`

### What this means
CloudToLocalLLM is **close enough to product-shape that the bottleneck is now launch discipline**, not raw invention. The repo already smells like a near-product, but it is still carrying too many parallel surfaces and unclosed launch gaps.

### Current launch blockers
1. No explicit release gate for a **tester-safe Linux-first build**.
2. Main chat cockpit direction is strong but still mid-integration.
3. Voice is directionally right but not yet proven as a calm, reliable companion loop.
4. Vision/camera exist in architecture and services, but user-facing permission/state clarity still matters.
5. Setup/reconnect/recovery needs to feel boring and trustworthy.
6. Revenue packaging is not yet simplified into one clear early offer.
7. Tester onboarding/docs/demo flow are not yet tight enough.

---

## 1. Product wedge

### The product is
A **local-first intelligent operator cockpit** with:
- one durable main timeline
- one connected runtime channel
- one calm companion surface for voice
- explicit device-scoped eyes/hands
- restart-safe continuity
- visible background work

### The product is not
- a generic prompt box
- a toy avatar app
- a dev dashboard first
- a vague “AI infrastructure” story
- a surveillance product
- a cloud-only assistant

### First launch promise
**“Install it, connect your runtime, talk to it, see what it is doing, recover after interruptions, and keep work coherent across the day.”**

---

## 2. Launch thesis

### Best first deploy shape
**Linux-first desktop early access**

Why:
- Linux build already verified locally.
- Packaging/release scaffolding already exists.
- The product’s current proof path is strongest on RIGHT-PC-style setups.
- Trying to make Linux + Windows + web equally polished before launch will slow revenue.

### Early-access promise
The first paying/testable version does **not** need all long-term pillars fully complete. It needs to be:
- coherent
- installable
- trustworthy
- visibly useful within minutes
- good enough that a tester wants another session tomorrow

---

## 3. Ruthless launch priorities

### P0 — Must be true before taking pilots seriously
1. **Main chat is the real channel of truth**
   - chat + background work + runtime events + restart/resume surface together
2. **Setup wizard is boring and reliable**
   - first run works
   - reopen setup later works
   - stale endpoints do not trap the user
3. **Hermes runtime connection is inspectable and restart-safe**
   - connect
   - disconnect
   - recover
   - explain current state cleanly
4. **Linux build + packaging + install path are reproducible**
   - debug is not enough
   - need release artifact confidence
5. **Voice companion is good enough to demo without embarrassment**
   - low-friction
   - brisk
   - not noisy
   - not canned
6. **Camera/vision permissions are explicit and legible**
   - obvious on/off state
   - obvious why it is active
   - no creepy ambiguity

### P1 — Strongly preferred before first paid pilot
1. Artifact/status history in cockpit feels stable.
2. Minimal tester docs and guided onboarding exist.
3. Landing/pricing/demo framing are clean.
4. At least one “holy shit” workflow is repeatable end-to-end.

### P2 — Can wait until after first pilots
1. Deep multi-device sync transport.
2. Hosted runtime productization.
3. Broad Windows parity.
4. Fancy memory/search/compliance extras.
5. Non-essential visual polish.

---

## 4. Launch gates

### Gate A — Internal alpha gate
Pass only if all are true:
- targeted tests green
- targeted analyze green
- Linux release build green
- install script path audited
- setup wizard works on a fresh state
- main chat shows local-think/runtime activity in one timeline
- voice sidecar can demo a calm basic loop

### Gate B — Friendly tester gate
Pass only if all are true:
- a new tester can install without live hand-holding
- runtime selection is understandable
- the app survives one forced restart without losing the plot
- the app shows “what it is doing” clearly
- camera/desktop permissions feel explicit and safe
- there is a one-page quick-start and one-page known-limits doc

### Gate C — Paid pilot gate
Pass only if all are true:
- at least 3 testers used it more than once
- at least 2 testers completed one meaningful workflow
- at least 1 tester says they would pay or continue under a pilot agreement
- bugs are annoying but not trust-destroying
- support burden is manageable

---

## 5. Concrete 4-week timeline

## Week 1 — Freeze the launch wedge
**Outcome:** decide what ships in the first pilot and stop widening scope.

### Task 1.1: Write launch scope lock
**Objective:** define exactly what is in/out for the first paid/testable version.

**Files:**
- Create: `docs/plans/2026-05-04-launch-scope-lock.md`
- Modify: `README.md`
- Modify: `SPEC.md` only if product language is inconsistent

**Deliverables:**
- one-paragraph launch promise
- Linux-first declaration
- P0/P1/P2 list
- explicit non-goals

### Task 1.2: Verify cockpit path
**Objective:** prove the main chat cockpit path is the primary surface.

**Files:**
- Modify: `lib/screens/home/home_layout.dart`
- Modify: `lib/services/hermes_manager/main_chat_timeline_composer.dart`
- Modify: `lib/widgets/hermes/main_chat_timeline_item.dart`
- Test: `test/widgets/hermes/main_chat_timeline_item_test.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_composer_test.dart`

**Acceptance:**
- background jobs show in the main timeline
- no dependency on a separate “diagnostic-first” flow
- empty conversation still surfaces meaningful job state

### Task 1.3: Verify release-critical setup flow
**Objective:** harden setup, reconnect, and setup reopen path.

**Files:**
- Modify: `lib/services/onboarding/setup_wizard_service.dart`
- Modify: `lib/services/gateway_command_resolver.dart`
- Test: `test/services/onboarding/setup_wizard_service_test.dart`

**Acceptance:**
- first run clean
- stale/manual URL recoverable
- user can reopen setup later
- runtime choice path is understandable

### Task 1.4: Produce release-readiness checklist
**Objective:** convert vague readiness into a checked list.

**Files:**
- Create: `docs/plans/2026-05-04-release-readiness-checklist.md`

**Acceptance:**
- every launch blocker maps to a pass/fail checkbox

---

## Week 2 — Make the demo actually slap
**Outcome:** the app becomes something you can show without apology.

### Task 2.1: Tighten voice companion loop
**Objective:** make voice feel like product, not scaffolding.

**Files:**
- Modify: `docs/architecture/VOICE_CONVERSATION_SYSTEM.md`
- Modify: `lib/services/voice/local_voice_input_service.dart`
- Modify: `lib/widgets/voice/voice_conversation_status_card.dart`
- Modify: sidecar/avatar window wiring if already present
- Test: `test/services/local_voice_input_service_test.dart`
- Test: `test/widgets/voice_conversation_status_card_test.dart`

**Acceptance:**
- transcript/engagement/reply state feel coherent
- no noisy filler text
- status labels are user-comprehensible
- demo path does not depend on hidden manual steps

### Task 2.2: Clarify vision/camera state
**Objective:** ensure camera/vision are helpful and explicit.

**Files:**
- Modify: vision settings / permission UI files under `lib/services/vision/` and related screens/widgets
- Add tests where practical

**Acceptance:**
- visible on/off state
- explicit permission language
- clear reason for camera availability
- no spooky passive ambiguity

### Task 2.3: End-to-end internal demo script
**Objective:** standardize one repeatable “wow” flow.

**Files:**
- Create: `docs/plans/2026-05-04-internal-demo-script.md`

**Acceptance:**
- install
- connect runtime
- voice interaction
- visible background event
- restart/recover
- inspect artifact/state

---

## Week 3 — Deploy for real testers
**Outcome:** Linux release flow is credible and testers can self-start.

### Task 3.1: Verify packaging and installer path
**Objective:** prove the release path, not just local debug.

**Files:**
- Inspect: `.github/workflows/app-builds.yml`
- Inspect: `.github/workflows/deployment.yml`
- Inspect/modify if needed:
  - `scripts/packaging/build_installer.sh`
  - `scripts/packaging/build_deb.sh`
  - `scripts/packaging/build_appimage.sh`
  - `scripts/packaging/installer-template.sh`

**Acceptance:**
- release artifact matrix understood
- installer script generation verified
- known packaging failures documented
- one Linux install test completed from artifact/installer path

### Task 3.2: Ship tester docs
**Objective:** reduce hand-holding.

**Files:**
- Create: `docs/early-access/quick-start.md`
- Create: `docs/early-access/known-limits.md`
- Create: `docs/early-access/how-to-send-feedback.md`
- Modify: `README.md`

**Acceptance:**
- a tester can install and connect without a live call
- known rough edges are explicit
- feedback request is structured

### Task 3.3: Landing and offer clarity
**Objective:** make the product and offer understandable.

**Files:**
- Create: `docs/plans/2026-05-04-positioning-pricing.md`
- Modify website/landing assets if in repo scope

**Acceptance:**
- one-sentence pitch
- who it is for
- what first pilots get
- what is not promised yet

---

## Week 4 — Pilot conversion
**Outcome:** move from “interesting app” to “paying or near-paying pilot.”

### Task 4.1: Recruit 3–5 serious testers
**Objective:** prioritize users with real friction, not curiosity tourists.

**Profile:**
- operators
- founders
- people drowning in messages/admin/context
- people who can articulate ROI quickly

### Task 4.2: Run structured pilot loop
**Objective:** extract signal, not random comments.

**Each tester session should answer:**
- what did they try?
- where did they hesitate?
- what felt magical?
- what felt untrustworthy?
- what would they pay for?
- would they use it tomorrow?

### Task 4.3: Ask for pilot commitment
**Objective:** validate money, not just praise.

**Ask for one of:**
- paid pilot
- letter-of-intent style commitment
- scheduled follow-up with a deployment target

---

## 6. Revenue model assumptions

These are **planning assumptions**, not market facts.

### Offer A — Lean pilot
- Early access local-first cockpit
- Price assumption: **$99/month** per pilot user/business
- Best for: founder/operator/test users who already run their own runtime

### Offer B — Mixed local/business
- Local-first base: **$49/month**
- Business/operator tier: **$149/month**
- Best for: users who need more support, shared workflows, or more obvious business value

### Offer C — Hosted-plus pilot
- Hosted/white-glove pilot: **$249/month**
- Best for: users who want less setup burden and are willing to pay for convenience

### Computed scenarios
Using simple internal planning math:

- **Lean pilot**
  - 5 pilots @ $99 = **$495 MRR**
  - 10 pilots @ $99 = **$990 MRR**
  - 15 pilots @ $99 = **$1,485 MRR**

- **Mixed offer**
  - 5 local-first @ $49 + 3 business @ $149 = **$692 MRR**
  - 10 local-first @ $49 + 5 business @ $149 = **$1,235 MRR**
  - 20 local-first @ $49 + 8 business @ $149 = **$2,172 MRR**

- **Hosted-plus**
  - 3 hosted @ $249 + 5 local-first @ $49 = **$992 MRR**
  - 5 hosted @ $249 + 10 local-first @ $49 = **$1,735 MRR**
  - 8 hosted @ $249 + 15 local-first @ $49 = **$2,727 MRR**

### Recommendation
Start with **Offer A or B** first.
Do **not** lead with hosted complexity until the local-first product is sticky.

---

## 7. Expense model assumptions

These are **incremental planning assumptions** for the first pilot stage.

### Lean pilot base cost assumption
- VPS/control plane: **$60/mo**
- email/domain/misc: **$40/mo**
- release/monitoring buffer: **$50/mo**
- **Total base: $150/mo**

### Mixed offer base cost assumption
- VPS/control plane: **$80/mo**
- email/domain/misc: **$40/mo**
- support/demo buffer: **$80/mo**
- **Total base: $200/mo**

### Hosted-plus base cost assumption
- VPS/control plane: **$150/mo**
- email/domain/misc: **$40/mo**
- hosted runtime buffer: **$200/mo**
- **Total base: $390/mo**

### Gross margin after these assumed base costs
- Lean: 10 pilots @ $99 → **$840/mo after base cost**
- Mixed: 10 local-first + 5 business → **$1,035/mo after base cost**
- Hosted-plus: 5 hosted + 10 local-first → **$1,345/mo after base cost**

### Important note
At this stage, **time/support cost is the hidden expense**. The main danger is not infra burn; it is launching too broad and becoming your own unpaid support desk.

---

## 8. What to cut right now

Do not let these delay the pilot wedge:
- deep sync transport implementation
- broad cloud-hosted runtime work
- broad Windows parity before Linux pilots
- advanced memory/vector work beyond what the cockpit needs
- huge architecture refactors with no tester-facing payoff
- dashboard/admin expansion that weakens the calm primary surface

---

## 9. What must visibly work for the product to feel real

1. Install
2. Setup
3. Connect runtime
4. Talk to it
5. See what it is doing
6. Recover after interruption/restart
7. Use voice without cringing
8. Understand when vision/desktop permissions are active
9. End the session still trusting it

If any of those feel broken, the app is still pre-pilot.

---

## 10. Immediate execution order

### First
- lock scope
- verify cockpit path
- harden setup/reconnect/reopen setup

### Second
- tighten voice loop
- tighten permission/vision clarity
- define the one repeatable demo flow

### Third
- verify packaging/release/install path
- publish tester docs
- simplify pricing/offer

### Fourth
- onboard 3–5 serious testers
- collect repeat-use signal
- ask for paid pilot commitment

---

## 11. Decision rule

For every task, ask:

**Does this make CloudToLocalLLM easier to deploy, easier to trust, easier to demo, or easier to pay for in the next 30 days?**

If yes, it stays.
If no, it waits.

---

## 12. Blunt conclusion

CloudToLocalLLM is close enough that the next win is **not more concept expansion**.
The next win is:
- freeze the launch wedge
- make Linux early access real
- make the voice/cockpit experience slap
- prove a tester can install, connect, trust, and want it
- then turn that into pilot revenue

That is the path.
