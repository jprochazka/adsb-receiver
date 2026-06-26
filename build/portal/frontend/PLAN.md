# ADS-B Receiver Portal Angular 22 Upgrade Plan

This plan replaces the completed frontend cleanup plan. It covers upgrading the Angular application in `build/portal/frontend` from Angular 21.2.x to Angular 22.x, adopting the Angular 22 / TypeScript 6 toolchain, updating Angular-adjacent packages, and then selectively modernizing code where the change is safe and testable.

## Goal

Upgrade the frontend to the latest stable Angular 22 release while preserving routes, backend API contracts, UI behavior, authentication semantics, map/chart behavior, and the existing Karma/Jasmine test workflow.

## Current Baseline

Verified locally on this branch before writing the plan:

- Repo: `/tmp/adsb-receiver-review`
- Frontend: `build/portal/frontend`
- Branch: `cleanup`
- Current Angular packages in `package.json`: `^21.2.17`
- Current TypeScript: `~5.9.3`
- Current Node in this environment: `v22.23.1`
- Current npm in this environment: `10.9.8`
- Current Angular build system: `@angular/build:application` and `@angular/build:karma`
- Current app architecture: standalone components with strict TypeScript and strict Angular templates enabled
- Current test scripts:
  - `npm run typecheck`
  - `npm run build`
  - `npm run test:headless`
  - `npm run test:coverage`
- `npm audit --omit=dev --audit-level=moderate` currently reports 0 production vulnerabilities.

## External Compatibility Facts Checked

From Angular version compatibility docs:

- Angular `22.0.x` requires Node `^22.22.3 || ^24.15.0 || ^26.0.0`.
- Angular `22.0.x` requires TypeScript `>=6.0.0 <6.1.0`.
- Angular `22.0.x` supports RxJS `^6.5.3 || ^7.4.0`.

Current local Node `v22.23.1` satisfies Angular 22. Current RxJS `~7.8.0` is in the supported range.

Latest package lookup at plan time:

- `@angular/core`: `22.0.3`
- `@angular/cli`: `22.0.4`
- `typescript`: `6.0.3`
- `zone.js`: `0.16.2`
- `rxjs`: `7.8.2`

Use Angular CLI migrations as the source of truth for exact package versions and code migrations. Do not hand-edit all Angular package versions first unless `ng update` is blocked.

## Angular 22 Risks to Manage Explicitly

Angular 22 has real breaking-change risk. Treat this as a migration, not a casual dependency bump.

High-priority risks from Angular 22 changelog/release notes:

- TypeScript older than 6.0 is no longer supported.
- Components with undefined `changeDetection` are now `OnPush` by default. This app currently has many standalone components without explicit `changeDetection`; this can affect UI refresh behavior and tests.
- `HttpBackend` defaults to FetchBackend. If any code depends on XHR-specific behavior or upload progress, keep or opt back to XHR explicitly.
- Template diagnostics may become stricter, including nullable optional chaining/nullish coalescing warnings.
- Data-prefixed attributes no longer bind inputs/outputs.
- Template expression use of `in` variables can fail.
- Forms `min`/`max` validators no longer support string values; bound values must be numbers or null.
- Deprecated/removed APIs include Hammer.js integration, `ComponentFactoryResolver`, `ComponentFactory`, `createNgModuleRef`, and `ChangeDetectorRef.checkNoChanges`.
- Router defaults changed, notably `paramsInheritanceStrategy` defaulting to `always`.

Plan default: preserve behavior first. Adopt new features only after the base migration is green.

## Non-Goals

- Do not redesign the UI.
- Do not change backend endpoint paths, payload keys, auth token keys, or route paths.
- Do not replace Karma/Jasmine, Chart.js, OpenLayers, Bootstrap, or RxJS with different libraries during the Angular migration. Version upgrades are allowed when handled in isolated, verified package-update commits.
- Do not introduce NgRx or broad state-management rewrites.
- Do not convert every component to signals in one pass.
- Do not mix package upgrade commits with broad feature refactors.
- Do not loosen strict TypeScript/template settings except as a short-lived, explicitly tracked blocker workaround.

