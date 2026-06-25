# ADS-B Receiver Portal Frontend Cleanup Plan

This plan covers a cleanup/refactor pass for the Angular application in `build/portal/frontend` on the `cleanup` branch. The goal is to improve maintainability, type safety, testability, and build hygiene without changing user-visible behavior or API contracts.

## Goals

- Keep the existing Angular standalone-component architecture recognizable.
- Avoid a large rewrite or visual redesign.
- Preserve routes, UI behavior, backend API paths, localStorage token semantics, map behavior, chart behavior, and admin workflows.
- Make each cleanup step small enough to test independently.
- Keep `npm run build` passing after each phase.
- Keep Karma tests passing once the local Chrome/Chromium prerequisite is available.

## Initial Baseline Snapshot

- Frontend source: about 12,866 lines across 51 TypeScript files under `src/app`.
- Templates: about 5,114 lines across 20 HTML files.
- Styles: about 1,705 lines across 21 SCSS files.
- Tests: about 4,617 lines across 24 spec files.
- Largest components:
  - `src/app/live/live.component.ts`: 1,291 lines.
  - `src/app/flights/flights.component.ts`: 1,149 lines.
  - `src/app/devices/devices.component.ts`: 942 lines.
  - `src/app/service/data.service.ts`: 537 lines.
  - `src/app/admin-blog/admin-blog.component.ts`: 534 lines.
  - `src/app/admin-live/admin-live.component.ts`: 483 lines.
  - `src/app/admin-flights/admin-flights.component.ts`: 438 lines.
- Tooling observations from local review:
  - `npm ci` initially fails because `package-lock.json` is not fully in sync with `package.json` / Angular 21 optional peer dependencies (`chokidar@5.0.0`, `readdirp@5.0.0`).
  - `npm install --package-lock-only --ignore-scripts --no-audit --no-fund` makes `npm ci` work locally.
  - `npm run build` passes after installing dependencies.
  - `npm test -- --watch=false --browsers=ChromeHeadless` builds the test bundle but cannot launch because no Chrome/Chromium binary is installed in this environment and `CHROME_BIN` is unset.
  - `npm audit --omit=dev --audit-level=moderate` reports production dependency advisories in Angular 21.2.x and `protocol-buffers-schema`; `npm audit fix` is available but should be done as a dedicated dependency-update phase.
- Main maintainability concerns:
  - `DataService` centralizes every backend API call and repeats token/header construction heavily.
  - Many API methods return `Observable<any>` and many components store `any`/`any[]`, despite strict TypeScript being enabled.
  - Very large components mix data loading, URL state, formatting, map/chart state, filtering, pagination, admin actions, and template state.
  - Several components use direct `localStorage` and repeated JWT decoding logic instead of a shared auth/session seam.
  - Several admin settings saves call `.subscribe()` without surfaced success/error behavior.
  - Test execution depends on an external browser binary that is not documented/configured here.
  - No lint script is currently configured.

## Non-Goals

- Do not redesign the UI.
- Do not change route paths.
- Do not change backend API endpoint paths or payload keys.
- Do not replace Angular, Karma/Jasmine, Chart.js, OpenLayers, Bootstrap, or RxJS.
- Do not convert the app to NgRx or another state-management framework.
- Do not introduce new runtime services.
- Do not do broad formatting-only churn.
- Do not remove working tests to make refactors easier.

## Progress Checklist

Use this checklist to track implementation across small commits. Mark an item complete only after the relevant targeted tests/builds and the full frontend verification gate pass.

Legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked / needs decision

### Setup and Tooling

- [x] Phase 0.1 — Sync `package-lock.json` so `npm ci` works without a pre-step.
- [x] Phase 0.2 — Add documented frontend setup/build/test commands.
- [x] Phase 0.3 — Decide and document the local browser prerequisite for Karma (`chromium`, `google-chrome`, or CI-provided `CHROME_BIN`).
- [x] Phase 0.4 — Add a conservative lint/typecheck script only if it can pass without broad code churn.
- [x] Phase 0.5 — Record baseline verification: `npm ci`, `npm run build`, and headless Karma once browser support is available.

### Shared Types and API Client Cleanup

