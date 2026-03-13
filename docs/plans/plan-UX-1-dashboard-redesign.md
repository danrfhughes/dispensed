# Dashboard Redesign — NHS App Style with Dispensed Brand

## Context

The current dashboard is functional but visually flat — white cards on grey, no brand identity, no personalisation. The NHS App (screenshot provided) has a strong pattern: coloured header bar with patient greeting + NHS number, then content sections below with card-style navigation. We want to follow this layout using our brand colour `#5B8A7A` (teal/sage) instead of NHS Blue — per NHS Identity Guidelines, third-party apps must not use NHS colours.

Now that NHS-2 is complete, we have patient demographics (first_name, last_name, NHS number, GP, pharmacy) available on PatientProfile. The dashboard should use this data.

---

## Step 1: Branded header banner on dashboard

Replace the plain white time/date card with a branded hero section:

**`app/views/dashboard/index.html.erb`** — replace the top `bg-white` date banner with:
- Full-width `#5B8A7A` background, white text
- Greeting: "Good morning/afternoon/evening," (time-based)
- Patient name in large bold text (from `patient_profile.full_name`, fallback to email)
- NHS number below in smaller text (from `patient_profile.display_nhs_number`)
- Date shown as secondary info (white text, smaller, below name)
- **Drop the live clock** — cleaner NHS App style, users have phone clocks
- Remove the `<script>` block for `updateTime()` and the `#live-time` element
- Prescription expiry warnings stay, styled as white/semi-transparent text on teal

Time-of-day greeting logic (server-rendered, no JS needed):
- Before 12:00 → "Good morning,"
- 12:00–17:59 → "Good afternoon,"
- 18:00+ → "Good evening,"

---

## Step 2: Update layout nav bar to use brand colour

**`app/views/layouts/application.html.erb`**:
- Change nav background from `bg-white` to `#5B8A7A` background
- "Dispensed" logo text → white
- Nav links → white text, active state uses white with underline or bold
- Sign out link → white with opacity
- Email → white text
- Signed-out links → white

This mirrors the NHS App's coloured nav bar but in our brand teal.

---

## Step 3: Replace blue accent colours with brand teal across views

Globally swap blue accent colours to teal where they represent brand identity. Status colours (green=taken, orange=warning, red=error) stay unchanged.

**Replace pattern:** `text-blue-600` → `text-teal-700`, `bg-blue-600` → inline style `#5B8A7A`, `text-blue-500` → `text-teal-600`, `bg-blue-50` → `bg-teal-50`, `text-blue-700` → `text-teal-800`, `hover:text-blue-600` → `hover:text-teal-700`, `hover:bg-blue-700` → darker teal.

Since `#5B8A7A` doesn't map exactly to a Tailwind preset, use a mix of:
- Inline `style="background-color: #5B8A7A"` for the header/nav (same pattern as NHS Login button)
- Tailwind `teal-*` classes for accent text/links (teal-600 `#0d9488` is close enough for text accents, or use `emerald-700` `#047857` — but `teal-700` `#0f766e` is closest)

**Decision: use `[#5B8A7A]` arbitrary value syntax** for backgrounds where exact match matters (header, nav, buttons), and `teal-700`/`teal-600` for text links where exact hex doesn't matter.

Files to update:
- `app/views/layouts/application.html.erb` — nav
- `app/views/dashboard/index.html.erb` — header, links, today column highlight
- `app/views/devise/sessions/new.html.erb` — login button (keep NHS Login button as NHS Blue)
- `app/views/devise/shared/_links.html.erb` — link colours
- `app/views/medications/index.html.erb` — buttons, links
- Any other views with `text-blue-600` or `bg-blue-600`

---

## Step 4: Add GP practice and pharmacy info cards to dashboard

Below the weekly schedule grid, add an info section (like NHS App's "Your health" / "Services" sections):

- **Your GP** card — shows GP practice name and ODS code (from `patient_profile.gp_practice`)
- **Your pharmacy** card — shows nominated pharmacy name and ODS code (from `patient_profile.nominated_pharmacy`)
- Only shown if data exists (P5+ NHS Login users)

Styled as white rounded cards with a right-arrow chevron, matching NHS App's card link style.

**`app/views/dashboard/index.html.erb`** — add after the schedule grid
**`app/controllers/dashboard_controller.rb`** — expose `@patient_profile`

---

## File summary

| File | Action |
|------|--------|
| `app/views/dashboard/index.html.erb` | Rewrite top banner, add GP/pharmacy cards, swap blue→teal |
| `app/views/layouts/application.html.erb` | Teal nav bar, white text |
| `app/controllers/dashboard_controller.rb` | Expose `@patient_profile` |
| `app/views/devise/sessions/new.html.erb` | Swap form button blue→teal (NHS Login button stays NHS Blue) |
| `app/views/devise/registrations/new.html.erb` | Swap blue→teal if exists |
| `app/views/devise/shared/_links.html.erb` | Swap link blue→teal |
| `app/views/medications/show.html.erb` | Swap blue→teal links/buttons |
| `app/views/medications/_form.html.erb` | Swap blue→teal submit button |
| `app/views/schedules/_form.html.erb` | Swap blue→teal submit button |

---

## Verification

1. `bundle exec rspec` — all existing specs still pass (pure view/CSS change, no logic change)
2. Visit dashboard as Jane Smith (NHS Login mock) — see "Good evening, Jane Smith" in teal header with NHS number
3. Nav bar is teal with white text, active link highlighted
4. GP practice and pharmacy cards shown below schedule
5. Login page uses teal for form button, NHS Login button stays NHS Blue
6. Weekly schedule grid colours unchanged (green/orange/red status cells intact)
7. Mobile responsive — header stacks properly on narrow screens