## Progress Checklist

Legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked / needs decision

Items are only complete after the listed targeted checks and the full frontend verification gate pass.

### Phase 0 — Baseline and Safety Net

- [ ] Phase 0.1 — Confirm clean tree, current branch, and current dependency/test baseline.
- [ ] Phase 0.2 — Save package inventory and current Angular/TypeScript versions in this plan.
- [ ] Phase 0.3 — Run baseline verification on Angular 21: `npm ci`, `npm run typecheck`, `npm run build`, `npm run test:headless`, and `npm run test:coverage` if feasible.
- [ ] Phase 0.4 — Audit Angular 22 breaking-change touchpoints in this codebase before changing packages.
- [ ] Phase 0.5 — Commit the baseline plan/inventory update separately.

### Phase 1 — Angular CLI Migration to v22

- [ ] Phase 1.1 — Run Angular CLI update dry-run/recommendation commands and record any migration warnings.
- [ ] Phase 1.2 — Run `ng update @angular/cli@22 @angular/core@22` without `--force`; do not bypass peer conflicts until investigated.
- [ ] Phase 1.3 — Review and commit only CLI/package/migration output if it is coherent.
- [ ] Phase 1.4 — Run `npm ci` from a clean lockfile and fix lockfile/package consistency.
- [ ] Phase 1.5 — Run `npm run typecheck`; classify failures as TypeScript 6, Angular template, OnPush, FetchBackend, router, or package peer issues.

### Phase 2 — TypeScript 6 and Compiler Strictness Cleanup

- [ ] Phase 2.1 — Update TypeScript to the Angular-supported `>=6.0.0 <6.1.0` range, preferably via CLI migration output.
- [ ] Phase 2.2 — Fix TypeScript 6 errors without weakening `strict`, `strictTemplates`, or existing compiler options.
- [ ] Phase 2.3 — Address new Angular template diagnostics directly unless a temporary diagnostic suppression is justified and recorded.
- [ ] Phase 2.4 — Replace remaining easy `any` seams touched by compiler errors with existing shared domain types.
- [ ] Phase 2.5 — Commit TypeScript/compiler cleanup separately from feature modernization.

### Phase 3 — Angular 22 Behavior Compatibility

- [ ] Phase 3.1 — Audit every standalone component for implicit Angular 22 `OnPush` behavior.
- [ ] Phase 3.2 — For components where behavior must stay eager, add explicit compatibility configuration or update data flow/tests to be OnPush-safe.
- [ ] Phase 3.3 — Verify async UI updates in auth/nav, admin save flows, live map polling, devices graphs, flights pagination, and blog comments.
- [ ] Phase 3.4 — Audit `HttpClient` usage for FetchBackend behavior differences; preserve XHR only if a concrete issue appears.
- [ ] Phase 3.5 — Audit router behavior affected by inherited route params; pin router config only if a concrete route regression appears.
- [ ] Phase 3.6 — Commit Angular 22 behavior compatibility fixes.

### Phase 4 — Third-Party Package Updates

- [ ] Phase 4.1 — Run `npm outdated --json` after Angular 22 migration and classify packages into Angular-managed, runtime, dev/test, and risky UI/runtime packages.
- [ ] Phase 4.2 — Update Angular-managed packages together: `@angular/*`, `@angular/build`, `zone.js`, and TypeScript within Angular compatibility bounds.
- [ ] Phase 4.3 — Update low-risk runtime packages in small groups: fonts, `bootstrap`, `chart.js`, `rxjs` patch/minor, `tslib`.
- [ ] Phase 4.4 — Update high-risk runtime packages separately: `ol` and anything that affects map rendering or projection behavior.
- [ ] Phase 4.5 — Update dev/test packages separately: `jasmine-core`, `karma`, launchers/reporters, and `@types/jasmine`.
- [ ] Phase 4.6 — Run `npm audit --omit=dev --audit-level=moderate` and document/fix any production advisories.
- [ ] Phase 4.7 — Commit each package group separately with verification evidence.