- [x] Phase 1.1 — Add shared API/domain interfaces for common backend payloads currently represented as `any`.
- [x] Phase 1.2 — Add a small auth header/session helper to remove repeated `localStorage.getItem('access_token')` and header literals in `DataService`.
- [x] Phase 1.3 — Split `DataService` by domain or extract private helper methods in-place, whichever is lower risk after inspection.
- [x] Phase 1.4 — Replace manual query-string concatenation with `HttpParams` for routes that accept optional filters.
- [x] Phase 1.5 — Verify `data.service.spec.ts`, affected component specs, and full build/test gate.

### Auth and Session Handling

- [x] Phase 2.1 — Centralize JWT payload decoding used by `app.component.ts`, `auth.interceptor.ts`, `account.component.ts`, `flights.component.ts`, `blog.component.ts`, and `admin-scheduler.component.ts`.
- [x] Phase 2.2 — Add focused unit tests for malformed tokens, expired tokens, missing roles, and returnUrl handling.
- [x] Phase 2.3 — Keep localStorage key names and navigation behavior unchanged.
- [x] Phase 2.4 — Verify login/register/logout/app/interceptor tests and full build/test gate.

### Large Component Decomposition

- [x] Phase 3.1 — Extract pure formatting/filtering/pagination helpers from `flights.component.ts` without changing template behavior.
- [x] Phase 3.2 — Extract map/trail/photo/comment helper logic from `flights.component.ts` only where tests can characterize behavior.
- [x] Phase 3.3 — Extract live map configuration, aircraft classification legend, overlay-ring parsing, and resize helpers from `live.component.ts`.
- [x] Phase 3.4 — Extract device graph/KPI formatting helpers from `devices.component.ts`.
- [x] Phase 3.5 — Verify affected component specs after each slice and full build/test gate before committing.

### Admin Components and Settings Workflows

- [x] Phase 4.1 — Normalize repeated boolean setting save/load patterns in admin components.
- [x] Phase 4.2 — Add consistent error feedback for setting save failures where current UI silently subscribes.
- [x] Phase 4.3 — Extract reusable taxonomy/tag/category helpers from `admin-blog.component.ts`.
- [x] Phase 4.4 — Extract purge/ignore-on-purge helper logic from `admin-flights.component.ts`.
- [x] Phase 4.5 — Verify admin component specs and full build/test gate.

### Templates and Styles

- [x] Phase 5.1 — Review largest templates for repeated button/table/empty-state patterns.
- [x] Phase 5.2 — Extract small reusable presentational components only when duplication is clear and tests remain simple.
- [x] Phase 5.3 — Consolidate repeated SCSS values/classes conservatively; avoid visual redesign.
- [x] Phase 5.4 — Verify screenshots manually if browser tooling is available; otherwise rely on component tests and build.

### Test Coverage and Reliability

- [x] Phase 6.1 — Make headless test execution reproducible locally/CI.
- [x] Phase 6.2 — Add targeted tests for shared auth/session helpers.
- [ ] Phase 6.3 — Add tests around extracted pure helpers from flights/live/devices.
- [ ] Phase 6.4 — Add tests for admin save error paths where behavior is stable.
- [x] Phase 6.5 — Add a coverage baseline command/report and record current statement/branch/function/line coverage.
- [ ] Phase 6.6 — Identify coverage gaps in high-risk user flows and add behavior-focused tests until coverage is up to par.
- [ ] Phase 6.7 — Set pragmatic coverage thresholds only after the baseline is stable; avoid threshold gaming.
- [ ] Phase 6.8 — Avoid brittle DOM tests that only assert Angular implementation details.

### Dependency and Security Follow-up

- [ ] Phase 7.1 — Update the lockfile in a standalone commit and verify `npm ci` from a clean tree.
- [ ] Phase 7.2 — Run `npm audit --omit=dev --audit-level=moderate` and decide whether to apply `npm audit fix`.
- [ ] Phase 7.3 — If Angular packages are updated, run build, headless tests, and a quick UI smoke pass.
- [ ] Phase 7.4 — Keep dependency updates separate from refactors unless required to unblock tooling.

### Commit Tracking

Record each cleanup commit here as work proceeds:

| Status | Phase | Commit | Notes |
| --- | --- | --- | --- |
| [x] | Planning | `7e67a31` | Added frontend cleanup plan. |
| [x] | 0 | `2e1c3b8`, `67045de` | Lockfile synced; `npm ci`, `npm run build`, `npm run typecheck`, and headless Karma pass after installing Google Chrome. |
| [x] | 1 | `d791358`, `f04c879`, `12ca91d` | Added shared API response types, centralized DataService auth headers, extracted low-risk in-place URL/pagination helpers, converted public blog post query construction to HttpParams, and fixed brittle specs revealed by headless Karma. |
| [x] | 2 | `0500201` | Centralized JWT payload/session helpers, migrated existing decode callers, preserved token key/navigation behavior, and verified full headless Karma/build gate. |
| [x] | 3 | `bb35aa5`, `661e7fd`, `03e99c7`, `0bab12c`, `db5d16c`, `81fb12a` | Completed large component decomposition with flights display/track helpers, live display/overlay/settings helpers, and devices display/KPI helpers. |
| [x] | 4 | `148f7bb`, `4d647b0`, `89f7e9e`, `6d5d914`, `10142ff`, `9051f1a` | Completed admin/settings workflow cleanup with autosave feedback/helper consolidation, admin blog taxonomy helpers, admin live/feeders setting-save consolidation, and admin flights purge/ignore helpers. |
| [x] | 5 | `c518732`, `3261070`, `58c77d5` | Completed templates/styles cleanup with largest-template inventory, shared admin setting toggle presentational extraction, shared per-page select styling, and build/test/browser-smoke verification. |
| [ ] | 6 | TBD | Test reliability and coverage. |
| [ ] | 7 | TBD | Dependency/security follow-up. |

---

## Phase 0: Setup and Tooling

1. Sync the lockfile in a dedicated commit.
   - Run from `build/portal/frontend`:
     - `npm install --package-lock-only --ignore-scripts --no-audit --no-fund`
     - `npm ci`
   - Commit only `package-lock.json` if it changes.
   - Do not combine this with source refactors.

2. Add frontend testing documentation.
   - Create `build/portal/frontend/TESTING.md` only if the user wants checked-in docs.
   - Otherwise keep commands in this plan.
   - Include:
     - `npm ci`
     - `npm run build`
     - `npm test -- --watch=false --browsers=ChromeHeadless`
     - Chrome/Chromium prerequisite and `CHROME_BIN` note.

3. Establish local verification gate.
   - Required every source-changing phase:
     - `npm run build`
     - targeted component/service specs when browser support is present
     - full `npm test -- --watch=false --browsers=ChromeHeadless` when browser support is present
   - If Chrome is unavailable, report the blocker explicitly and run build plus any non-browser checks available.

4. Consider lint/typecheck scripts.
   - Current `npm run build` already performs Angular/TypeScript compilation.
   - Added `npm run typecheck` as a conservative development Angular build/typecheck alias.
   - Added `npm run test:headless` as the documented one-shot Karma command.
   - Add ESLint only as a later separate phase if it can be introduced with minimal mechanical churn.


Phase 0 live verification notes (2026-06-25):
- `npm install --package-lock-only --ignore-scripts --no-audit --no-fund` updated only `package-lock.json` for Angular 21 optional peer dependencies.
- `npm ci` passes from `build/portal/frontend`.
- `npm run build` passes.
- `npm run typecheck` passes; it is a conservative Angular development build/typecheck script and adds no new lint dependencies.
- Installed Google Chrome 149 locally in this environment; `npm run test:headless` now launches ChromeHeadless and passes.
- Local Karma prerequisite decision: install `chromium` or `google-chrome` and set `CHROME_BIN` when the binary is not discoverable by `karma-chrome-launcher`; CI should use an image/action that provides Chrome or exports `CHROME_BIN`.

Acceptance criteria:
- `npm ci` works from a clean tree.
- `npm run build` passes.
- Karma test prerequisite is documented or configured.
- Any new tooling is conservative and does not trigger broad unrelated rewrites.

## Phase 1: Shared Types and API Client Cleanup

1. Inventory backend payloads represented by `any`.
   - Start with `src/app/service/data.service.ts`.
   - Prioritize stable payloads already exercised by specs:
     - users
     - settings
     - blog posts/comments
     - ADS-B/UAT flights and positions
     - ACARS flights/messages
     - graph responses
     - live aircraft

