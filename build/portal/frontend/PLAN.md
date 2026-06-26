# ADS-B Receiver Portal Angular 22 Upgrade Plan

## Goal

Upgrade the Angular frontend in `build/portal/frontend` from Angular 21.2.x to Angular 22.x, move the app to the Angular 22 / TypeScript 6 toolchain, update supported frontend packages, and adopt a small number of Angular 22 / TypeScript 6 improvements where they are safe and verified.

## Scope

This plan is only for the Angular upgrade work.

Included:

- Angular framework and CLI upgrade to v22.
- TypeScript upgrade to the Angular-supported v6 range.
- Angular-managed package updates: `@angular/*`, `@angular/build`, `zone.js`.
- Compatible frontend package updates where safe: RxJS, Bootstrap, Chart.js, OpenLayers, Karma/Jasmine tooling, fonts, and related dev dependencies.
- Angular 22 compatibility fixes for compiler, template, routing, HTTP, change-detection, and test behavior.
- Limited feature adoption after the upgrade is green.
- Full build, test, coverage, audit, and browser smoke verification.

Excluded:

- UI redesign.
- Backend API route, payload, or auth-token contract changes.
- Replacing Karma/Jasmine, Chart.js, OpenLayers, Bootstrap, or RxJS with different libraries.
- Introducing NgRx or another global state-management framework.
- Converting the whole app to signals or Signal Forms in one pass.
- Broad unrelated refactoring not required by the Angular 22 upgrade.

## Current Baseline

Verified before starting upgrade implementation:

- Repo: `/tmp/adsb-receiver-review`
- Frontend: `build/portal/frontend`
- Current Angular packages in `package.json`: `^21.2.17`
- Current TypeScript: `~5.9.3`
- Current Node in this environment: `v22.23.1`
- Current npm in this environment: `10.9.8`
- Current Angular build system: `@angular/build:application` and `@angular/build:karma`
- Current app architecture: standalone components with strict TypeScript and strict Angular templates enabled
- Current scripts:
  - `npm run typecheck`
  - `npm run build`
  - `npm run test:headless`
  - `npm run test:coverage`
- Current production audit: `npm audit --omit=dev --audit-level=moderate` reports 0 production vulnerabilities.


## Phase 0 Baseline Evidence

Collected before changing Angular packages:

- Branch/status: `cleanup`, clean working tree at start.
- Node: `v22.23.1`.
- npm: `10.9.8`.
- `npm outdated --json || true` shows Angular 22 and TypeScript 6 available:
  - `@angular/cli`: current `21.2.17`, latest `22.0.4`.
  - `@angular/core`: current `21.2.17`, latest `22.0.3`.
  - `typescript`: current `5.9.3`, latest `6.0.3`.
  - `zone.js`: current `0.15.1`, latest `0.16.2`.
- `npm ci`: passed; npm reported dev dependency advisories, but production audit remains clean.
- `npm run typecheck`: passed.
- `npm run build`: passed.
- `npm run test:headless`: passed, `332 SUCCESS` on `Chrome Headless 149.0.0.0`.
- `npm run test:coverage`: passed, `332 SUCCESS`.
- Coverage baseline:
  - Statements: `69.72%` (`2734/3921`).
  - Branches: `51.14%` (`757/1480`).
  - Functions: `61.04%` (`699/1145`).
  - Lines: `71.77%` (`2568/3578`).
