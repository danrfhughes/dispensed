# Dispensed — Product Backlog

*Last updated: 2026-03-12*

---

## EPIC: NHS App Integration

The NHS App has 37.4m registered users but stops at "prescription dispensed." Dispensed occupies the unserved gap from dispensed to taken. Integration eliminates manual medication setup — the single largest drop-off point in adherence apps.

> **Research ref:** pill_box_heuristics.pdf §7 ("NHS App adjacency — currently unoccupied infrastructure"); Medication UI Patterns §Setup Layer ("manual setup is the largest drop-off point in adherence apps"); Investment Case §2.3 (post-discharge digital review as highest-priority intervention)

### NHS-1: NHS Login (OmniAuth OIDC)
**Priority:** P1 — Foundation (all other NHS items depend on this)
**Complexity:** Medium
**API:** NHS Login — OpenID Connect with `private_key_jwt` auth
**Identity levels:** P0 (email only), P5 (verified demographics), P9 (full ID — needed for clinical data)
**Scopes:** `openid`, `profile` (NHS number, surname, DOB at P5+), `profile_extended`, `gp_registration_details`
**Onboarding:** Integration environment available with test patients on Spine; technical conformance then approval
**Implementation:** OmniAuth strategy wrapping NHS Login OIDC; store NHS number + proofing level on User/PatientProfile
**Notes:** P9 requires photo ID verification — expect conversion drop-off. Design for progressive step-up (start at P5, prompt P9 only when clinical data is needed).

> **Research ref:** Feature Priority Matrix p2 ("Integration with pharmacy prescriptions — High impact, High complexity, P2"); Investment Case §3 Option 1 (post-discharge digital pathway requires identity verification)

### NHS-2: Read Patient Demographics (PDS FHIR API)
**Priority:** P1 — Eliminates manual profile entry
**Complexity:** Low-Medium
**API:** Personal Demographics Service (PDS) FHIR R4 — Patient resource
**Auth:** User-restricted via NHS Login (P5+)
**Returns:** Name, DOB, address, NHS number, registered GP (ODS code), nominated pharmacy (ODS code), contact details
**Environments:** Sandbox, Integration, Production — all available
**Onboarding:** Digital via NHS API platform; requires valid use case and legal basis
**Implementation:** After NHS Login at P5+, call PDS to pre-populate PatientProfile (name, DOB, address). Reduces onboarding friction significantly.

> **Research ref:** Medication UI Patterns §Mistake 2 ("Setup complexity — requiring drug name, dosage, schedule, instructions, refill info is a huge barrier"); pill_box_heuristics.pdf §1 ("the 'already loaded' dependency" — users offload knowledge to the system; the system must earn that trust by being accurate from the start)

### NHS-3: Read Nominated Pharmacy (PDS FHIR API extension)
**Priority:** P2
**Complexity:** Low
**API:** Same PDS FHIR API — `Extension-UKCore-NominatedPharmacy` on Patient resource
**Returns:** ODS codes for P1 (preferred), P2 (appliance), P3 (temporary) nominations
**Depends on:** NHS-2 (same API call)
**Additional lookup:** ODS API or EPS Directory of Services to resolve ODS code to pharmacy name/address
**Implementation:** Display nominated pharmacy on profile; enables future refill reminder features and pharmacy-patient linking.

> **Research ref:** Feature Priority Matrix p1 ("Refill reminders — Medium impact, Low complexity, P1"); Investment Case §1.3 ("Community Pharmacy — management of complex dosette box regimens")

### NHS-4: Read Prescribed Medication
**Priority:** P2 — Highest-value but most complex; dependent on NHS API availability
**Complexity:** High
**APIs (three options, in order of feasibility):**

| API | What it provides | Auth | Status for third-party apps |
|-----|-----------------|------|-----------------------------|
| Prescriptions for Patients FHIR | EPS prescription data (MedicationRequest, MedicationDispense) | NHS Login P9 | Unclear — may be limited rollout |
| GP Connect Patient Facing Prescriptions | GP system medication list (acute + repeat) | NHS Login P9 + `gp_integration_credentials` | **Not onboarding new consumers** (NHS App only) |
| EPS FHIR API | Full EPS backend (prescribe/dispense/query) | CIS2 / app-restricted | Not patient-facing |

