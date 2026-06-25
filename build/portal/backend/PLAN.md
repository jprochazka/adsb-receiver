# ADS-B Receiver Portal Backend Cleanup Plan

This plan covers a cleanup/refactor pass for the Flask application in `build/portal/backend` on the `cleanup` branch. The goal is to improve readability, maintainability, and testability without changing external API behavior.

## Goals

- Keep the existing Flask/Flask-RESTX architecture recognizable.
- Avoid a large rewrite.
- Preserve route behavior, response shapes, auth semantics, migrations, and scheduler behavior.
- Make each cleanup step small enough to test independently.
- Keep the test suite passing after each phase.

## Initial Baseline Snapshot

- Backend source: about 6,947 lines across 21 Python files.
- Tests: about 6,712 lines across 20 test files.
- Initial test result from local review environment: `452 passed`; latest completed cleanup verification: `475 passed`; current coverage snapshot: 73% branch coverage from `coverage run -m pytest -q && coverage report -m` using `pyproject.toml` coverage config.
- Main readability concerns:
  - `backend/__init__.py` does too much.
  - `backend/models.py` contains all model classes in one file.
  - Large route modules mix API docs, schemas, helper logic, and handlers; Swagger coverage is also weaker on multiplexed `add_resource()` controllers.
  - `dump1090` and `dump978` route/job logic has duplication.
  - Background job code is procedural and side-effect heavy.
  - `requirements.txt` is UTF-16LE instead of normal UTF-8.
  - Several modules have unused imports and broad `except Exception` handling.

## Non-Goals

- Do not redesign the API.
- Do not change endpoint paths.
- Do not change response schemas except where tests prove compatibility.
- Do not replace Flask-RESTX, SQLAlchemy, APScheduler, or Marshmallow.
- Do not change database table names or migration history unless absolutely required.
- Do not introduce new runtime services.


## Progress Checklist

Use this checklist to track implementation across small commits. Mark an item complete only after the relevant targeted tests and the full backend test suite pass.

Legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked / needs decision

### Setup and Tooling

- [x] Phase 0.1 — Convert `requirements.txt` from UTF-16LE to UTF-8 without changing package pins.
- [x] Phase 0.2 — Verify `python -m pip install -r requirements.txt` works directly.
- [x] Phase 0.3 — Add documented local setup/test commands.
- [x] Phase 0.4 — Add conservative Ruff configuration to `pyproject.toml`.
- [x] Phase 0.5 — Remove only mechanical lint findings such as unused imports.
- [x] Phase 0.6 — Run baseline verification: `python -m pytest -q`, `python -m compileall backend tests`, and `ruff check .` if Ruff is added.

### App Factory and Configuration

- [x] Phase 1.1 — Split `create_app()` setup into focused helper functions inside `backend/__init__.py`.
- [x] Phase 1.2 — Verify route registration and scheduler API protection still work.
- [x] Phase 1.3 — Run targeted app factory/database tests and full pytest suite.
- [x] Phase 2.1 — Add centralized config loader module.
- [x] Phase 2.2 — Replace direct `open("config.yml")` reads in app setup.
- [x] Phase 2.3 — Replace direct `open("config.yml")` reads in graphs and RRD jobs.
- [x] Phase 2.4 — Verify app/tests work from expected working directories.

### Route Cleanup

- [x] Phase 3.1 — Add shared request parsing helpers for pagination, booleans, and search terms.
- [x] Phase 3.2 — Adopt shared helpers in low-risk routes first.
- [x] Phase 3.3 — Run affected route tests and full pytest suite.
- [x] Phase 4.1 — Simplify `routes/users.py` with small private helpers.
- [x] Phase 4.2 — Verify `tests/test_routes_users.py` and full pytest suite.
- [x] Phase 5.1 — Simplify `routes/blog.py` post/comment helpers.
- [x] Phase 5.2 — Verify `tests/test_routes_blog.py` and full pytest suite.
- [x] Phase 6.1 — Extract common ADS-B/UAT route helpers where behavior is truly shared.
- [x] Phase 6.2 — Simplify `routes/dump1090.py` using shared helpers.
- [x] Phase 6.3 — Simplify `routes/dump978.py` using shared helpers.
- [x] Phase 6.4 — Verify dump1090/dump978 targeted tests and full pytest suite.
- [x] Phase 7.1 — Simplify `routes/live.py` internals without changing response shape.
- [x] Phase 7.2 — Simplify `routes/graphs.py` internals without changing metric behavior.
- [x] Phase 7.3 — Verify live/graphs targeted tests and full pytest suite.

