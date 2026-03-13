# SCHED-2: Dose Regeneration on Schedule Edit

## Context

When a user edits a schedule (changes time, days, or routine anchor), existing doses for today onwards are stale — they still reflect the old schedule. Currently, editing a schedule has no effect on already-generated doses. This makes schedule editing effectively broken for the current day and any pre-generated future doses.

## Approach

**Add an `after_update` callback on Schedule** that regenerates doses from today onwards. The logic:

1. **Delete pending doses** for this schedule from today onwards (where `status: "pending"` and `scheduled_for >= beginning of today`)
2. **Preserve actioned doses** — any dose already taken/skipped/missed is untouched
3. **Regenerate** by calling the existing `GenerateDailyDosesJob` for today (which uses `find_or_create_by!` so it's idempotent)

This is simple, safe, and reuses the existing generation infrastructure.

## Files to modify

### 1. `app/models/schedule.rb`
- Add `after_update :regenerate_doses_from_today`
- New private method `regenerate_doses_from_today`:
  - Guard: only run if time_of_day, days_of_week, or routine_anchor changed (use `saved_change_to_*?` methods)
  - Delete: `doses.where(status: "pending").where("scheduled_for >= ?", Time.current.beginning_of_day).destroy_all`
  - Regenerate: `GenerateDailyDosesJob.new.perform(Date.current)`

### 2. `spec/models/schedule_spec.rb`
Add tests:
- Editing `time_of_day` regenerates today's pending dose with new time
- Editing `days_of_week` removes dose if schedule no longer active on today
- Editing `routine_anchor` regenerates dose with anchor's default time
- Taken/skipped doses are preserved (not deleted) when schedule is edited
- Editing `instructions` only does NOT trigger regeneration

### 3. `app/controllers/schedules_controller.rb`
No changes needed — the callback handles it transparently.

## Key design decisions

- **Only regenerate today**: The daily job handles future dates at midnight. No need to pre-generate beyond today.
- **Guard on structural changes**: Only trigger when `time_of_day`, `days_of_week`, or `routine_anchor` changed — not for `instructions` or `food_relation` (which don't affect dose timing).
- **Inline execution**: Run the job synchronously (same as `after_create`), not queued. The operation is fast (one day, one schedule) and the user needs to see the result immediately on redirect.

## Verification

1. Run `bundle exec rspec spec/models/schedule_spec.rb` — all new + existing tests pass
2. Run full suite `bundle exec rspec` — 165+ examples, 0 failures
3. Manual test in browser:
   - Create a medication with a "Before bed" schedule → dose appears on dashboard
   - Edit the schedule to "With breakfast" → dose time updates on dashboard
   - Mark a dose as taken, then edit the schedule → taken dose preserved, new pending dose regenerated