**Current reality:** GP Connect is closed to new third-party consumers. Prescriptions for Patients is the most viable route but availability is uncertain. Direct engagement with NHS England onboarding team required.

**Implementation (when available):** Auto-import prescribed medications into Dispensed on first login, eliminating manual setup entirely. Map SNOMED/dm+d codes to medication records. Present for user confirmation before activating schedules.

**FHIR → SCHED-1 mapping (added 2026-03-13):** FHIR MedicationRequest.dosageInstruction includes structured event timing codes that map directly to SCHED-1a's `routine_anchor` + `food_relation` fields. When NHS-4 delivers medication import, schedules can be auto-generated with correct routine anchors — no manual schedule setup needed.

| FHIR timing code | Meaning | routine_anchor | food_relation |
|---|---|---|---|
| `WAKE` | On waking | `waking` | — |
| `ACM` / `CM` / `PCM` | Before/at/after breakfast | `breakfast` | `before_food` / `with_food` / `after_food` |
| `ACD` / `CD` / `PCD` | Before/at/after lunch | `midday` | `before_food` / `with_food` / `after_food` |
| `ACV` / `CV` / `PCV` | Before/at/after evening meal | `evening_meal` | `before_food` / `with_food` / `after_food` |
| `HS` | Before sleep | `bedtime` | — |

This means SCHED-1a's data model is FHIR-ready by design. The manual schedule form is a stand-in for prescription data that doesn't yet exist in the app; once NHS-4 lands, the mapping is mechanical.

**Fallback (immediate):** NHS dm+d drug database lookup for medication setup (already referenced in research as best practice). Reduces typing errors and enables pill imagery.

> **Research ref:** Medication UI Patterns §Setup Layer Feature 1 ("Medication database lookup — RxNorm / NHS dm+d drug database; reduces errors, faster setup, enables pill imagery"); pill_box_heuristics.pdf §1 ("The undifferentiated tablet problem" — patients lose label context; auto-import preserves it); Feature Priority Matrix p2 ("Integration with pharmacy prescriptions — reduces setup errors but complex"); Investment Case §3 Option 1 ("older patients discharged with new or changed medicines, often with inadequate counselling")

---

## EPIC: Scheduling UX Overhaul

> **Research ref:** Design of Pill Boxes p3 ("rigidity is a problem — only 14% of participants used time-based reminders"); pill_box_heuristics.pdf §5 ("habit strength is the strongest single predictor of adherence"); Medication UI Patterns §Mistake 1 ("Time-only reminders — older adults think in routine triggers")

### SCHED-1: Routine-based reminders (anchor to meals/activities, not clock times)
**Priority:** P0
**Complexity:** Medium
**Research:** Feature Priority Matrix rates this "Very High impact, P0." Gualtieri et al. 2024 found only 14% of older adults use time-based reminders; routine-linked triggers are more durable.
**Research doc:** `Research/SCHED-1 Routine-Based Reminders Research.md`
**MVP scope (SCHED-1a):** Two new columns (`routine_anchor`, `food_relation`), `time_of_day` nullable, five hardcoded anchors (waking/breakfast/midday/evening_meal/bedtime), form leads with routine selection, dashboard shows routine labels, wider "due now" window for anchored doses.

### SCHED-1b: Per-anchor customisable time windows
**Priority:** P2
**Complexity:** Low
**Description:** Add `window_start` and `window_end` columns to schedules, replacing the hardcoded `window_minutes` lookup. Lets users define their own flexibility window per routine anchor (e.g. "my breakfast window is 06:30–09:00").
**Depends on:** SCHED-1a

### SCHED-1c: Weekend routine time overrides (dedicated UI)
**Priority:** P2
**Complexity:** Medium
**Description:** Dedicated UI for setting different routine times on weekends (e.g. breakfast at 07:00 weekdays, 09:00 weekends). Currently achievable by creating two schedules with specific days, but a streamlined UI would reduce friction. Medisafe offers this as a specific feature.
**Depends on:** SCHED-1a

