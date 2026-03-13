# Dispensed — Project Instructions

## Dev environment
- Run with `bin/dev` (not `rails server`) — Tailwind needs the Procfile
- PostgreSQL everywhere (dev, test, production)
- RSpec + FactoryBot + Shoulda Matchers + Capybara (rack_test driver)

## Workflow
- **Commit per backlog item** — don't let work accumulate uncommitted across multiple features
- **Plan before implement** — when tasks are listed, add to backlog for discussion rather than implementing immediately. Only implement directly when the instruction is unambiguously "do this now"
- **Plans in docs/** — when creating implementation plans, save them to `docs/` in this project (e.g. `docs/INFRA-4-plan.md`), not just the internal `.claude/plans/` directory
- **Backlog is canonical** — `BACKLOG.md` is the source of truth for all work items. Update it when items are completed or new items are discovered

## Testing
- Run `bundle exec rspec` to verify — target: 0 failures
- System specs in `spec/system/` use `driven_by(:rack_test)` by default (no JS)
- Tag specs with `js: true` to use headless Chrome via Selenium (for JS-dependent tests)
- Example: `it "toggles the form", js: true do ... end`

## Deployment
- Render.com — app live at https://dispensed.onrender.com
- Puma single mode (`workers 0`) with Solid Queue plugin
- Pre-Deploy Command: `bundle exec rails db:migrate`