### Jobs, Models, and Final Cleanup

- [x] Phase 8.1 — Replace debug `print()` usage in jobs with logging where appropriate.
- [x] Phase 8.2 — Extract repeated dump1090/dump978 collection helpers only where safe.
- [x] Phase 8.3 — Reduce long RRD writer methods with metric/helper extraction.
- [x] Phase 8.4 — Verify job targeted tests and full pytest suite.
- [x] Phase 9.1 — Decide whether to keep `models.py` monolithic or organize/split it.
- [x] Phase 9.2 — Kept `models.py` monolithic; reduced serialization duplication while preserving imports and avoiding migration noise.
- [x] Phase 9.3 — Verify model tests and full pytest suite.
- [x] Phase 10.1 — Tighten broad exception handling where expected exception types are clear.
- [x] Phase 10.2 — Run final lint, compileall, and full pytest suite.
- [x] Phase 10.3 — Update this checklist with completed items and any deferred work.


### Swagger/API Documentation Follow-up

- [x] Phase 11.1 — Add Swagger coverage tests against `/api/swagger.json` for ADS-B, UAT, and ACARS endpoints.
- [x] Phase 11.2 — Split or otherwise document multiplexed `add_resource()` controllers so generated summaries, query parameters, response models, and error responses are accurate per path.
- [x] Phase 11.3 — Add missing query/path parameter docs for flight lists, search, positions, purge, and ACARS list/message endpoints.
- [x] Phase 11.4 — Attach existing RESTX response models to read/count/database endpoints where models already exist.
- [x] Phase 11.5 — Adjust stale or misleading wording only where it affects generated API docs; remove low-value boilerplate comments only when touching the file for documentation work.
- [x] Phase 11.6 — Verify `/api/swagger.json`, targeted route tests, Ruff, compileall, and full pytest suite.


### Test Coverage Follow-up

- [x] Phase 12.1 — Add a committed coverage command/config so coverage can be reproduced consistently without relying on local-only tooling.
- [ ] Phase 12.2 — Add focused tests for RRD data collection helpers and writer behavior; this is the largest coverage gap.
- [ ] Phase 12.3 — Add dump978 job tests that mirror dump1090 ingestion coverage for aircraft/flight/position creation and invalid feed paths.
- [ ] Phase 12.4 — Add notification route tests for recent notification summaries, duplicate handling, validation, and delete/list error paths.
- [ ] Phase 12.5 — Add auth decorator/helper tests for missing users, locked users, invalid roles, and admin/user authorization boundaries.
- [ ] Phase 12.6 — Add route error-path coverage for ACARS, devices, graphs, links, settings, users, and ADS-B/UAT comments only where the behavior is stable and useful.
- [ ] Phase 12.7 — Re-run coverage and full verification; record before/after coverage and avoid chasing line coverage with brittle implementation-detail tests.

### Commit Tracking

Record each cleanup commit here as work proceeds:

| Status | Phase | Commit | Notes |
| --- | --- | --- | --- |
| [x] | Planning | `0d712ad` | Added initial `PLAN.md` on `cleanup`. |
| [x] | 0 | `7d34682`, `ba0e6ab`, `0bbbf6f` | Tooling baseline complete. |
| [x] | 0.2-0.3 | `ba0e6ab` | Requirements install verified; backend testing guide added. |
| [x] | 0.4 | `0bbbf6f` | Added conservative Ruff configuration. |
| [x] | 0.5-0.6 | `0bbbf6f` | Removed mechanical unused imports; `ruff check .`, `compileall`, and `pytest` pass. |
| [x] | 1 | `0c2358e` | App factory split into focused setup helpers; targeted and full tests pass. |
| [x] | 2 | `57076e5` | Centralized config loader added; direct config.yml reads migrated; targeted and full tests pass. |
| [x] | 3 | `38253f1` | Shared route query parsing helpers added and adopted in users, blog, ADS-B, and UAT routes; targeted and full tests pass. |
| [x] | 4 | `6f17c92` | Users route simplified with private helpers; targeted and full tests pass. |
| [x] | 5 | `034e6fa` | Blog route simplified with post/comment helper extraction; targeted and full tests pass. |
| [x] | 6 | `21f651a` | Shared ADS-B/UAT route helper module added; dump1090/dump978 use shared helpers; targeted and full tests pass. |
| [x] | 7 | `4cd507b` | Live and graphs route internals simplified; targeted and full tests pass. |
| [x] | 8 | `dc4ae54` | Job print logging replaced; shared ADS-B/UAT ingest helpers and RRD writer helpers extracted; targeted and full tests pass. |
| [x] | 9 | `7f8afbf` | Kept models module monolithic; shared serialization helpers added; model and full tests pass. |
| [x] | 10 | `d6d890b` | Final exception-handling cleanup; targeted and full verification pass. Deferred broad DB exception narrowing where tests still model generic failures. |
| [x] | 11 | `b24a9bd` | Swagger/API documentation follow-up complete. Added generated spec tests, documented multiplexed ADS-B/UAT/ACARS endpoints, attached response models, and fixed targeted generated-doc wording. |
| [~] | 12 | `1458f25` | Test coverage follow-up. Current reproducible branch coverage snapshot is 73%; Phase 12.1 complete; prioritize RRD jobs, dump978 ingestion jobs, notification routes, auth boundaries, and stable route error paths. |

---

## Phase 0: Tooling and Safety Net

1. Convert `requirements.txt` from UTF-16LE to UTF-8.
   - Keep package pins unchanged.
   - Verify `python -m pip install -r requirements.txt` works directly.

2. Add lightweight lint tooling.
   - Add Ruff configuration to `pyproject.toml`.
   - Start with conservative rules: unused imports, undefined names, basic formatting hazards.
   - Avoid enabling aggressive style rules at first.

3. Document the verified local test commands.
   - Example:
     - `python3 -m venv .venv`
     - `. .venv/bin/activate`
     - `python -m pip install -U pip setuptools wheel`
     - `python -m pip install -r requirements.txt`
     - `python -m pytest -q`

4. Run and record baseline checks.
   - `python -m pytest -q`
   - `python -m compileall backend tests`
   - `ruff check .` once Ruff is added.

Acceptance criteria:
- Requirements install from the repository file without temporary conversion.
- Existing tests still pass.
- Any lint fixes are mechanical only.

## Phase 1: Clean App Factory Wiring

Target file: `backend/__init__.py`

1. Split `create_app()` into focused setup helpers:
   - `configure_json(app)`
   - `configure_cors(app)`
   - `configure_database(app)`
   - `configure_jwt(app)`
   - `register_api_namespaces(api)`
   - `register_blueprints(app)` if blueprints are still needed
   - `configure_scheduler(app)`
   - `init_extensions(app)`

2. Keep `create_app(test_config=None)` as the public entry point.

3. Avoid changing initialization order unless tests require it.

4. Review whether both RESTX namespace registration and Flask blueprint registration are necessary.
   - If blueprints do not register any independent routes, remove redundant blueprint registration only after tests confirm no route loss.

Acceptance criteria:
- `create_app()` becomes mostly orchestration.
- No route paths change.
- Scheduler API protection still works.
- Test suite passes.

## Phase 2: Centralize Configuration Loading

Current issue: multiple modules read `config.yml` with relative paths.

1. Add a config helper module, for example `backend/config.py` or `backend/config_loader.py`.

2. Provide helpers such as:
   - `load_portal_config()`
   - `get_database_config()`
   - `get_security_config()`
   - `get_graphs_config()`
   - `get_rrd_writer_config()`

3. Resolve `config.yml` relative to a known backend root instead of the current process working directory.

4. Update callers:
   - `backend/__init__.py`
   - `backend/routes/graphs.py`
   - `backend/jobs/rrd_data_collection.py`
   - Any other direct `open("config.yml")` use.

Acceptance criteria:
- App can be started from the backend directory as before.
- Tests can construct apps with explicit `test_config` without requiring real config files.
- Tests pass.

## Phase 3: Extract Shared Route Helpers

Current issue: route modules duplicate pagination, filtering, serialization, and comment handling.