### SCHED-1d: Auto-detect timing constraints from dm+d codes
**Priority:** P3
**Complexity:** High
**Description:** When a medication has a dm+d code, auto-populate `food_relation` and suggest the appropriate routine anchor based on known prescribing requirements (e.g. levothyroxine → waking + empty_stomach, metformin → with_food). Requires dm+d integration (INFRA-3).
**Depends on:** SCHED-1a, INFRA-3

### SCHED-1e: "I just had breakfast" real-time routine signal
**Priority:** P3
**Complexity:** High
**Description:** Let users signal when a routine event actually happens (e.g. tap "I'm having breakfast now"), shifting the dose's "due now" window in real time. Explored by CareClinic (tracks meals/sleep) but no medication-focused app implements this.
**Depends on:** SCHED-1a

### SCHED-1f: Routine time learning from user behaviour
**Priority:** P3
**Complexity:** High
**Description:** Analyse dose-taking patterns over time to learn when the user actually takes routine-anchored doses, and adjust default times and windows accordingly. E.g. if a user consistently takes their "breakfast" dose at 07:15, shift the default from 08:00.
**Depends on:** SCHED-1a

### SCHED-2: Dose regeneration on schedule edit
**Priority:** P0
**Complexity:** Medium

### SCHED-3: Twice-daily and complex frequency support ✅
**Priority:** P0
**Complexity:** Medium
**Status:** COMPLETE — overlap validator relaxed, twice-daily form option, controller creates two schedules in transaction, routine labels on medication show page. 220 examples, 0 failures. *(2026-03-13)*
**Research:** Adherence drops from ~79% (once daily) to ~51% (four times daily) — pill_box_heuristics.pdf §3. System must surface regimen complexity to the user.

### SCHED-4: Schedule conflict resolution UX
**Priority:** P1
**Complexity:** Medium

### SCHED-5: Schedule history / audit trail
**Priority:** P1
**Complexity:** Low

### SCHED-3b: Three-times-daily convenience UX
**Priority:** P2
**Complexity:** Low
**Description:** A "Three times a day" option in the schedule frequency selector that creates three Schedule records in a single transaction (morning, midday, evening). Currently achievable by adding schedules one at a time — this is a convenience shortcut, not new capability. Lower priority than SCHED-3 because the manual path works and three-times-daily regimens are less common than twice-daily.
**Depends on:** SCHED-3

### SCHED-7: PRN / as-needed medication support
**Priority:** P1
**Complexity:** Medium
**Description:** Support medications taken at the patient's discretion (pro re nata / "as needed") — e.g. pain relief, rescue inhalers, anti-nausea. Distinct from scheduled medications: no fixed times, no "missed" state, no dose generation. Key elements: (a) `prn` boolean on Medication or Schedule, (b) separate "Log a dose" action on the dashboard (patient-initiated, not system-prompted), (c) usage frequency tracking (doses per day/week), (d) max daily dose awareness (surface warnings when approaching prescribed limits, e.g. "3 of 4 max paracetamol doses today"), (e) PRN medications shown in a separate dashboard section from scheduled medications. Clinical note: PRN dose logging provides valuable data for pharmacist medication reviews — high PRN usage may indicate undertreated symptoms or need for a regular prescription.
**Research:** pill_box_heuristics.pdf §3 (regimen complexity); Feature Priority Matrix (medication tracking beyond scheduled doses)

### SCHED-6: Timezone edge cases
**Priority:** P2
**Complexity:** Low

---

## EPIC: Core UX — Verification First

> **Research ref:** pill_box_heuristics.pdf §1 ("the core user need is fast, reliable dose status confirmation, not the alert — 85% of participants cited visual confirmation as primary value"); §7 implication 1 ("Verification first")

### UX-1: "Due Now" home screen (single-task, what's due right now)
**Priority:** P0 (already partially implemented)
**Research:** Feature Priority Matrix P0; Medication UI Patterns Pattern 1; pill_box_heuristics.pdf §7.1 ("mark taken and 'have I already taken this?' check must be immediate and accessible without navigation")

### UX-2: Large Taken / Skip / Snooze confirmation actions
**Priority:** P0 (already partially implemented)
**Research:** Feature Priority Matrix P0; Medication UI Patterns Pattern 2 (three clear actions, large, colour-coded, labelled with text)

