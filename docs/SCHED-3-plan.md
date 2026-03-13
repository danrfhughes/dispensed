# SCHED-3: Twice-Daily and Complex Frequency Support

*Created: 2026-03-13*

## Problem

Many common medications (metformin, antibiotics, blood pressure meds) require twice-daily dosing. The current system blocks creating a second schedule on the same medication due to the `no_overlapping_schedules` validator. Users must work around this limitation, which is a P0 gap — the core loop doesn't support a fundamental prescribing pattern.

## Research summary

Full research in `Research/SCHED-3 Complex Scheduling Approaches Research.pdf`. Key points:

- Adherence drops from ~79% (once daily) to ~51% (four times daily)
- UMS (Universal Medication Schedule) uses four slots: Morning/Noon/Evening/Bedtime
- Research recommends **slot-based with routine anchors** as default (Morning + Evening for twice-daily)
- Dashboard already groups by time — no display changes needed
- GenerateDailyDosesJob already creates one dose per schedule — two schedules = two doses automatically

## Design decisions

1. **Two Schedule records, not one record with multiple times.** Keeps the data model simple — each Schedule has one time, one anchor. The job and dashboard already handle this correctly.
2. **Default to breakfast + bedtime anchors** for twice-daily (research-backed). Allow override to custom times or other anchor pairs.
3. **One form submit creates two records** — controller handles the split in a transaction.
4. **No forced pairing** — once created, each schedule is independent. Edit/delete one without affecting the other.
5. **Three-times-daily and four-times-daily** — support via the same mechanism (user adds schedules individually). No special UX for these in SCHED-3; just remove the blocker.
6. **Conflict detection deferred to SCHED-4** — SCHED-3 enables the creation; SCHED-4 adds guardrails.

## Implementation steps

### Step 1: Relax the overlap validator

**File:** `app/models/schedule.rb`

Current `no_overlapping_schedules` blocks ANY second active schedule on the same medication. Change to: only block if two schedules would generate doses at the **same time on the same day**.

New logic:
- Two schedules with **different `routine_anchor` values** — allowed (e.g. breakfast + bedtime)
- Two schedules with **different `time_of_day` values** (>= 2 hour gap) and no anchor — allowed
- Two schedules with the **same anchor or same time** on overlapping days — blocked
- A "daily" schedule no longer blocks all other schedules — only those at the same time/anchor

### Step 2: Add "Twice daily" frequency option to the form

**File:** `app/views/schedules/_form.html.erb`

Add a third frequency radio: "Twice daily (morning + evening)" between Daily and Specific days. When selected:
- Show two anchor picker sections (morning anchor + evening anchor)
- Default: breakfast (08:00) + bedtime (22:00)
- Each anchor independently selectable from the full anchor list
- Food relation applies per-anchor (show two food relation sections)
- Hidden field `frequency_type=twice_daily` so controller knows to split

### Step 3: Controller creates two Schedule records

**File:** `app/controllers/schedules_controller.rb`

In `create`, check for `frequency_type=twice_daily`:
- If twice_daily: build two Schedule records from the submitted params, wrap in a transaction
- Both share: medication, days_of_week, instructions
- Each gets its own: routine_anchor, food_relation, time_of_day
- If either fails validation, roll back both and re-render form with errors
- If single: existing behaviour unchanged

New permitted params: `frequency_type`, `morning_anchor`, `morning_food_relation`, `morning_time_of_day`, `evening_anchor`, `evening_food_relation`, `evening_time_of_day`

### Step 4: Update medication show page

**File:** `app/views/medications/show.html.erb`

Minor: add routine label to schedule display (currently only shows time). Show e.g. "8:00 AM · With breakfast" instead of just "8:00 AM".

### Step 5: Tests

**File:** `spec/models/schedule_spec.rb`

New contexts under `no_overlapping_schedules`:
- Allows two schedules with different routine anchors on same medication
- Allows two schedules with different times (no anchors) on same medication
- Still blocks two schedules with same anchor on same medication
- Still blocks two schedules with same time on same medication

**File:** `spec/requests/schedules_spec.rb` (or equivalent)

- POST with `frequency_type=twice_daily` creates two Schedule records
- Both schedules generate doses correctly
- Transaction rollback if one schedule is invalid
- Editing one twice-daily schedule doesn't affect the other
- Deleting one leaves the other active

## Not in scope

- SCHED-4 (conflict detection / warnings)
- Three-times-daily convenience UX (users add third schedule manually)
- SCHED-1b/1c (custom windows, weekend overrides)

## Files changed

| File | Change |
|------|--------|
| `app/models/schedule.rb` | Relax `no_overlapping_schedules` validator |
| `app/views/schedules/_form.html.erb` | Add twice-daily frequency option + dual anchor UI |
| `app/controllers/schedules_controller.rb` | Handle `frequency_type=twice_daily` in create |
| `app/views/medications/show.html.erb` | Show routine label on schedule cards |
| `spec/models/schedule_spec.rb` | New overlap validation specs |
| `spec/requests/schedules_spec.rb` | New twice-daily creation specs |
| `spec/factories/schedules.rb` | Add `:twice_daily` trait if useful |
