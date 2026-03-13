# INFRA-4: Full BDD/Capybara Test Coverage

## Context
Dispensed has 172 passing specs (models, requests, services, jobs) but zero Capybara feature/system specs. No user-facing flow is tested through the browser stack. The backlog specifies comprehensive integration tests covering all happy paths and key error paths.

## Approach: System Specs with Capybara + rack_test

Use `spec/system/` (Rails 5.1+ convention) with `driven_by(:rack_test)` — no browser needed, fast, sufficient for form submissions and page content verification. Selenium only needed if testing JS interactions (can add later for the schedule form toggles).

## Setup

1. **Enable `infer_spec_type_from_file_location!`** in `rails_helper.rb` — so `spec/system/` files auto-get `:system` type
2. **Add Devise helpers for system specs** in `spec/support/devise.rb` — include `Devise::Test::IntegrationHelpers` for `:system` type
3. **Configure Capybara driver** — `driven_by(:rack_test)` as default (fast, no JS). Add `:selenium_chrome_headless` config for JS specs if needed later
4. **Create `spec/system/` directory**

## Spec Files (8 files, ~50-60 examples)

### 1. `spec/system/authentication_spec.rb`
- Sign up with email/password → lands on dashboard
- Sign in with email/password → lands on dashboard
- Sign out → redirected to sign-in page
- Invalid credentials → error message shown
- Unauthenticated user → redirected to sign-in

### 2. `spec/system/dashboard_spec.rb`
- Signed-in user sees dashboard with greeting
- Dashboard shows today's pending doses grouped by medication
- Empty state: no medications → appropriate message
- Mark dose as taken → status updates, redirects back
- Mark dose as skipped → status updates
- Reorder banner appears when medication needs reorder
- GP practice and pharmacy info cards display (when demographics present)

### 3. `spec/system/medications_spec.rb`
- Medications index lists active medications
- Create new medication via form → appears in list
- Validation errors shown on invalid create (blank name)
- Edit medication → changes persisted
- Archive medication → removed from active list
- Medication show page displays schedules section
- Cannot see other users' medications (isolation check)

### 4. `spec/system/schedules_spec.rb`
- Create schedule with specific time → dose generated
- Create schedule with routine anchor → shows routine label on dashboard
- Create schedule with food relation → shown in schedule details
- Validation error: no time and no anchor → error message
- Overlap conflict → error message shown
- Edit schedule time → redirects back to medication
- Archive schedule → removed from medication show
- Create specific-days schedule (e.g. Mon/Wed/Fri)

### 5. `spec/system/adherence_spec.rb`
- Adherence page shows per-medication breakdown
- Shows 7-day and 28-day stats
- Colour coding: good (green), warning (amber), poor (red)
- Empty state: no medications → appropriate message

### 6. `spec/system/doses_spec.rb`
- Take a dose from dashboard → taken_at recorded, shown as taken
- Skip a dose from dashboard → shown as skipped
- Cannot take/skip another user's dose

### 7. `spec/system/nhs_login_spec.rb`
- NHS Login button visible on sign-in page
- Successful NHS Login → user created, lands on dashboard
- Returning NHS Login user → signs in, lands on dashboard
- Failed NHS Login → error message on sign-in page

### 8. `spec/system/navigation_spec.rb`
- Nav bar links work: Dashboard, Medications, Adherence
- App name "Dispensed" in header
- Sign in / Sign up links shown when logged out

## Key Implementation Notes

- Use `login_as(user)` from Devise helpers (not `sign_in` which is for request specs — actually both work for system specs via IntegrationHelpers)
- Create test data via existing factories (User, Medication, Schedule, Dose, Organisation, PatientProfile)
- For NHS Login tests, use OmniAuth test mode (`OmniAuth.config.test_mode = true`) — already configured in the app
- `rack_test` driver doesn't execute JS, so the schedule form radio/checkbox toggle won't fire. Test the server-side behaviour (form submission with correct params). JS-dependent UI tests can be a follow-up with Selenium.

## Files to modify

| File | Change |
|------|--------|
| `spec/rails_helper.rb` | Uncomment `infer_spec_type_from_file_location!`, add `driven_by(:rack_test)` config |
| `spec/support/devise.rb` | Add IntegrationHelpers for `:system` type |
| `spec/system/*.rb` (8 new files) | All feature specs listed above |

## Cleanup

- Delete the 12 pending/empty view and helper spec stubs (they add noise and the system specs supersede them)

## Verification

1. `bundle exec rspec spec/system/` — all new specs green
2. `bundle exec rspec` — full suite still passes (existing 172 + new ~55)
3. Check coverage report (SimpleCov) for improvement

## Out of scope (backlogged)
- JS-dependent tests (schedule form toggles, Turbo interactions) → **INFRA-4a**
- Dose regeneration E2E through browser → **INFRA-4b**
- Timezone edge case specs → **INFRA-4c** (depends on SCHED-6)