2. Add shared interfaces in a low-risk location.
   - Candidate: `src/app/shared/api-types.ts` or domain-specific files under `src/app/shared/types/`.
   - Prefer domain-specific names over generic `ApiResponse` buckets.
   - Do not require every endpoint to be typed in one pass.

3. Remove repeated auth header construction.
   - Candidate helper in `DataService` first:
     - a private helper that returns the existing authorization header object for the current access token.
   - Later, consider moving token access to an `AuthSessionService` if Phase 2 confirms it is useful.
   - Keep the current bearer-token header semantics unchanged.

4. Replace manual query strings incrementally.
   - Example low-risk target:
     - `getBlogPosts(offset, limit, category, tag)` currently concatenates query strings manually.
   - Use `HttpParams` and keep generated request URLs semantically identical.

5. Verify.
   - Run `npm run build` after each slice.
   - Run `src/app/service/data.service.spec.ts` once headless test support is available.
   - Run full headless tests before committing.

Phase 1 live verification notes (2026-06-25):
- Added `src/app/shared/api-types.ts` with low-risk shared response interfaces.
- Centralized all `DataService` bearer-token header construction in a private `authHeaders()` helper; no public API paths or token storage keys changed.
- Converted `getBlogPosts(offset, limit, category, tag)` from manual query-string concatenation to `HttpParams` while preserving the same query keys.
- Phase 1.3 decision: keep `DataService` intact for now and extract private helpers in-place; splitting into domain services would create broader DI/import churn for little immediate payoff.
- Added `offsetLimitParams()`, `flightUrl()`, and `schedulerJobUrl()` helpers to reduce repeated URL/parameter construction without changing public methods.
- Installed Google Chrome 149 locally so Karma can launch `ChromeHeadless` in this environment.
- Fixed brittle frontend specs exposed by the first real headless run: completed missing service mocks, made repeated admin blog mock calls stable, and aligned pagination/control assertions with current templates/routes.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 280 SUCCESS`.

Acceptance criteria:
- `DataService` is smaller or has less duplication.
- Public request URLs/headers are unchanged.
- Types improve at stable API seams without forcing broad component rewrites.

## Phase 2: Auth and Session Handling

1. Extract JWT decode/session helpers.
   - Repeated logic appears in:
     - `src/app/app.component.ts`
     - `src/app/interceptors/auth.interceptor.ts`
     - `src/app/account/account.component.ts`
     - `src/app/flights/flights.component.ts`
     - `src/app/blog/blog.component.ts`
     - `src/app/admin-scheduler/admin-scheduler.component.ts`
   - Candidate helper/service:
     - `src/app/shared/auth-session.ts` for pure helpers, or
     - `src/app/service/auth-session.service.ts` if DI is needed.

2. Add tests before migration.
   - malformed JWT returns unauthenticated/expired
   - missing token returns unauthenticated
   - expired token returns expired
   - valid admin token returns admin role
   - returnUrl remains preserved on forced login redirect

3. Migrate one caller at a time.
   - Start with pure consumers, then interceptor.
   - Do not change localStorage keys.


Phase 2 live verification notes (2026-06-25):
- Added `src/app/shared/auth-session.ts` as the shared JWT/session helper seam.
- Added `src/app/shared/auth-session.spec.ts` covering missing, malformed, expired, valid admin, and missing-role token behavior.
- Migrated repeated JWT decode logic in `app.component.ts`, `auth.interceptor.ts`, `account.component.ts`, `flights.component.ts`, `blog.component.ts`, and `admin-scheduler.component.ts`.
- Preserved `access_token` / `refresh_token` storage keys and existing forced-login returnUrl behavior.
- Existing `login.component.spec.ts` still covers returnUrl navigation after successful login.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 283 SUCCESS`.

Acceptance criteria:
- Token/session behavior is centralized.
- Existing login/register/logout/app/interceptor specs pass.
- No route guard or navigation behavior changes.

## Phase 3: Large Component Decomposition

1. `flights.component.ts`.
   - Extract pure helpers first:
     - tab normalization
     - page parsing
     - display labels
     - aircraft type/icon formatting
     - comment sorting/threading if present
   - Keep stateful map/photo/API logic in the component until covered.