### UX-3: Missed dose workflow
**Priority:** P1
**Complexity:** Medium
**Research:** Feature Priority Matrix P1; Stuck et al. 2017 ("inflexible scheduling, weak handling of missed doses"); Medication UI Patterns §Mistake 5 ("escalation rather than repetition" — Reminder > Snooze > Second reminder > Caregiver alert)

### UX-4: Visual medication identification (pill photo, colour, shape, purpose label)
**Priority:** P1
**Complexity:** Medium
**Research:** Feature Priority Matrix P1; Design of Pill Boxes p2 ("older adults identify medications by appearance rather than name"); Medication UI Patterns Pattern 3 ("Blue capsule — blood pressure")

### UX-5: Move GP Practice and Nominated Pharmacy into hero banner
**Priority:** P1
**Complexity:** Low
**Description:** GP practice and nominated pharmacy info currently displayed as separate cards on the dashboard. Move them into the teal hero banner alongside the greeting/name/NHS number for a cleaner, more NHS App-like layout.

### UX-6: Fix "Taken?" popup alignment
**Priority:** P1
**Complexity:** Low
**Description:** The Taken/Skip/Cancel popup on the dashboard is misaligned — appears top-left of the viewport instead of anchored to the dose cell that was clicked. Should appear as an inline popover or modal centred on the triggering element.

### UX-7: WCAG 2.2 AA accessibility audit
**Priority:** P1
**Complexity:** Medium
**Research:** Design of Pill Boxes p4 ("treat WCAG 2.2 as the accessibility floor"); Feature Priority Matrix P0 (high-contrast UI, large tap targets >=44px)

---

## EPIC: Social Layer — Caregiver Integration

> **Research ref:** pill_box_heuristics.pdf §6 ("Data sharing with caregivers is the third highest evidence-weighted feature — effect weight 0.148"); §7.6 ("inverts the MDS dependency model"); Feature Priority Matrix P1

### CARE-1: Caregiver shared access / view
**Priority:** P1
**Complexity:** Medium-High

### CARE-2: Caregiver escalation alerts (missed dose > snooze > caregiver notification)
**Priority:** P1
**Complexity:** Medium

---

## EPIC: Notifications & Reminders

> **Research ref:** pill_box_heuristics.pdf §6 ("reminders improve adherence when introduced but habituation is a known failure mode — typical drop-off: weeks 1-4 high, declining to near-baseline by months 3-6"); Medication UI Patterns §Feature 4 ("Smart snooze and escalation")

### NOTIFY-1: Email reminders (ActionMailer)
**Priority:** P2
**Complexity:** Low

### NOTIFY-2: Push notifications
**Priority:** P2
**Complexity:** Medium

### NOTIFY-3: Smart snooze with escalation chain
**Priority:** P2
**Complexity:** Medium
**Research:** pill_box_heuristics.pdf §6 ("apps allowing snoozed or rescheduled reminders achieve better sustained adherence than fixed-time alerts")

---

## EPIC: Monitoring & Insight Layer

> **Research ref:** pill_box_heuristics.pdf §6 ("Documentation/logging has highest effect weight at 0.254 — the act of recording a dose has value beyond the reminder"); §6 Visualisation ("calendar/streak-based views preferred over numerical percentage displays; trajectories more motivating than current state")

### INSIGHT-1: Adherence calendar / streak view
**Priority:** P2
**Complexity:** Medium
**Research:** Feature Priority Matrix P1 ("Medication schedule calendar view — helps planning and confidence"); Medication UI Patterns Pattern 4

### INSIGHT-2: Schedule Complexity Score
**Priority:** P2
**Complexity:** Low
**Description:** A simple, visible metric showing the patient how complex their current medication schedule is. Counts: (a) distinct dosing times per day, (b) active food-relation constraints, (c) medications per slot (flagging overcrowded slots). Displayed as a plain-language summary, e.g. "You take medications at 4 different times each day, with 2 food-timing requirements." Not clinical advice — a conversation starter for pharmacist medication reviews.
**Strategic rationale:** NHS pharmacists conducting Structured Medication Reviews (SMRs) need evidence of real-world regimen complexity to justify simplification. Patients typically cannot articulate their own schedule burden — 20.7% of pill box users didn't know their own dosages. This score gives the pharmacist immediate visibility into consolidation opportunities, making the SMR more productive. If pharmacists find this data useful, they become an acquisition channel: recommending Dispensed because it generates data they need, not because it's "another reminder app."
**Research:** pill_box_heuristics.pdf §7.4; SCHED-3 Complex Scheduling Research §8 (NHS SMR context), §10 (recommendations)