- `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.
- Angular 22 breaking-change touchpoint audit found:
  - `ChangeDetectorRef.detectChanges()` usage in `flights.component.ts` and `live.component.ts`.
  - `provideHttpClient(withInterceptors([authInterceptor]))` in `app.config.ts`.
  - `@Input` / `@Output` usage in shared chart/toggle components and test stubs.
  - No direct matches for `ComponentFactoryResolver`, `ComponentFactory`, `checkNoChanges`, `createNgModuleRef`, `withFetch`, `paramsInheritanceStrategy`, or `canMatch` in app source.


## Phase 1 / Phase 2 Migration Evidence

Collected during Angular 22 migration:

- `npx ng update` recommended updating `@angular/cli` `21.2.17 -> 22.0.4` and `@angular/core` `21.2.17 -> 22.0.3`.
- `npx ng update @angular/cli@22 @angular/core@22` completed without `--force`.
- Angular CLI migrated package versions to Angular `22.0.x` and TypeScript `6.0.3`.
- Angular CLI added `istanbul-lib-instrument` for Karma coverage.
- Optional CLI migrations were intentionally not run in this phase:
  - Karma to Vitest migration is out of scope because the plan keeps Karma/Jasmine.
  - Application-builder migration was not needed; the app already uses `@angular/build:application`.
- Angular core migrations applied compatibility changes:
  - Added `ChangeDetectionStrategy.Eager` to components to preserve pre-v22 eager behavior.
  - Added `withXhr()` to `provideHttpClient` call sites to preserve pre-v22 XHR backend behavior.
  - Wrapped affected optional chaining expressions in `devices.component.html`.
  - Added temporary extended-diagnostic suppressions for `nullishCoalescingNotNullable` and `optionalChainNotNullable` to retain pre-v22 behavior while strict templates remain enabled.
- First TypeScript 6 typecheck failed with `TS2882` for side-effect CSS imports of `ol/ol.css` in `flights.component.ts` and `live.component.ts`.
- Added `src/styles.d.ts` with `declare module '*.css';` to satisfy TypeScript 6 side-effect import declarations without weakening strict settings.
- Verification after the CSS module declaration:
  - `npm ci`: passed.
  - `npm run typecheck`: passed.
  - `npm run build`: passed with a production bundle budget warning: initial bundle exceeded the `1.65MB` warning budget by `22.48 kB`; no build failure.
  - `npm run test:headless`: passed, `332 SUCCESS`.
  - `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.

## Phase 3 Runtime Compatibility Evidence

Collected after the Angular 22 migration:

- Angular 22 `OnPush` default risk is mitigated by the official migration adding `ChangeDetectionStrategy.Eager` to app components and relevant test stubs.
- Existing explicit `ChangeDetectorRef.detectChanges()` usage remains in `flights.component.ts` and `live.component.ts`; no additional runtime compatibility change was needed in this phase.
- Angular 22 FetchBackend behavior risk is mitigated by the official migration adding `withXhr()` to app/test `provideHttpClient` call sites.
- Router audit found route-param consumers in `flights`, `acars`, `blog`, `login`, and `register`; no `paramsInheritanceStrategy` override or `canMatch` implementation was found, and no code change was needed.
- Removed/deprecated API audit found no direct app-source matches for `ComponentFactoryResolver`, `ComponentFactory`, `checkNoChanges`, `createNgModuleRef`, `withFetch`, `paramsInheritanceStrategy`, or `canMatch`.
- Verification:
  - `npm run typecheck`: passed.
  - `npm run build`: passed with the known production bundle warning: initial bundle exceeds the `1.65MB` warning budget by `22.48 kB`; no build failure.
  - `npm run test:headless`: passed, `332 SUCCESS`.
  - `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.

## Phase 4 Frontend Package Update Evidence

Collected after Angular 22 runtime compatibility verification:

- `npm outdated --json || true` initially reported only:
  - `zone.js`: current/wanted `0.15.1`, latest `0.16.2`.
  - `@angular/platform-browser-dynamic`: current/wanted `22.0.3`, reported latest `20.0.7`; cross-checked with `npm view @angular/platform-browser-dynamic@22.0.3 version dist-tags --json`, which shows stable latest `22.0.3`, so this is treated as an npm outdated/deprecation reporting anomaly, not a downgrade target.
- Angular peer compatibility check: `@angular/core@22.0.3` supports `zone.js` `~0.15.0 || ~0.16.0` and RxJS `^6.5.3 || ^7.4.0`.
- Applied one low-risk runtime/toolchain manifest refresh:
  - `zone.js` `0.15.1 -> 0.16.2`.
  - `rxjs` manifest range `~7.8.0 -> ~7.8.2`; installed version remains `7.8.2`.
  - `tslib` manifest range `^2.3.0 -> ^2.8.1`; installed version remains `2.8.1`.
- Runtime packages already current after the Angular migration/inventory:
  - fonts: `@fontsource/inter` `5.2.8`, `@fontsource/rajdhani` `5.2.7`.
  - Bootstrap: `5.3.8`.
  - Chart.js: `4.5.1`.
  - OpenLayers `ol`: `10.8.0`.
  - `to-smooth`: `2.2.0`.
- Dev/test packages had no stable updates reported by `npm outdated`.
- Full audit note: `npm audit --audit-level=moderate` reports no moderate/high/critical advisories. There are 3 low-severity dev/tooling advisories involving current latest Angular build tooling (`@angular/build` `22.0.4`, `@babel/core`, `esbuild`); no newer stable Angular 22 build release is available yet, and production audit remains clean.
- Verification after the package refresh:
  - `npm ci`: passed.
  - `npm run typecheck`: passed.
  - `npm run build`: passed with the known production bundle warning, now `23.68 kB` over the `1.65MB` warning budget; no build failure.
  - `npm run test:headless`: passed, `332 SUCCESS`.
  - `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.