1. Add `backend/routes/common.py` or `backend/services/pagination.py` for common request parsing:
   - Offset/limit validation.
   - Boolean query parsing.
   - Common search query normalization.

2. Add service/helper modules for repeated ADS-B/UAT behavior:
   - `backend/services/flights.py`
   - or domain-specific modules under `backend/services/adsb.py` and `backend/services/uat.py`.

3. Start with low-risk extractions:
   - Pagination parsing.
   - `ignore_on_purge` parsing.
   - Comment content validation.
   - Sighting count helpers if shared cleanly.

4. Keep route handlers as thin HTTP adapters:
   - Parse request.
   - Call service/helper.
   - Return response.

Acceptance criteria:
- `dump1090.py` and `dump978.py` are shorter and easier to compare.
- Common behavior is tested once where practical.
- Endpoint tests remain green.

## Phase 4: Split Models by Domain Carefully

Current issue: `backend/models.py` contains all model classes.

Recommended approach: defer this until route/service cleanup is stable.

Option A: conservative split with compatibility wrapper:

1. Create a package:
   - `backend/models/__init__.py`
   - `backend/models/base.py`
   - `backend/models/users.py`
   - `backend/models/blog.py`
   - `backend/models/adsb.py`
   - `backend/models/uat.py`
   - `backend/models/settings.py`

2. Keep import compatibility:
   - Existing imports like `from backend.models import db, User, Flight` should continue working.

3. Move classes in small groups, not all at once.

Option B: keep `models.py` for now and only reorganize internally with clear sections.

Recommendation:
- Use Option B first if migration/import risk is high.
- Use Option A only if the project will keep growing significantly.

Acceptance criteria:
- No migration autogenerate noise from model relocation.
- Existing imports continue working.
- Tests pass.

## Phase 5: Refactor Background Jobs

Target files:
- `backend/jobs/dump1090_data_collection.py`
- `backend/jobs/dump978_data_collection.py`
- `backend/jobs/rrd_data_collection.py`
- `backend/jobs/maintenance.py`

1. Replace `print()`-style logging with structured `logging` calls.

2. Extract reusable DB upsert/update helpers for dump1090 and dump978 processors.

3. For RRD writing, move repeated metric definitions into data structures where practical:
   - Metric name.
   - RRD path pattern.
   - DS definition.
   - Extractor function/value.

4. Keep subprocess calls explicit and safe.
   - Continue using argument arrays for `subprocess.run`.
   - Keep timeouts where appropriate.

5. Avoid changing collection intervals or scheduler semantics.

Acceptance criteria:
- Job behavior remains the same.
- RRD writer methods are shorter and easier to test.
- Tests pass.

## Phase 6: Tighten Error Handling

Current issue: many broad `except Exception` blocks return generic errors.

1. Replace broad catches where clear expected exceptions exist:
   - Validation errors.
   - SQLAlchemy errors.
   - URL/network errors.
   - JSON decode errors.
   - File/config errors.

2. Preserve generic 500 fallback at route boundaries.

3. Ensure logging uses `logging.exception(...)` or `exc_info=True` consistently.

4. Avoid swallowing errors silently in tests unless deliberately testing resilience.

Acceptance criteria:
- Error responses remain compatible.
- Logs become more actionable.
- Tests cover representative error paths.

## Phase 7: Remove Import and API Noise

1. Remove unused imports found by Ruff/autoflake.

2. Normalize inconsistent imports.

3. Remove dead comments such as disabled scheduler debug code when no longer useful.

4. Review use of `jsonify` vs Flask-RESTX return dictionaries for consistency.

Acceptance criteria:
- Lint passes under the selected conservative Ruff rule set.
- No endpoint behavior changes.

## Phase 8: Optional Service Layer Cleanup

Only do this if route files still feel heavy after earlier phases.

1. Introduce service modules by domain:
   - `backend/services/users.py`
   - `backend/services/blog.py`
   - `backend/services/flights.py`
   - `backend/services/graphs.py`

2. Move non-HTTP business logic out of Resource methods.

3. Keep Flask request/response concerns in route modules.

Acceptance criteria:
- Route files are mostly docs, request parsing, auth decorators, and response formatting.
- Service functions are directly unit-testable.

## Suggested PR Breakdown

Prefer several small PRs instead of one large cleanup PR:

1. `docs/tooling: normalize requirements and add lint baseline`
2. `refactor: split app factory setup helpers`
3. `refactor: centralize backend config loading`
4. `refactor: extract common pagination and parsing helpers`
5. `refactor: reduce ADS-B and UAT route duplication`
6. `refactor: simplify RRD collection writer`
7. `chore: remove unused imports and tighten error logging`

## Verification Checklist for Each Phase

Run from `build/portal/backend`:

```bash
python -m pytest -q
python -m compileall backend tests
```

If Ruff is added:

```bash
ruff check .
```

For phases touching routes, also verify:

- `/api/docs/` still loads.
- Auth-protected routes still require JWTs.
- Admin-only routes still reject normal users.
- Public routes still work without JWTs.
- Existing pagination/filter query parameters still behave the same.

## Risk Areas

- Flask-RESTX namespace registration and blueprint registration may have subtle route-order implications.
- SQLAlchemy model relocation can affect migration discovery if done carelessly.
- Scheduler job setup can accidentally start jobs during tests if initialization order changes.
- Direct `config.yml` reads are brittle; changing them should be covered by tests.
- `dump1090` and `dump978` are similar but not identical; avoid over-generalizing them into unreadable abstractions.

## Recommended First Commit

Start with the lowest-risk cleanup:

1. Convert `requirements.txt` to UTF-8.
2. Add a short backend test/setup note if one does not already exist.
3. Add conservative Ruff config.
4. Remove unused imports only.
5. Run the full test suite.

That establishes clean tooling before structural refactors.

## Phase 11: Swagger/API Documentation Follow-up

Current issue: `/api/swagger.json` generates successfully, but several multiplexed controllers expose weak generated docs because one `Resource.get()` handles multiple paths. The main gaps are missing summaries, missing query parameters, missing per-path response models, and incomplete documented error responses.

Primary targets:
- `backend/routes/dump1090.py`
- `backend/routes/dump978.py`
- `backend/routes/acars.py`
- `backend/routes/live.py` wording only, if touched
- tests under `tests/` for generated Swagger/spec assertions

1. Add generated Swagger coverage tests.
   - Build a test app and fetch `/api/swagger.json`.
   - Assert key paths exist for ADS-B, UAT, and ACARS.
   - Assert documented query parameters for list/search/positions/purge endpoints.
   - Assert response models or response codes are present for read/count/database endpoints.

2. Improve ADS-B and UAT Swagger output without changing endpoint behavior.
   - Preferred: split multiplexed `AdsbFlightsController` and `UatFlightsController` into one `Resource` class per URL family.
   - Alternative: keep routing structure but add explicit RESTX docs where generated output can be made accurate.
   - Document `offset`, `limit`, `q`, `ignore_on_purge`, `days`, `flight`, and `comment_id` where applicable.
   - Reuse existing models: `Flight`, `FlightsList`, `Position`, `PositionsList`, `FlightCount`, comments, purge result, and purge preference models.

3. Improve ACARS Swagger output without changing endpoint behavior.
   - Preferred: split `AcarsController` into per-route resources for flights, counts, database info, and flight messages.
   - Document `offset`, `limit`, `flight_id`, and `days`.
   - Reuse existing models: `AcarsFlightsList`, `AcarsFlightCount`, `AcarsMessagesList`, `AcarsMessagesCount`, `AcarsDatabaseInfo`, and `AcarsPurgeResult`.
   - Include `503 ACARS database unavailable` where ACARS DB access can fail.

4. Wording cleanup rules.
   - Change misleading generated-doc wording:
     - `ADSB` should become `ADS-B` in the API title/description unless a path/model name requires backward compatibility.
     - `live_ns = Namespace('live', description='Live aircraft data from dump1090')` should mention both dump1090 and dump978 because the endpoint merges both feeds.
     - Any `count` field that counts top-level comments should say so explicitly; otherwise use `Number of comments returned`.
     - `Publication date (YYYY-MM-DD)` should be changed to `Publication date/time string` where the API accepts or returns minute-level timestamps.
   - Keep useful domain comments that explain metric sets or response shape.
   - Remove or avoid adding boilerplate comments such as `# Define API models for documentation` only when already editing that file; do not churn files just to remove comments.
   - Do not rename public model names, endpoint paths, JSON keys, or auth scheme names in a docs-only phase.