### INSIGHT-3: SMR-ready adherence summary (shareable)
**Priority:** P2
**Complexity:** Medium
**Description:** A one-page exportable/shareable summary designed for pharmacist medication reviews. Contains: Schedule Complexity Score, adherence rates per medication over 28 days (aligned to dispensing cycle), taken/missed/skipped breakdown by time-of-day slot, schedule change history, and any flagged food-relation conflicts. Format: printable HTML or PDF. The patient brings this to their SMR appointment (or shares it digitally).
**Strategic rationale:** Pharmacists currently have no visibility into how patients actually take medications at home — only what was prescribed and dispensed. This summary bridges that gap with structured data the pharmacist can act on. Positions Dispensed as a clinical tool, not just a consumer app.
**Depends on:** INSIGHT-2, SCHED-5 (schedule history)
**Research:** SCHED-3 Complex Scheduling Research §8 (NHS SMR context); NICE NG5 (Medicines Optimisation); NHS Scotland 7-Steps Medication Review

---

## EPIC: Intentional Non-Adherence Support

> **Research ref:** pill_box_heuristics.pdf §3 ("intentional non-adherence ~28% — belief-based decisions not to take; almost entirely unserved by existing tools"); §5 Necessity-Concerns Framework ("medication concerns OR = 0.50 — each SD increase in concerns halves adherence odds; 17% had concerns exceeding necessity beliefs")

### INTENT-1: Medication concerns logging (structured "I'm worried about..." flow)
**Priority:** P2
**Complexity:** Medium

### INTENT-2: Condition-linked necessity information
**Priority:** P3
**Complexity:** Medium

---

## EPIC: Clinical Safety

> **Research ref:** pill_box_heuristics.pdf §2 ("the perfect adherence trap — five adverse events in MCA group vs zero in control; abrupt transition to full adherence caused dose-related side effects"); §7.2 ("If onboarding reveals significant sub-adherence, surface recommendation to discuss with GP")

### SAFETY-1: Perfect adherence trap warning on onboarding
**Priority:** P2
**Complexity:** Low

### SAFETY-2: DCB0129 clinical safety case
**Priority:** P2 (required before production clinical use)
**Complexity:** High

### SAFETY-3: DSPT compliance
**Priority:** P2
**Complexity:** High

### SAFETY-4: DTAC assessment
**Priority:** P1 (elevated from P3 — hard prerequisite for any NHS procurement conversation)
**Complexity:** Medium
**Description:** Complete the DTAC self-assessment against all five domains (clinical safety, data protection, technical security, interoperability, usability/accessibility). Can begin before app is feature-complete — the assessment documents the product's posture and roadmap, not just current state. DTAC is the gateway: without it, no commissioner or provider will enter procurement discussions.
**Depends on:** SAFETY-2 (DCB0129), SAFETY-3 (DSPT), SAFETY-5 (Cyber Essentials) — all feed into DTAC evidence
**Research:** INVEST-1a Commissioner-Provider Feature Requirements §6 (Compliance Gateway)

### SAFETY-5: Cyber Essentials (Plus) certification
**Priority:** P1 (required as part of DTAC)
**Complexity:** Medium
**Description:** Obtain NCSC-backed Cyber Essentials certification (and ideally Plus). Baseline cybersecurity requirement for all NHS suppliers. Covers: firewalls, secure configuration, user access control, malware protection, patch management. The assessment is conducted by an accredited body; Plus adds a hands-on technical verification. Required as evidence for DTAC domain 3 (technical security).
**Research:** INVEST-1a Commissioner-Provider Feature Requirements §6 (Compliance Gateway)

