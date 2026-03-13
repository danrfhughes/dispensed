# NHS-2: Read Patient Demographics (PDS FHIR API) — Implementation Plan

## Context

After NHS Login (NHS-1, complete), the next step is auto-populating the patient's profile from NHS data. Currently PatientProfile only has `nhs_number`, `date_of_birth`, `fhir_id`, and `nhs_login_identity_level`. Users must manually enter name, address, phone, GP — the "setup complexity" research identifies as the largest drop-off point.

PDS FHIR returns the canonical Patient resource for any NHS number at P5+. We call PDS after NHS Login, get demographics, and pre-populate. Eliminates manual setup for NHS Login users.

**Also: replace `Pharmacy` with `Organisation`** — in FHIR/NHS, pharmacies, GP practices, trusts, and ICBs are all `Organization` resources differentiated by ODS role codes. Building a generic Organisation model now is future-proof for UNCOL and B2B backlog items.

**Mock PDS locally** (same pattern as NHS-1). Real API integration when sandpit credentials are configured.

---

## Step 1: Create Organisation model (replaces Pharmacy)

Create `organisations` table:
- `ods_code` (string, unique, not null) — ODS identifier
- `name` (string, not null)
- `organisation_type` (string) — "gp_practice", "pharmacy", "trust", "icb", etc.
- `address` (text, nullable)
- `phone` (string, nullable)
- `email` (string, nullable)
- `active` (boolean, default: true)

Create `app/models/organisation.rb`.

**File:** new migration, new model

---

## Step 2: Migration — Add demographic fields to PatientProfile, link to Organisation

**Add to `patient_profiles`:**
- `first_name` (string, nullable)
- `last_name` (string, nullable)
- `gender` (string, nullable)
- `address_line_1` (string, nullable)
- `address_line_2` (string, nullable)
- `city` (string, nullable)
- `postcode` (string, nullable)
- `phone` (string, nullable)
- `gp_organisation_id` (bigint FK → organisations, nullable)
- `nominated_pharmacy_id` (bigint FK → organisations, nullable)
- `demographics_fetched_at` (datetime, nullable)

**File:** new migration

---

## Step 3: Migrate Pharmacy data to Organisation, then drop Pharmacy

Migration to:
1. Copy any existing pharmacy records to `organisations` (type: "pharmacy", generate ODS code placeholder if missing)
2. Link patient_profiles to the new organisation records via `nominated_pharmacy_id`
3. Drop `pharmacies` table

Remove:
- `app/models/pharmacy.rb`
- `app/controllers/pharmacies_controller.rb`
- `app/views/pharmacies/` (all views)
- `spec/models/pharmacy_spec.rb`
- `spec/factories/pharmacies.rb`

Update:
- `app/models/patient_profile.rb` — replace `has_one :pharmacy` with `belongs_to :gp_practice` and `belongs_to :nominated_pharmacy`
- `config/routes.rb` — remove `resource :pharmacy`
- `app/views/layouts/application.html.erb` — remove pharmacy nav link

**Files:** migration, model updates, delete old files, route update

---

## Step 4: PDS FHIR client service

Create `app/services/nhs_api/pds_client.rb`:
- `fetch_patient(nhs_number, access_token:)` — `GET /Patient/{nhs_number}`
- Parses FHIR Patient resource → structured hash: `{ first_name:, last_name:, date_of_birth:, gender:, address:, phone:, gp_ods_code:, gp_name:, nominated_pharmacy_ods: }`
- Uses Faraday (already a dependency)
- Handles 401, 404, 500 errors gracefully

**File:** `app/services/nhs_api/pds_client.rb`

---

## Step 5: PDS mock for development/test

Create `app/services/nhs_api/pds_mock.rb`:
- Same interface as PdsClient
- Returns canned data for test NHS numbers (e.g. "9876543210" → Jane Smith)
- Swap via: `NhsApi::PdsClient.for_environment`

**File:** `app/services/nhs_api/pds_mock.rb`

---

## Step 6: Demographics sync service

Create `app/services/nhs_api/demographics_sync.rb`:
- Takes a `PatientProfile`
- Calls PDS (or mock) to fetch demographics
- Updates PatientProfile fields
- Finds or creates Organisation records for GP practice and nominated pharmacy (by ODS code)
- Sets `demographics_fetched_at`
- Skips if identity level < P5

**File:** `app/services/nhs_api/demographics_sync.rb`

---

## Step 7: Trigger sync after NHS Login

Update `app/controllers/users/omniauth_callbacks_controller.rb`:
- After successful P5+ login, call `NhsApi::DemographicsSync`
- Skip if `demographics_fetched_at` < 24h ago (don't re-fetch on every login)

**File:** `app/controllers/users/omniauth_callbacks_controller.rb`

---

## Step 8: Tests

- **Service specs:** PdsClient, PdsMock, DemographicsSync
- **Model spec:** Organisation (validations, associations)
- **Updated specs:** PatientProfile (new associations), OmniAuth callbacks (demographics populated)
- **Remove:** pharmacy_spec.rb, pharmacies factory
- **Add:** organisations factory

**Files:** new specs in `spec/services/nhs_api/`, `spec/models/organisation_spec.rb`, updated existing specs

---

## File summary

| File | Action |
|------|--------|
| `db/migrate/xxx_create_organisations.rb` | New — organisations table |
| `db/migrate/xxx_add_demographics_to_patient_profiles.rb` | New — name, address, phone, gender, GP/pharmacy FKs |
| `db/migrate/xxx_migrate_pharmacies_to_organisations.rb` | New — data migration + drop pharmacies |
| `app/models/organisation.rb` | New |
| `app/models/patient_profile.rb` | Update — new associations + remove pharmacy |
| `app/models/pharmacy.rb` | Delete |
| `app/controllers/pharmacies_controller.rb` | Delete |
| `app/views/pharmacies/` | Delete all |
| `app/services/nhs_api/pds_client.rb` | New |
| `app/services/nhs_api/pds_mock.rb` | New |
| `app/services/nhs_api/demographics_sync.rb` | New |
| `app/controllers/users/omniauth_callbacks_controller.rb` | Update — trigger sync |
| `config/routes.rb` | Update — remove pharmacy route |
| `app/views/layouts/application.html.erb` | Update — remove pharmacy nav |
| `spec/` | New service + model specs; delete pharmacy specs |

---

## Verification

1. `bundle exec rspec` — all specs pass (pharmacy specs removed, new specs green)
2. Click "Continue with NHS Login" in dev → dashboard shows patient name
3. Console: `PatientProfile.last` has first_name, last_name, address, GP, phone
4. Console: `Organisation.where(organisation_type: "pharmacy")` and `Organisation.where(organisation_type: "gp_practice")` both populated
5. `PatientProfile.last.gp_practice` and `.nominated_pharmacy` return Organisation records
6. Existing email/password login unaffected
7. P0 user login — no PDS call, no error