5. Verification.
   - Run generated spec tests first.
   - Run targeted route tests for changed files:
     - `tests/test_routes_dump1090.py`
     - `tests/test_routes_dump978.py`
     - `tests/test_routes_acars.py`
     - any new Swagger/spec test file
   - Run `ruff check .`.
   - Run `python -m compileall backend tests`.
   - Run full `pytest -q`.

Acceptance criteria:
- `/api/swagger.json` still returns HTTP 200.
- Swagger paths for ADS-B, UAT, and ACARS include accurate summaries, query/path parameters, response codes, and response models where available.
- No endpoint paths, response payload keys, auth behavior, or database behavior change.
- Targeted tests and full backend suite pass.

## Phase 12: Test Coverage Follow-up

Coverage snapshot reproduced during Phase 12.1:

```text
coverage run -m pytest -q
coverage report -m
475 passed
TOTAL: 73% branch coverage
```

Highest-value gaps from the coverage report:
- `backend/jobs/rrd_data_collection.py`: 12% — most writer/fetch/update paths are untested.
- `backend/jobs/dump978_data_collection.py`: 23% — UAT ingestion coverage lags behind dump1090.
- `backend/routes/notifications.py`: 50% — route validation, recent-summary, duplicate, and error paths need coverage.
- `backend/auth.py`: 64% — authorization edge cases are under-covered.
- `backend/opensky_classification.py`: 70% and `backend/aircraft_classification.py`: 71% — classifier edge cases can be improved with pure unit tests.
- `backend/routes/users.py`: 72%, `backend/routes/graphs.py`: 75%, `backend/routes/devices.py`: 77%, `backend/routes/links.py`: 77% — mostly error/edge paths.

Recommended approach:
1. Add reproducible coverage tooling. [done in Phase 12.1]
   - Coverage run/report settings live in `pyproject.toml`; `TESTING.md` documents `coverage erase`, `coverage run -m pytest -q`, and `coverage report -m`.
   - Do not add an aggressive fail-under gate yet; establish the baseline first.

2. Prioritize behavior-heavy, low-flakiness unit tests.
   - RRD writer helpers: test URL fetch JSON decode errors, missing RRD files, metric mapping, range calculations, network-interface lookup fallback/error behavior, and `_update_rrd` argument construction with mocks.
   - dump978 data collection: mirror the dump1090 ingestion cases already covered, including new aircraft, existing aircraft update, flight creation/reuse, position insertion, missing position fields, bad JSON/feed errors, and rollback paths.
   - auth helpers/decorators: test missing current user, locked user, invalid role, admin-only rejection, and user-or-admin success boundaries.
   - aircraft/OpenSky classifiers: add table-driven pure unit tests for known emitter categories, message types, cache hit/miss behavior, and unknown/default paths.

3. Add route-level tests only where they verify stable public behavior.
   - Notifications: list pagination/search, recent summaries, duplicate create behavior, delete success/not-found, and DB error handling.
   - Users: registration disabled/validation branches, lock/unlock not-found and auth failures, status filters.
   - Graphs/devices/links/settings: invalid parameters, unavailable data, and 404/503 behavior that clients depend on.
   - ADS-B/UAT comments: not-found, forbidden owner/admin boundaries, validation errors, and rollback paths where not already covered.

4. Avoid low-value coverage inflation.
   - Do not write tests that only assert private implementation details after refactors.
   - Do not over-mock SQLAlchemy internals unless the behavior is otherwise hard to trigger.
   - Prefer public route responses, pure helper functions, or thin mocks around network/filesystem/rrdtool boundaries.

5. Verification.
   - For each coverage slice, first run the new focused tests and confirm they fail for the intended missing/incorrect behavior when practical.
   - Run targeted related tests.
   - Run `coverage run --source=backend -m pytest -q && coverage report -m`.
   - Run `ruff check .` and `python -m compileall backend tests` before committing.

Acceptance criteria:
- Coverage command is reproducible from the backend directory.
- Each added test protects public behavior or a stable helper boundary.
- Coverage improves meaningfully in the prioritized low-coverage modules without brittle implementation-detail assertions.
- Full backend suite, Ruff, and compileall pass.