### SAFETY-6: DPIA (Data Protection Impact Assessment)
**Priority:** P2
**Complexity:** Medium
**Description:** ICO-required assessment for processing health data at scale. Implicit in DSPT but should be an explicit deliverable with its own sign-off. Covers: lawful basis for processing (likely legitimate interests + explicit consent for health data under UK GDPR Article 9), data flows, retention policy, rights of data subjects, risk assessment. Needed before live patient data flows in production.

### SAFETY-7: Scheduling logic transparency for clinical risk evaluation
**Priority:** P1 (elevated — prerequisite for DCB0129 and DTAC clinical safety domains)
**Complexity:** Medium
**Description:** Any app logic that determines what information is presented to users must be documented in a format accessible to clinical risk assessors who are not reading Ruby. This covers: schedule overlap detection rules, dose generation logic, routine anchor defaults and time windows, missed dose classification, "due now" window calculation, reorder nudge timing. Deliverable: a plain-language logic specification document that maps each user-visible scheduling decision to the code that produces it, with worked examples. Must be maintained as scheduling logic evolves. The test suite provides mechanical verification that code matches spec; this document provides the human-readable layer that a Clinical Safety Officer can validate against DCB0129 hazard analysis.
**Applies to:** All app logic with clinical or informational impact on users — not just scheduling. Any new feature that changes what a user sees about their medication, doses, or adherence must be added to this document.
**Depends on:** SAFETY-2 (DCB0129) — this feeds directly into the clinical safety case as evidence of design traceability.

---

## EPIC: Security Audit

> Dispensed processes NHS patient data including NHS numbers, demographics, and medication information. Security posture must be demonstrable before any production use with real patient data, and is a hard prerequisite for Cyber Essentials (SAFETY-5), DSPT (SAFETY-3), and DTAC (SAFETY-4).

### SEC-1: Dependency vulnerability audit
**Priority:** P1
**Complexity:** Low
**Description:** Run `bundle audit` and `yarn audit` (if JS deps exist). Review and remediate all known CVEs in dependencies. Set up automated checks (e.g. GitHub Dependabot or `bundler-audit` in CI). Establish a policy for dependency update cadence.

### SEC-2: Authentication and session security review
**Priority:** P1
**Complexity:** Medium
**Description:** Review Devise configuration against OWASP recommendations: password complexity, session timeout, account lockout, CSRF protection, secure cookie flags, remember-me token handling. Review NHS Login integration for token storage security, callback validation, and session binding. Verify no sensitive data in logs.

### SEC-3: Input validation and injection review
**Priority:** P1
**Complexity:** Medium
**Description:** Audit all controller actions and form inputs for: SQL injection (parameterised queries), XSS (output encoding, Content-Security-Policy), mass assignment (strong parameters completeness), path traversal. Review any raw SQL or `html_safe` usage. Check HTTP security headers (X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security).

### SEC-4: Data protection at rest and in transit
**Priority:** P1
**Complexity:** Medium
**Description:** Verify TLS configuration on Render (certificate, HSTS). Review database encryption posture (Render Postgres encryption at rest). Audit what sensitive fields (NHS numbers, names, addresses) are stored and whether field-level encryption is warranted. Review backup encryption. Ensure no PII in application logs.

### SEC-5: Authorisation and access control review
**Priority:** P1
**Complexity:** Low
**Description:** Verify all controller actions enforce correct ownership (patient can only see/modify their own data). Check for IDOR vulnerabilities across medications, schedules, doses, and patient profiles. Review admin role permissions. Verify no information leakage via error messages or API responses.

### SEC-6: Penetration test (external)
**Priority:** P2 (after SEC-1 through SEC-5 remediated)
**Complexity:** High
**Description:** Commission an external penetration test from an accredited provider (CHECK or CREST certified). Required as evidence for Cyber Essentials Plus (SAFETY-5). Scope: web application, authentication flows, API endpoints, NHS Login integration. Remediate findings before production launch.
**Depends on:** SEC-1 through SEC-5, SAFETY-5

---

## EPIC: Infrastructure

### INFRA-1: Local dev → PostgreSQL (replace SQLite) ✅
**Priority:** P1
**Complexity:** Low
**Status:** COMPLETE — pg gem, database.yml all PostgreSQL, local databases running.

