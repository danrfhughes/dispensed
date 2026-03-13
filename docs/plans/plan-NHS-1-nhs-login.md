# NHS-1: NHS Login (OmniAuth OIDC) — Approved Plan

*Approved: 2026-03-12 | Status: COMPLETE*

## Context

NHS Login is the foundation for all NHS App integration. Dispensed uses Devise with email/password only. NHS Login adds an alternative auth path so users can sign in with their NHS identity, giving us their NHS number and proofing level — unlocking NHS-2 (demographics) and eventually NHS-4 (medications).

## Approach

Devise OmniAuth with `omniauth_openid_connect` gem, plus custom `private_key_jwt` client assertion (NHS Login requires RS512-signed JWTs at the token endpoint). Mock environment for local dev; real sandpit when deployed.

## Key design decisions

- **Auth fields on User** (`provider`, `uid`) — Devise needs these for OmniAuth routing
- **Identity level on PatientProfile** (`nhs_login_identity_level`) — clinical identity concern, alongside `nhs_number` and `fhir_id`
- **Custom OmniAuth strategy** (`lib/omniauth/strategies/nhs_login.rb`) — extends OpenIDConnect to inject RS512-signed client assertion (rack-oauth2's built-in only does RS256)
- **NHS Login button** uses NHS Blue `#005eb8` (their branded component); app primary colour is distinct

## Files created/modified

| File | Action |
|------|--------|
| `Gemfile` | Added omniauth_openid_connect, omniauth-rails_csrf_protection, jwt |
| `db/migrate/20260312175110_add_oauth_to_users.rb` | provider, uid fields + unique index |
| `db/migrate/20260312175120_add_nhs_login_identity_level_to_patient_profiles.rb` | nhs_login_identity_level |
| `app/models/user.rb` | omniauthable, from_omniauth, password_required? |
| `app/services/nhs_login/client_assertion.rb` | RS512 JWT builder for private_key_jwt |
| `lib/omniauth/strategies/nhs_login.rb` | Custom strategy extending OpenIDConnect |
| `config/initializers/devise.rb` | OmniAuth provider config with strategy_class |
| `config/routes.rb` | devise_for with omniauth_callbacks controller |
| `app/controllers/users/omniauth_callbacks_controller.rb` | NHS Login callback handler |
| `app/views/devise/sessions/new.html.erb` | NHS Login button |
| `app/views/devise/shared/_links.html.erb` | Suppressed duplicate OmniAuth link |
| `config/environments/development.rb` | OmniAuth test_mode with mock auth hash |
| `spec/services/nhs_login/client_assertion_spec.rb` | 7 specs |
| `spec/requests/omniauth_callbacks_spec.rb` | 7 specs |
| `spec/models/user_spec.rb` | 5 new specs (from_omniauth, password_required?) |

## Test result

112 examples, 0 failures