2. `live.component.ts`.
   - Extract pure helpers first:
     - overlay-ring JSON parsing
     - aircraft type/source labels
     - classification legend data
     - map style constants
   - Keep OpenLayers object lifecycle changes isolated and tested.

3. `devices.component.ts`.
   - Extract pure formatting helpers:
     - bytes/rates
     - graph periods
     - KPI calculations
     - receiver status labels
   - Avoid changing chart rendering behavior.

4. Verification.
   - Add pure helper specs where practical.
   - Run relevant component specs and `npm run build` after each slice.


Phase 3 live verification notes (2026-06-25):
- Phase 3.1 slice: added `src/app/flights/flight-display.helpers.ts` for pure flights display/pagination helpers.
- Added `src/app/flights/flight-display.helpers.spec.ts` covering page-number windows, count normalization, aircraft class inference, and aircraft display labels.
- Migrated `flights.component.ts` to use the extracted helper for page-number windows, count normalization, aircraft class inference, and labels while keeping stateful map/photo/API logic in the component.
- Updated the existing flights component spec to assert aircraft classification through the helper seam instead of the old private component method.
- Focused helper spec passes: `TOTAL: 4 SUCCESS`.
- Phase 3.2 slice: added `src/app/flights/flight-track.helpers.ts` for characterized track segmentation and render-coordinate interpolation helpers.
- Added `src/app/flights/flight-track.helpers.spec.ts` covering time-gap segmentation, empty inputs, non-mutating input order, sparse-coordinate interpolation, and single-position segments.
- Migrated `flights.component.ts` to use the track helper seam while keeping OpenLayers map/layer lifecycle, photo loading, and comment mutations in the component.
- Updated the existing flights component spec to assert track segmentation/interpolation through the helper seam instead of removed private component methods.
- Focused track helper spec passes: `TOTAL: 4 SUCCESS`.
- Focused flights component spec passes: `TOTAL: 26 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 291 SUCCESS`.
- Phase 3.3 first live slice: added `src/app/live/live-display.helpers.ts` for altitude/source colors, aircraft classification labels, source labels, flight-history link construction, and aircraft type legend data.
- Added `src/app/live/live-display.helpers.spec.ts` covering altitude color tiers, ADS-B/UAT source labels, category/callsign classification fallbacks, type/source labels, flight-history link generation, and legend ordering.
- Migrated `live.component.ts` to use the display helper seam while keeping SVG/icon generation and OpenLayers lifecycle in the component.
- Focused live display helper spec passes: `TOTAL: 6 SUCCESS`.
- Focused live component spec passes: `TOTAL: 21 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 297 SUCCESS`.
- Phase 3.3 second live slice: added `src/app/live/live-overlay.helpers.ts` for theoretical-range and HeyWhatsThat overlay-ring JSON parsing.
- Added `src/app/live/live-overlay.helpers.spec.ts` covering invalid JSON, lon/lat pair arrays, lon/lng/longitude object aliases, nested coordinate configs, and GeoJSON polygon features.
- Migrated `live.component.ts` to use the overlay helper seam while keeping OpenLayers overlay source/layer lifecycle in the component.
- Focused live overlay helper spec passes: `TOTAL: 5 SUCCESS`.
- Focused live component spec passes: `TOTAL: 21 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 302 SUCCESS`.
- Phase 3.3 third live slice: added `src/app/live/live-settings.helpers.ts` for live map defaults, bounded settings parsing, overlay JSON trimming, and flyout-width clamping.
- Added `src/app/live/live-settings.helpers.spec.ts` covering numeric bounds, invalid fallback values, boolean defaults, true-only flags, and viewport-aware flyout clamping.
- Migrated `live.component.ts` to use the settings helper seam while keeping setting fetch orchestration and resize event lifecycle in the component.
- Focused live settings helper spec passes: `TOTAL: 4 SUCCESS`.
- Focused live component spec passes: `TOTAL: 21 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 306 SUCCESS`.
- Phase 3.4 devices slice: added `src/app/devices/devices-display.helpers.ts` for device graph period constants, refresh interval bounds, byte/duration formatting, aircraft type labels, dataset-average KPI extraction, and range-unit conversion.
- Added `src/app/devices/devices-display.helpers.spec.ts` covering byte/duration formatting, refresh bounds, aircraft type labels, dataset averaging, and range conversions.
- Migrated `devices.component.ts` to use the devices helper seam while keeping graph chart config construction, data loading, tab state, brush state, and chart lifecycle in the component.
- RED verified first: the new helper spec initially failed because the helper module did not exist, then failed for missing exported KPI helpers before implementation; after implementation the same spec passed.
- Focused devices helper + component specs pass: `TOTAL: 33 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 312 SUCCESS`.