### Phase 5 — Angular 22 Feature Adoption

Adopt features only after Phases 1-4 are green. Prefer small, reversible, behavior-preserving improvements.

- [ ] Phase 5.1 — Replace any remaining legacy structural directives with built-in control flow only where templates are already being touched; many templates already use `@if`/`@for`.
- [ ] Phase 5.2 — Evaluate signal-based component APIs (`input()`, `output()`, `model()`) for small presentational components first, such as `SpinnerComponent`, `AdminSettingToggleComponent`, and chart wrapper inputs.
- [ ] Phase 5.3 — Evaluate `computed()`/`signal()` for local derived UI state in one low-risk component before any broad conversion.
- [ ] Phase 5.4 — Evaluate Angular 22 stable Signal Forms for one isolated form only after existing form behavior is covered by tests; do not migrate all forms at once.
- [ ] Phase 5.5 — Evaluate Angular Aria only where it improves existing accessibility without visual churn.
- [ ] Phase 5.6 — Avoid adopting new APIs in large stateful components (`live`, `flights`, `devices`) until smaller components prove the pattern.

### Phase 6 — TypeScript 6 Modernization

Use TypeScript 6 to improve correctness, not to churn syntax.

- [ ] Phase 6.1 — Keep `strict`, `noImplicitOverride`, `noPropertyAccessFromIndexSignature`, `noImplicitReturns`, and `strictTemplates` enabled.
- [ ] Phase 6.2 — Use stricter inferred types from TS 6 to remove redundant annotations where they obscure domain types.
- [ ] Phase 6.3 — Replace weak object literals with typed helpers or `satisfies` where route/config/admin setting maps need shape checks.
- [ ] Phase 6.4 — Tighten remaining `Observable<any>` and component `any[]` usage touched by upgrade work.
- [ ] Phase 6.5 — Do not add TS 6-specific cleverness unless it reduces an actual bug risk or removes casts.

### Phase 7 — Full Verification and Smoke Testing

- [ ] Phase 7.1 — Run `npm ci` from a clean tree.
- [ ] Phase 7.2 — Run `npm run typecheck`.
- [ ] Phase 7.3 — Run `npm run build` production build.
- [ ] Phase 7.4 — Run `npm run test:headless`.
- [ ] Phase 7.5 — Run `npm run test:coverage` and compare against existing thresholds.
- [ ] Phase 7.6 — Run a browser smoke pass for login/nav, live map, flights, devices graphs, blog, account, and admin workflows if a browser is available.
- [ ] Phase 7.7 — Run `npm audit --omit=dev --audit-level=moderate`.
- [ ] Phase 7.8 — Confirm clean working tree and record final commit SHAs.

## Commit Tracking

Record each upgrade slice here as work proceeds.

| Status | Phase | Commit SHA | Notes |
| --- | --- | --- | --- |
| [ ] | 0 | TBD | Baseline inventory and Angular 22 upgrade plan. |
| [ ] | 1 | TBD | Angular CLI v22 package/migration output. |
| [ ] | 2 | TBD | TypeScript 6/compiler/template cleanup. |
| [ ] | 3 | TBD | Angular 22 behavior compatibility fixes. |
| [ ] | 4 | TBD | Third-party package update groups. |
| [ ] | 5 | TBD | Angular 22 feature adoption slices. |
| [ ] | 6 | TBD | TypeScript 6 modernization slices. |
| [ ] | 7 | TBD | Final verification and smoke/audit evidence. |

## Detailed Execution Plan

### Phase 0: Baseline and Safety Net

Objective: establish a known-good starting point before the Angular 22 migration.