### INFRA-2: Staging environment
**Priority:** P1
**Complexity:** Medium

### INFRA-3: dm+d drug database integration (NHS Dictionary of Medicines and Devices)
**Priority:** P1
**Complexity:** Medium
**Research:** Medication UI Patterns §Setup Layer Feature 1 ("RxNorm / NHS dm+d drug database — reduces errors, faster setup, enables pill imagery")

### INFRA-4: Full BDD/Capybara test coverage
**Priority:** P1
**Complexity:** Medium
**Description:** Comprehensive integration test suite using Capybara system specs (rack_test driver). Cover all user-facing flows end-to-end: sign up, sign in (email + NHS Login), dashboard interaction (mark taken/skipped), medication CRUD, schedule CRUD, adherence view, reorder warnings, archived medications, GP/pharmacy info cards. Ensure all happy paths and key error paths are exercised through the browser stack.

### INFRA-4a: JS-dependent Capybara specs (Selenium)
**Priority:** P2
**Complexity:** Medium
**Depends on:** INFRA-4
**Description:** Add Selenium/headless Chrome driver for system specs that require JavaScript execution. Covers: schedule form radio/checkbox toggles (routine anchor vs time_of_day conditional display, specific-days checkboxes), taken/skip popup interactions, any Turbo Frame/Stream behaviour.

### INFRA-4b: Dose regeneration E2E system spec
**Priority:** P2
**Complexity:** Low
**Depends on:** INFRA-4
**Description:** End-to-end system spec verifying that editing a schedule (time, days, routine anchor) through the browser triggers dose regeneration. Currently covered by model specs (SCHED-2) but not exercised through the full stack.

### INFRA-4c: Timezone edge case specs
**Priority:** P2
**Complexity:** Medium
**Depends on:** INFRA-4, SCHED-6
**Description:** System and unit specs covering timezone handling: UTC storage with London display, daylight saving transitions, dose scheduling near midnight, week view crossing day boundaries.

---

## EPIC: Uncollected Prescriptions

> **Research ref:** Investment Case §1.2 ("wasted medicines — £300m annually, England"); pill_box_heuristics.pdf §4 ("NHS App handles prescription ordering and collection logistics but stops at the pharmacy door")

### UNCOL-1: Collection rate monitoring (patient-facing)
**Priority:** P2
**Complexity:** Medium
**Description:** Track and surface to the patient their own prescription collection rate over time — similar to the adherence view. Visual feedback loop to encourage behaviour change.

### UNCOL-2: "I'm on my way" notification (patient → pharmacy)
**Priority:** P3
**Complexity:** Medium
**Description:** Patient confirms via the app that they are heading to the pharmacy to collect. Triggers notification to the pharmacy side.

### UNCOL-3: Just-in-time fulfilment (pharmacy-facing)
**Priority:** P3
**Complexity:** High
**Description:** When a patient sends an "I'm on my way" signal, the pharmacy receives a notification to begin dispensing — reducing wait time and minimising stock sitting uncollected on shelves. Requires a pharmacist-role user type (Practitioner model) and pharmacy/organisation model (B2B layer).
**Depends on:** Organisation/B2B model, Practitioner user role

---

## EPIC: Product Investment Case

> **Research ref:** Digital_Medication_Adherence_Investment_Case.docx (system-level health economics case — establishes the £400m–£930m annual cost of non-adherence); SCHED-3 Complex Scheduling Research §8 (NHS SMR context, pharmacist-as-acquisition-channel thesis)