Acceptance criteria:
- Large components shrink through behavior-preserving extraction.
- Extracted helpers have focused tests.
- Templates continue to compile under strict templates.

## Phase 4: Admin Components and Settings Workflows

1. Identify repeated setting load/save code.
   - Admin components with obvious repetition:
     - `admin-acars.component.ts`
     - `admin-devices.component.ts`
     - `admin-feeders.component.ts`
     - `admin-graphs.component.ts`
     - `admin-live.component.ts`

2. Extract reusable helpers cautiously.
   - A small private helper per component may be lower risk than a cross-component abstraction.
   - Only create a shared settings service/helper after two or three components prove the same shape.

3. Add stable error feedback.
   - Several save methods call `.subscribe()` without error handling.
   - Add user-visible error messages only where the component already has an error-message pattern.
   - Avoid inventing a new global notification system.

Acceptance criteria:
- Repeated settings code is reduced.
- Failed save paths are testable and, where appropriate, visible to the user.
- Existing admin UI behavior remains unchanged on success.

Phase 4 live verification notes (2026-06-25):
- Phase 4.1/4.2 first admin devices slice: consolidated repeated `updateSetting(...).subscribe()` autosave methods in `admin-devices.component.ts` behind a private `saveSetting(...)` helper.
- Added success/error message state and template alerts for admin devices autosaves so failed saves are visible instead of silently swallowed.
- Added `admin-devices.component.spec.ts` coverage for successful autosave feedback and failed autosave feedback.
- RED verified first: the focused admin devices spec initially failed because `successMessage` and `errorMessage` did not exist on the component; after implementation the same spec passed.
- Focused admin devices spec passes: `TOTAL: 5 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 313 SUCCESS`.
- Phase 4.1/4.2 second admin autosave slice: consolidated silent nav setting saves in `admin-acars.component.ts` and `admin-links.component.ts` behind local `saveSetting(...)` helpers.
- Added focused admin ACARS and admin Links specs for successful nav autosave feedback and failed nav autosave feedback.
- RED verified first: the focused specs failed because nav autosaves did not set success/error state and unhandled save errors escaped the subscription; after implementation the same specs passed.
- Focused admin ACARS + Links specs pass: `TOTAL: 14 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 316 SUCCESS`.
- Phase 4.1/4.2 third admin autosave slice: consolidated silent setting saves in `admin-flights.component.ts` and `admin-blog.component.ts` behind local `saveSetting(...)` helpers.
- Added focused admin Flights and Blog specs for successful settings autosave feedback and failed settings autosave feedback.
- Verified no remaining admin `updateSetting(...).subscribe();` silent autosave calls remain; remaining admin `updateSetting` subscriptions have explicit success/error handlers or are batched `forkJoin` saves with handlers.
- RED verified first: the focused specs failed because settings autosaves did not set success/error state and unhandled save errors escaped the subscription; after implementation the same specs passed.
- Focused admin Flights + Blog specs pass: `TOTAL: 47 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 319 SUCCESS`.
- Phase 4.3 admin blog taxonomy slice: added `src/app/admin-blog/admin-blog.helpers.ts` for pure tag/category normalization, deduplication, and catalog aggregation helpers.
- Added `admin-blog.helpers.spec.ts` covering trimmed tag extraction, case-insensitive tag deduplication, tag/category catalog counts, Uncategorized fallback, and custom category resolution.
- Migrated `admin-blog.component.ts` to call the helper seam while keeping API orchestration, prompts/confirms, bulk update subscriptions, and component state in the component.
- RED verified first: the new helper spec failed because the helper module did not exist yet; after implementation the same spec passed.
- Focused admin Blog helper + component specs pass: `TOTAL: 34 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 324 SUCCESS`.
- Phase 4.1 final settings-normalization slice: consolidated repeated boolean autosave handlers in `admin-live.component.ts` and `admin-feeders.component.ts` behind local `saveSetting(...)` helpers.
- Verified remaining admin setting saves are either routed through local `saveSetting(...)` helpers, explicit numeric/string helpers, explicit order/custom-preset handlers, or `forkJoin` batch saves with success/error handlers.
- Focused admin Live + Feeders component specs pass before and after refactor: `TOTAL: 19 SUCCESS`.
- `npm run typecheck` passes.
- `npm run build` passes.
- `npm run test:headless` passes: `TOTAL: 324 SUCCESS`.
- Phase 4.4 admin flights purge/ignore slice: added `src/app/admin-flights/admin-flights.helpers.ts` for purge completion messages, ignored-flight range/pagination helpers, offset normalization, ignore-toggle event extraction, and purge preference error messages.
- Added `admin-flights.helpers.spec.ts` covering purge message formatting, empty/bounded ignored-flight ranges, pagination bounds, post-load offset normalization, ignore-toggle extraction, and source-specific preference errors.
- Migrated `admin-flights.component.ts` to use the helper seam while keeping purge subscriptions, reload orchestration, and saving state in the component.
- RED verified first: the new helper spec failed because the helper module did not exist yet; after implementation the same spec passed.
- Focused admin Flights helper + component specs pass: `TOTAL: 24 SUCCESS`.
- Phase 4.5 final admin verification gate passed: `npm run typecheck`, `npm run build`, and full `npm run test:headless` with `TOTAL: 330 SUCCESS`.