Commands:

```bash
cd /tmp/adsb-receiver-review
git status --short
git branch --show-current

cd build/portal/frontend
node --version
npm --version
npm ci
npm run typecheck
npm run build
npm run test:headless
npm run test:coverage
npm audit --omit=dev --audit-level=moderate
npm outdated --json || true
```

Expected outcome:

- Working tree starts clean except this plan update.
- Baseline tests/builds pass on Angular 21 before upgrade work begins.
- If coverage or headless tests fail for environmental reasons, capture the exact blocker in this plan before proceeding.

Commit:

```bash
git add build/portal/frontend/PLAN.md
git commit -m "docs: plan Angular 22 frontend upgrade"
```

### Phase 1: Angular CLI Migration to v22

Objective: let Angular's official migrations update package metadata and code before any manual modernization.

Commands:

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npx ng update
npx ng update @angular/cli@22 @angular/core@22
npm ci
npm run typecheck
```

Rules:

- Do not use `--force` first.
- If peer conflicts appear, inspect the peer range and package owner before deciding.
- Keep the migration output commit focused on files changed by `ng update` and package manager lockfile updates.
- If Angular CLI suggests incremental update steps, follow them instead of jumping manually.

Likely files:

- `package.json`
- `package-lock.json`
- `angular.json`
- `tsconfig*.json`
- Angular migration-touched source files, if any

Commit:

```bash
git add build/portal/frontend/package.json build/portal/frontend/package-lock.json build/portal/frontend/angular.json build/portal/frontend/tsconfig*.json build/portal/frontend/src
git commit -m "chore: upgrade frontend to Angular 22"
```

### Phase 2: TypeScript 6 and Compiler Strictness Cleanup

Objective: fix compiler/template failures from Angular 22 and TypeScript 6 without weakening type safety.

Commands:

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npm run typecheck
npm run build
```

Fix order:

1. TypeScript syntax/API errors.
2. Angular template type errors.
3. Nullable/optional-chain/nullish-coalescing diagnostics.
4. Test compile errors.
5. Remaining app build errors.

Rules:

- Prefer precise model/interface fixes over casts.
- Avoid broad `as any` patches.
- If a diagnostic must be suppressed temporarily, add a checklist item in this plan explaining where and why.

Commit:

```bash
git add build/portal/frontend/src build/portal/frontend/tsconfig*.json build/portal/frontend/PLAN.md
git commit -m "fix: satisfy TypeScript 6 frontend checks"
```

### Phase 3: Angular 22 Behavior Compatibility

Objective: preserve runtime behavior under Angular 22 defaults.

Audit commands:

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
rg "changeDetection|ChangeDetectionStrategy|ChangeDetectorRef|markForCheck|detectChanges|ComponentFactoryResolver|checkNoChanges|provideHttpClient|withFetch|paramsInheritanceStrategy|canMatch|@Input|@Output" src/app angular.json
```

Checks:

- Components with async subscriptions and no explicit change detection.
- Components whose tests assume eager change detection.
- Polling components (`app`, `live`, `devices`, `rrd-chart`).
- Route-param consumers.
- HTTP operations that may be affected by FetchBackend.

Default strategy:

- First preserve behavior. If a component breaks because Angular 22 defaults to OnPush, either make the component's data flow OnPush-safe or explicitly preserve eager behavior for that component.
- Do not convert large components to signals just to satisfy OnPush; isolate behavior changes.

Verification:

```bash
npm run typecheck
npm run build
npm run test:headless
```

Commit:

```bash
git add build/portal/frontend/src build/portal/frontend/angular.json build/portal/frontend/PLAN.md
git commit -m "fix: preserve frontend behavior on Angular 22"
```

### Phase 4: Third-Party Package Updates

Objective: update non-Angular packages without hiding regressions inside the framework migration.

Commands:

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npm outdated --json || true
npm audit --omit=dev --audit-level=moderate
```