### INVEST-1: Commissioner/Provider product investment case for Dispensed
**Priority:** P2
**Complexity:** High (iterative — research-heavy, multiple drafts expected)
**Description:** A product-level investment case connecting Dispensed's specific features to the cost savings quantified in the existing system-level health economics document. Target audience: NHS ICB commissioners and provider trust decision-makers. Must answer: "Why commission/fund Dispensed specifically, rather than any other adherence tool?" Structured around three value propositions: (a) patient-facing adherence improvement (routine-anchored scheduling, verification-first UX, habit formation), (b) pharmacist workflow integration (SMR-ready adherence summaries, Schedule Complexity Score, adherence data pharmacists can act on), (c) population-level intelligence (aggregated adherence data segmented by condition, medication class, demographic — commissioner-grade insight into where non-adherence costs are concentrated). Must include: competitive differentiation (NHS Login, FHIR alignment, routine-anchor model, UK-specific dispensing cycle awareness), deployment model, indicative pricing/commissioning structure, and modelled ROI using figures from the existing investment case.
**Approach:** Iterative. Research phase first (INVEST-1a), then drafting (INVEST-1b), then review cycles.
**Depends on:** Existing system-level investment case (Research folder); INSIGHT-2, INSIGHT-3 (pharmacist integration features); research into commissioner/provider feature requirements (INVEST-1a)
**Research:** Digital_Medication_Adherence_Investment_Case.docx; SCHED-3 Complex Scheduling Research; Feature Priority Matrix; pill_box_heuristics.pdf

### INVEST-1a: Research — commissioner/provider feature requirements
**Priority:** P2
**Complexity:** Medium
**Status:** In progress
**Description:** Research what specific features and data outputs NHS commissioners (ICBs) and providers (trusts, community pharmacy) would need from a medication adherence platform to justify commissioning it. Includes: population-level adherence dashboards, condition/medication-class segmentation, integration with existing NHS analytics (FDP, CQRS, NHSBSA dispensing data), clinical safety compliance (DCB0129, DTAC, DSPT), data governance and IG requirements, and evidence of cost-effectiveness. Also identify which features Dispensed already has or is close to having that tick these boxes.

---

## Prioritisation Framework

*Added: 2026-03-13*

| Priority | Criteria | Test |
|----------|----------|------|
| **P0** | **"The app doesn't work without this."** Core loop functionality — can a user add a medication, set a schedule, see what's due, and mark it taken? | Would a real user abandon the app on day one if this were missing? |
| **P1** | **"The app works but can't grow without this."** Two sub-types: (a) features that remove barriers to adoption (setup friction, trust, identity); (b) hard prerequisites that block an entire strategic pathway (compliance, infrastructure). | Does the absence of this feature block user acquisition, or block a future route to market entirely? |
| **P2** | **"Makes the app significantly better or opens a new value stream."** Retention features, new user segments (pharmacists, caregivers), enrichment, and strategic research. The app functions without these and no pathway is blocked by their absence. | Does this improve retention, open a new audience, or generate strategic insight — but the app still works without it? |
| **P3** | **"Good idea, park until there's demand or bandwidth."** Features where user need is speculative, or that serve a market segment that doesn't yet exist. | Is there concrete evidence of user demand, or is this anticipating a future need? |

**Override rule — Dependency elevation:** If Feature X is a prerequisite for Features Y and Z, X gets elevated regardless of its standalone value. Example: SAFETY-4 (DTAC) moved from P3 to P1 because the entire commissioner strategy depends on it passing.

---

## Priority Summary

| Priority | Items | Theme |
|----------|-------|-------|
| P0 | ~~SCHED-1a~~, ~~SCHED-2~~, ~~SCHED-3~~, UX-1, UX-2 | Core scheduling + verification loop |
| P1 | ~~NHS-1~~, ~~NHS-2~~, SCHED-4, SCHED-5, SCHED-7, UX-3, UX-4, UX-5, UX-6, UX-7, CARE-1, CARE-2, ~~INFRA-1~~, INFRA-2, INFRA-3, ~~INFRA-4~~, SAFETY-4, SAFETY-5, SAFETY-7, SEC-1–5 | NHS foundation, PRN support, accessibility, caregiver, infra, compliance, security |
| P2 | NHS-3, NHS-4, SCHED-1b, SCHED-1c, SCHED-3b, SCHED-6, NOTIFY-1–3, INSIGHT-1–3, INTENT-1, SAFETY-1–3, SAFETY-6, UNCOL-1, INVEST-1/1a, INFRA-4a, INFRA-4b, INFRA-4c, SEC-6 | Enrichment, routine customisation, 3x-daily UX, notifications, clinical safety, pharmacist integration, investment case, pentest |
| P3 | SCHED-1d, SCHED-1e, SCHED-1f, INTENT-2, UNCOL-2, UNCOL-3 | Advanced routines, education, pharmacy-facing |