## Phase 5: Templates and Styles

1. Review largest templates.
   - Focus on repeated table states, pagination controls, action button clusters, and empty/loading/error states.

2. Extract only obvious presentational duplication.
   - Candidate shared components should be dumb/presentational.
   - Avoid coupling domain state into shared UI components.

3. Keep style changes conservative.
   - Prefer variable/class consolidation.
   - Do not redesign layout, spacing, colors, map controls, or charts in this cleanup pass.

Acceptance criteria:
- Template duplication is reduced only where clear.
- Build and strict template checks pass.
- No visual redesign is introduced.

Phase 5 live verification notes (2026-06-25):
- Phase 5.1 template inventory reviewed the largest component templates by line count:
  - `devices.component.html` — 984 lines; heavy card/table/KPI/chart repetition. Best first candidate is presentational extraction only if component tests stay simple.
  - `flights.component.html` — 839 lines; large map flyout/comments/detail template. Avoid broad extraction because it is tightly coupled to map/flyout state.
  - `admin-flights.component.html` — 463 lines; repeated pagination, alert, purge-card, and form-switch patterns remain candidate cleanup areas.
  - `admin-blog.component.html` — 416 lines; repeated alert/pagination/form-switch patterns but less urgent after Phase 4 helper extraction.
  - `admin-live.component.html` — 306 lines and `admin-devices.component.html` — 205 lines; repeated settings cards/form-switch rows are the clearest candidates for conservative presentational cleanup.
- Pattern counts across the largest templates showed repeated `card`, `form-check`, `alert`, table, pagination, and spinner structures; no style changes were made in the inventory slice.
- Phase 5.2 should start with one small presentational component or template-only cleanup where duplication is obvious and covered by existing component specs; avoid redesigning layout, spacing, colors, map controls, or charts.
- Phase 5.2 first presentational extraction added `src/app/shared/admin-setting-toggle/admin-setting-toggle.component.ts` for repeated admin list-group form-switch rows.
- Added `admin-setting-toggle.component.spec.ts` covering title/description/state label rendering and `checkedChange` emission.
- Migrated repeated toggle rows in `admin-devices.component.html` to the shared presentational component while keeping save handlers and settings state in `admin-devices.component.ts`.
- RED verified first: the new component spec failed because the component module did not exist yet; after implementation the same spec passed.
- Focused shared toggle + admin Devices specs pass: `TOTAL: 7 SUCCESS`.
- Full Phase 5.2 gate passed: `npm run typecheck`, `npm run build`, and full `npm run test:headless` with `TOTAL: 332 SUCCESS`.
- Phase 5.3 consolidated duplicate per-page select sizing into the global `.per-page-select` utility in `src/styles.scss`.
- Migrated `Flights`, `ACARS`, `Admin Users`, and `Admin Blog` templates from page-specific per-page select classes to `.per-page-select`; removed duplicated 8.5rem width rules from component SCSS.
- Phase 5.4 visual smoke used the dev server and browser screenshots for public `Flights` and `ACARS` pages; the shared select width/alignment rendered correctly with no obvious visual breakage. Admin Blog/Admin Users are auth-gated, so verification for those stayed on template compile/build/full Karma coverage.
- Final Phase 5 gate passed: `npm run typecheck`, `npm run build`, and full `npm run test:headless` with `TOTAL: 332 SUCCESS`.