## Phase 5 Limited Angular 22 Feature Adoption Evidence

Implemented one small, verified feature-adoption slice after Phases 1-4 were green:

- Converted remaining legacy structural directive usage in `admin-graphs.component.html` from `*ngIf` / `*ngFor` to Angular built-in control flow `@if` / `@for`.
- Removed now-unused `NgIf` and `NgFor` imports from `AdminGraphsComponent`.
- Converted the small presentational `AdminSettingToggleComponent` from decorator-based `@Input` / `@Output` to signal-based `input.required()`, `input()`, and `output()`.
- Added a local `computed()` value for the toggle state label so the template no longer recomputes `checked ? enabledLabel : disabledLabel` inline.
- Evaluated Signal Forms and Angular Aria for this phase; no isolated low-risk form or concrete accessibility win was adopted without broader design/API changes, so both were deferred.
- Legacy structural directive audit after the slice found no remaining `*ngIf`, `*ngFor`, `*ngSwitch`, `ngSwitchCase`, or `ngSwitchDefault` matches in `src/app`.
- Targeted verification:
  - `npm run test:headless -- --include='src/app/admin-graphs/admin-graphs.component.spec.ts'`: passed, `4 SUCCESS`.
  - `npm run test:headless -- --include='src/app/shared/admin-setting-toggle/admin-setting-toggle.component.spec.ts'`: passed, `2 SUCCESS`.