Recommended grouping:

1. Angular-adjacent/toolchain:
   - `zone.js`
   - `typescript`
   - `@angular/*`
2. Low-risk runtime:
   - `@fontsource/inter`
   - `@fontsource/rajdhani`
   - `bootstrap`
   - `chart.js`
   - `rxjs` patch/minor within Angular support
   - `tslib`
3. High-risk runtime:
   - `ol`
   - any package that changes map/chart rendering behavior
4. Dev/test:
   - `jasmine-core`
   - `karma`
   - `karma-*`
   - `@types/jasmine`

Verification after each group:

```bash
npm ci
npm run typecheck
npm run build
npm run test:headless
npm audit --omit=dev --audit-level=moderate
```

Commit each group separately.

### Phase 5: Angular 22 Feature Adoption

Objective: use new Angular features where they reduce code or improve correctness.

Candidate low-risk first slices:

1. Small standalone components:
   - `src/app/shared/spinner/spinner.component.ts`
   - `src/app/shared/admin-setting-toggle/admin-setting-toggle.component.ts`
   - `src/app/shared/rrd-chart/rrd-chart.component.ts`
2. Presentational inputs/outputs:
   - evaluate `input()`/`output()` only when tests can validate behavior.
3. Local derived state:
   - evaluate `signal()`/`computed()` for small local UI state, not shared application state.
4. Forms:
   - evaluate Signal Forms only in one isolated, well-tested form before any broad migration.
5. Accessibility:
   - evaluate Angular Aria for concrete a11y improvements, not a broad rewrite.

Rules:

- One feature-adoption pattern per commit.
- No large component conversion until the pattern is proven in a small component.
- Every feature-adoption commit must include or update tests.

### Phase 6: TypeScript 6 Modernization

Objective: reduce weak typing exposed by the upgrade.

Targets:

- Remaining `Observable<any>` in `src/app/service/data.service.ts`.
- Remaining component `any[]` in admin/blog/user/link/app components.
- Weak payload objects around admin user/blog/link forms.
- Route/nav/link configuration object shapes.

Rules:

- Use existing shared API/domain interfaces where possible.
- Prefer `satisfies` on config maps where it catches shape drift.
- Avoid syntax churn that does not improve safety.
- Keep each typing slice tied to a test/build gate.

Verification:

```bash
npm run typecheck
npm run build
npm run test:headless
```

### Phase 7: Final Verification and Handoff

Objective: prove the upgraded app works and leave a clean branch.

Commands:

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npm ci
npm run typecheck
npm run build
npm run test:headless
npm run test:coverage
npm audit --omit=dev --audit-level=moderate

cd /tmp/adsb-receiver-review
git status --short
git log --oneline -10
```

Manual smoke checklist if browser access is available:

- Login, logout, register, account page.
- Navbar visibility by auth/admin state.
- Live map loads, polls, and shows expected overlays.
- Flights pages paginate/search/detail/comment flows.
- Devices graphs render and period/range controls work.
- Blog list/detail/comment flows.
- Admin users/blog/flights/live/devices/graphs/settings save and error paths.

Final handoff should include:

- Final Angular/CLI/TypeScript/Node versions.
- Package groups updated.
- Test/build/audit output summary.
- Known deferred modernization items, if any.
- Clean working tree evidence.

## Open Questions / Decisions

- If Angular 22 OnPush default creates regressions, should we preserve eager behavior explicitly for existing components first, then migrate to OnPush intentionally later? Default recommendation: yes.
- If FetchBackend creates a concrete HTTP behavior difference, should we opt back to XHR globally or only for affected paths? Default recommendation: only preserve XHR where evidence requires it.
- How aggressively should we adopt Signal Forms? Default recommendation: one isolated form as a spike after the upgrade is green.
- Should package updates beyond Angular 22 be included in this branch? Default recommendation: yes, but only as separate commits grouped by risk.