## Phase 6: Test Reliability and Coverage

1. Make headless Karma reproducible.
   - Preferred local fix: install Chromium and set `CHROME_BIN` if needed.
   - Alternative CI fix: use a browser image/action that provides Chrome.

2. Add tests around extracted pure helpers.
   - Auth/session helpers.
   - Flights/live/devices formatting helpers.
   - Admin settings save error handling.

3. Establish a real coverage baseline.
   - Add or document a repeatable coverage command, preferably `ng test --watch=false --browsers=ChromeHeadless --code-coverage` or an npm script wrapping it.
   - Record current statement, branch, function, and line coverage in this plan.
   - Include coverage artifact location, such as `coverage/`, if generated locally.

4. Bring coverage up to par with behavior-focused tests.
   - Review the coverage report for high-risk low-coverage areas before chasing percentages.
   - Prioritize user-facing flows and refactor-sensitive seams:
     - auth/session expiry and role handling
     - login/register/logout returnUrl and error paths
     - DataService request URL/params/header helpers
     - flights/live/devices pure helpers and display decisions
     - admin save/error paths
     - blog/comment permission and mutation flows
   - Add tests for meaningful behavior gaps, not incidental implementation details.

5. Set pragmatic thresholds after the baseline stabilizes.
   - Do not invent thresholds before measuring the current suite.
   - Prefer thresholds that prevent regressions while leaving room for staged improvement.
   - If thresholds are added, verify they pass locally and in CI.

6. Avoid brittle tests.
   - Prefer component behavior and pure helper inputs/outputs.
   - Avoid asserting private Angular implementation details unless no public seam exists.

Acceptance criteria:
- `npm test -- --watch=false --browsers=ChromeHeadless` runs in the intended environment.
- A repeatable coverage command exists and its baseline is recorded.
- Coverage gaps in high-risk flows are identified and either covered or tracked with explicit follow-up notes.
- Any coverage thresholds are evidence-based and pass without gaming tests.
- New tests protect behavior introduced or preserved by refactors.

Phase 6 live verification notes (2026-06-25):
- Phase 6.1 reproducibility check: existing `npm run test:headless` script runs Karma with `--watch=false --browsers=ChromeHeadless`; verified full suite passes with `TOTAL: 332 SUCCESS`.
- Phase 6.2 auth/session check: existing `src/app/shared/auth-session.spec.ts` covers missing, malformed, expired, valid user-id/role, admin, missing-role, and missing-expiry cases; focused auth-session spec passes with `TOTAL: 3 SUCCESS`.
- Phase 6.5 RED verified first: `npm run test:coverage` failed because the script did not exist yet; added the script to `package.json` and reran it successfully.
- Coverage command: `npm run test:coverage` (`ng test --watch=false --browsers=ChromeHeadless --code-coverage`).
- Coverage artifact location: `build/portal/frontend/coverage/frontend/` (ignored by `.gitignore`).
- Baseline from `npm run test:coverage`: Statements 69.72% (2734/3921), Branches 51.14% (757/1480), Functions 61.04% (699/1145), Lines 71.77% (2568/3578).
- Verification after script addition: `npm run typecheck`, `npm run build`, and `npm run test:headless` all pass; `npm run test:headless` reports `TOTAL: 332 SUCCESS`.

## Phase 7: Dependency and Security Follow-up

1. Keep dependency updates separate.
   - First make lockfile reproducible.
   - Then assess `npm audit --omit=dev` output.

2. Apply minimal safe updates.
   - Prefer patch/minor updates that keep Angular major version unchanged.
   - Run build/tests after updates.

3. Do not mix dependency changes with component refactors.

Acceptance criteria:
- Production audit issues are either fixed or documented with a clear reason for deferral.
- `npm ci`, `npm run build`, and headless tests pass after dependency changes.