- Full verification after the feature-adoption slice:
  - `npm run typecheck`: passed.
  - `npm run build`: passed with the known production bundle warning, now `24.77 kB` over the `1.65MB` warning budget; no build failure.
  - `npm run test:headless`: passed, `332 SUCCESS`.
  - `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.

## Phase 6 TypeScript 6 Modernization Evidence

Implemented one small TypeScript modernization slice focused on shape checking and local type tightening:

- Kept strict TypeScript and strict Angular template settings enabled; no compiler weakening was introduced.
- Changed `app.routes.ts` from an explicit `Routes` annotation to `satisfies Routes`, preserving route-object shape checking while avoiding unnecessary type widening.
- Added local `PortalLink` and `LinksResponse` interfaces in `AdminLinksComponent`.
- Replaced `links: any[]`, `editingLink: any`, and `startEdit/deleteLink(link: any)` with typed `PortalLink` state and parameters.
- Added a narrow null guard for `saveEdit()` so `editingLink.id` is only read after the edit target exists.
- Added a defensive guard for impossible drag/drop splice misses, avoiding unsafe assumptions after tightening array element types.
- Avoided broader `DataService` API typing churn because that would touch many endpoints and expand the phase beyond a safe modernization slice.
- Characterization/targeted verification:
  - Before the refactor, `npm run test:headless -- --include='src/app/admin-links/admin-links.component.spec.ts'` passed, `8 SUCCESS`.
  - After the refactor, the same targeted spec passed, `8 SUCCESS`.
- Full verification after the TypeScript modernization slice:
  - `npm run typecheck`: passed.
  - `npm run build`: passed with the known production bundle warning, now `24.85 kB` over the `1.65MB` warning budget; no build failure.
  - `npm run test:headless`: passed, `332 SUCCESS`.
  - `npm audit --omit=dev --audit-level=moderate`: passed with 0 production vulnerabilities.

## Compatibility Facts

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

Use Angular CLI migrations as the source of truth for exact package versions and code migrations. Do not hand-edit Angular packages first unless `ng update` is blocked.

## Angular 22 Risks to Track

Treat the migration as a breaking-change upgrade, not a simple package bump.

Key risks:

- TypeScript older than 6.0 is no longer supported.
- Components with undefined `changeDetection` are now `OnPush` by default.
- `HttpBackend` defaults to FetchBackend.
- Template/compiler diagnostics may become stricter.
- Data-prefixed attributes no longer bind inputs/outputs.
- Template expression use of `in` variables can fail.
- Forms `min`/`max` validators no longer support string values.
- Removed/deprecated APIs include Hammer.js integration, `ComponentFactoryResolver`, `ComponentFactory`, `createNgModuleRef`, and `ChangeDetectorRef.checkNoChanges`.
- Router defaults changed, notably `paramsInheritanceStrategy` defaulting to `always`.

Default strategy: preserve current behavior first. Adopt new features only after the base upgrade is green.

## Progress Checklist

Legend:

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked / needs decision

Items are complete only after targeted checks and the full frontend verification gate pass.

### Phase 0 — Baseline Before Upgrade

- [x] Phase 0.1 — Confirm clean tree and current branch.
- [x] Phase 0.2 — Record current Node, npm, Angular, TypeScript, RxJS, and package inventory.
- [x] Phase 0.3 — Run Angular 21 baseline: `npm ci`, `npm run typecheck`, `npm run build`, `npm run test:headless`, `npm run test:coverage`.
- [x] Phase 0.4 — Run `npm audit --omit=dev --audit-level=moderate` and `npm outdated --json || true`.
- [x] Phase 0.5 — Audit codebase for Angular 22 breaking-change touchpoints before package changes.
- [x] Phase 0.6 — Commit baseline plan/inventory update.

### Phase 1 — Angular CLI v22 Migration

- [x] Phase 1.1 — Run `npx ng update` and record migration guidance.
- [x] Phase 1.2 — Run `npx ng update @angular/cli@22 @angular/core@22` without `--force`.
- [x] Phase 1.3 — Investigate any peer dependency conflicts instead of bypassing them.
- [x] Phase 1.4 — Review migration output in `package.json`, `package-lock.json`, `angular.json`, `tsconfig*.json`, and touched source files.
- [x] Phase 1.5 — Run `npm ci` from the migrated lockfile; if `package.json` and `package-lock.json` are out of sync, regenerate the lockfile and commit both together.
- [x] Phase 1.6 — Commit official Angular migration output separately.

### Phase 2 — TypeScript 6 and Compiler Fixes

- [x] Phase 2.1 — Ensure TypeScript is in Angular's supported `>=6.0.0 <6.1.0` range.
- [x] Phase 2.2 — Run `npm run typecheck` and classify all failures.
- [x] Phase 2.3 — Fix TypeScript 6 errors without weakening `strict` settings.
- [x] Phase 2.4 — Fix Angular template/compiler diagnostics without disabling `strictTemplates`.
- [x] Phase 2.5 — Run `npm run build`.
- [x] Phase 2.6 — Commit TypeScript/compiler fixes separately.

### Phase 3 — Angular 22 Runtime Compatibility

- [x] Phase 3.1 — Audit components affected by Angular 22's default `OnPush` behavior.
- [x] Phase 3.2 — Preserve existing UI update behavior for auth/nav, admin saves, live map polling, devices graphs, flights pagination, and blog comments.
- [x] Phase 3.3 — Audit `HttpClient` usage for FetchBackend behavior differences.
- [x] Phase 3.4 — Audit route-param behavior affected by router default changes.
- [x] Phase 3.5 — Replace or remove any removed Angular APIs if present.
- [x] Phase 3.6 — Run `npm run typecheck`, `npm run build`, and `npm run test:headless`.
- [x] Phase 3.7 — Commit runtime compatibility fixes separately.

### Phase 4 — Frontend Package Updates

- [x] Phase 4.1 — Run `npm outdated --json || true` after Angular 22 migration.
- [x] Phase 4.2 — Update Angular-managed/toolchain packages together: `@angular/*`, `@angular/build`, `zone.js`, `typescript`.
- [x] Phase 4.3 — Update low-risk runtime packages in small groups: fonts, Bootstrap, Chart.js, RxJS patch/minor, `tslib`.
- [x] Phase 4.4 — Update high-risk runtime packages separately, especially OpenLayers (`ol`).
- [x] Phase 4.5 — Update dev/test packages separately: Jasmine, Karma, launchers/reporters, `@types/jasmine`.
- [x] Phase 4.6 — After each package group, run `npm ci`, `npm run typecheck`, `npm run build`, `npm run test:headless`, and production audit.
- [x] Phase 4.7 — Commit each package group separately with verification notes.

### Phase 5 — Limited Angular 22 Feature Adoption

Adopt only small, testable features after Phases 1-4 are green.

- [x] Phase 5.1 — Confirm remaining legacy structural directive usage and convert only if the file is already touched for upgrade work.
- [x] Phase 5.2 — Evaluate signal-based component APIs (`input()`, `output()`, `model()`) on one small presentational component first.
- [x] Phase 5.3 — Evaluate `signal()` / `computed()` for local derived UI state in one low-risk component.
- [x] Phase 5.4 — Evaluate Signal Forms on one isolated, well-tested form only if it clearly reduces complexity.
- [x] Phase 5.5 — Evaluate Angular Aria for concrete accessibility wins without visual redesign.
- [x] Phase 5.6 — Commit each feature-adoption slice separately with tests.

### Phase 6 — TypeScript 6 Modernization

Modernize only where it improves upgrade correctness or removes weak typing exposed by the migration.

- [x] Phase 6.1 — Keep strict compiler settings enabled.
- [x] Phase 6.2 — Use `satisfies` where configuration objects need shape checks.
- [x] Phase 6.3 — Tighten `Observable<any>` or component `any[]` usage only where touched by upgrade work.
- [x] Phase 6.4 — Remove casts introduced during migration if proper types are clear.
- [x] Phase 6.5 — Avoid syntax churn that does not improve safety.
- [x] Phase 6.6 — Commit TypeScript modernization slices separately.

### Phase 7 — Final Verification and Handoff

- [ ] Phase 7.1 — Run `npm ci` from a clean tree.
- [ ] Phase 7.2 — Run `npm run typecheck`.
- [ ] Phase 7.3 — Run `npm run build`.
- [ ] Phase 7.4 — Run `npm run test:headless`.
- [ ] Phase 7.5 — Run `npm run test:coverage`.
- [ ] Phase 7.6 — Run `npm audit --omit=dev --audit-level=moderate`.
- [ ] Phase 7.7 — Run browser smoke checks if a browser is available.
- [ ] Phase 7.8 — Record final versions, test output, audit output, known deferrals, and final commit SHAs.
- [ ] Phase 7.9 — Confirm clean working tree.

## Commit Tracking

| Status | Phase | Commit SHA | Notes |
| --- | --- | --- | --- |
| [x] | 0 | 6e8f55e | Baseline passed: npm ci, typecheck, build, headless tests, coverage, production audit, and breaking-change touchpoint audit. |
| [x] | 1 | ac467c2 | Angular CLI v22 migration output: package updates, Eager change detection, withXhr, diagnostics migration, and template migration. |
| [x] | 2 | 985af51 | Added CSS side-effect module declaration for TypeScript 6; typecheck/build/headless tests pass. |
| [x] | 3 | ac467c2 | Runtime compatibility preserved by Angular migration: Eager change detection and withXhr; removed API/router audits clean; typecheck/build/headless tests pass. |
| [x] | 4 | cc94b98 | Refreshed runtime dependency manifests for `zone.js`, `rxjs`, and `tslib`; package inventory shows no remaining stable updates; verification passed. |
| [x] | 5 | 7094f01 | Adopted built-in control flow in `admin-graphs` and signal-based inputs/output/computed state in `AdminSettingToggleComponent`; verification passed. |
| [x] | 6 | e8d52c8 | Added `satisfies Routes` and tightened `AdminLinksComponent` link response/state types; verification passed. |
| [ ] | 7 | TBD | Final verification and handoff. |

## Execution Commands

### Baseline

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

### Angular Migration

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npx ng update
npx ng update @angular/cli@22 @angular/core@22
npm ci
npm run typecheck
npm run build
npm run test:headless
```

### Breaking-Change Audit

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
rg "changeDetection|ChangeDetectionStrategy|ChangeDetectorRef|markForCheck|detectChanges|ComponentFactoryResolver|ComponentFactory|checkNoChanges|createNgModuleRef|provideHttpClient|withFetch|paramsInheritanceStrategy|canMatch|@Input|@Output|input\(|output\(|model\(" src/app angular.json
```

### Package Updates

```bash
cd /tmp/adsb-receiver-review/build/portal/frontend
npm outdated --json || true
npm audit --omit=dev --audit-level=moderate
npm ci
npm run typecheck
npm run build
npm run test:headless
```

### Final Verification

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

## Browser Smoke Checklist

Run manually if browser access is available after the upgrade:

- Login, logout, register, and account page.
- Navbar visibility by auth/admin state.
- Live map loads, polls, and displays overlays.
- Flights pages paginate, search, show details, and handle comments.
- Devices graphs render and period/range controls work.
- Blog list, detail, and comment flows work.
- Admin users/blog/flights/live/devices/graphs/settings flows save and show errors correctly.

## Open Decisions

- If Angular 22 default `OnPush` creates regressions, preserve current behavior explicitly first, then consider intentional OnPush optimization later.
- If FetchBackend creates a concrete HTTP regression, preserve XHR only for affected behavior rather than opting out globally by default.
- Keep package updates beyond Angular in this branch only when they are grouped, verified, and do not obscure Angular migration failures.
- Keep Signal Forms and signal-based APIs limited to small, reversible slices after the upgrade is green.
