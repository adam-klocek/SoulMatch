# SoulMatch 1.0 — The First Spark

## 1.0.1 hotfix — startup loader

The 1.0.0 fullscreen loading overlay depended on a single `shiny:connected` event, with no fallback when the event was missed or startup failed. It could conceal a usable interface or hide a startup error indefinitely. The exact cause on the reporting user's machine was not observed.

Runtime changes: `R/ui.R` moves startup status after the screen output and adds a reload control/no-JavaScript explanation; `www/app.css` makes it non-blocking and hides it through a sibling rule whenever screen content exists; `www/app.js` observes screen population, guards partially initialized Shiny APIs, accepts lifecycle hints and shows actionable help after 15 seconds. No private data or schema changes. `DESCRIPTION` now records 1.0.1.

`tests/js/startup.test.cjs` covers ten startup/connection-timing cases with Node's built-in test runner. Run `node --test tests/js/startup.test.cjs` from the app directory. These are logic tests, not browser rendering tests. The existing R suite, asset checks and a real Shiny WebSocket session/login also pass.


This release extends the existing R Shiny application. It is a local pilot release, not a claim of production readiness or validated matchmaking accuracy. No Supabase project has been connected and no public deployment has been performed.

## Assessment and implementation sequence

The 0.3 foundation was reusable: authenticated Shiny sessions, DBI/SQLite migrations, private image handlers, versioned psychometric tools, normalized interests/lifestyle, directional preferences, two registered rankers, consent-aware offline learning, and mode-specific mutual chat. Its primary gaps were unlimited refresh-based discovery, missing availability/context preferences, no post-date outcome collection, no administrator role or research UI, and placeholder branding.

The implemented sequence was: inspect and retain those services; create original vector branding; add transactional schema migration 4; add context eligibility; introduce persisted daily collections; add communication/feedback tools; add private insights and protected administrator views; strengthen offline temporal evaluation; test and document the release. Existing accounts, photos, questionnaire responses, decisions and conversations are retained. No old raw responses were relabeled as a new instrument version.

## Delivered behavior

| Area | Version 1 behavior |
| --- | --- |
| Brand | Original tilted matchstick, coral flame and small peach heart accent; outlined rounded Nunito Sans wordmark; primary, dark, monochrome and standalone SVG variations; favicon SVG plus raster fallbacks; accessible names and static default |
| Integration | Main header, shared login/registration form, self-discovery/onboarding, dashboard welcome, mobile navigation, initial loading state and browser favicon use the new identity |
| Motion | Optional initial-loader flame animation only, off by default, two slow cycles, reduced-motion fallback; other logos stay static |
| Migration | Schema 4 adds role/status, member context, recommendation batches/entries, eligibility snapshots, saves, decision events, feedback, safety separation, experiment assignment, moderation/audit and offline evaluation records |
| Context | Multiple intentions, availability, children, existing children, relationship structure, relocation, alcohol and pets; optional exact-text region/faith/culture; essential/strong/nice importance |
| Eligibility | Existing adult/gender/mode/firm preference/block rules remain; new essential context requirements apply mutually in Love. An unanswered essential field fails the boundary. Friends ignores romantic context requirements. A discovery break hides either mode without closing existing chats |
| Profiles | Five optional Beyond the Photo writing prompts, explicitly labeled as shared profile text; no psychological/photo inference |
| Algorithms | Configurable weighted baseline, equal-weight Common ground baseline, existing mutual-fit heuristic, and gated learned adapter. Configuration supplies daily count, weighting, exploration and exposure bonus. Retired model signatures are invalidated |
| Reciprocal prediction | Standardized internal directional interface returns missing values without a trained model; no precise rejection probabilities appear on profile cards |
| Daily Connections | Default six persisted introductions per day/space, Save for later, revisit saved profile, full profile, explicit extra batches. Refresh reuses a current impression rather than repeatedly creating exposure events |
| Exposure | Eligible candidate opportunities, served introduction timestamps, explicit decision events, bounded low-exposure ranking bonus, epsilon exploration with conditional selection probabilities. Eligibility and blocks precede ranking |
| Insights | Private Dating Insights reports current pool counts, mutual requirements and soft-preference coverage, with no excluded-member identities or promises of attraction |
| Chat | Optional shared-interest starter and respectful closure draft fill the composer only. User chooses Send. Unmatch is scoped by mode; blocks remain global. Message rate limiting is shared through the database |
| After meeting | Both people independently confirm meeting. Each may then save/edit private feedback. Comfort, attraction, natural conversation, profile accuracy, second-meeting interest and optional relationship/satisfaction follow-ups are stored. Safety feedback is stored separately and never exported as a matching predictor |
| Research | Administrator-only funnel counts with denominators and windows, exposure relative to observed opportunities, per-domain reliability when enough consenting non-demo data exists, and recorded offline evaluation results. Fictional demo members are excluded |
| Experiments | Operator-created mode-specific experiments pin algorithm versions, randomly assign participants once and retain assignments. Stop/rollback through an explicit operator command. No automatic winner selection |
| Moderation | Administrator can review reports and suspend/reactivate another account with a reason; changes are audited. Suspended users cannot log in, be recommended or use mutual chat |
| Data control | Owner-only JSON export, existing password-confirmed deletion extended by cascade to new records, optional research consent, retention cleanup for expired rate-limit events, private database file permissions |
| Offline evaluation | Time-ordered pair partitions; later records and outcomes from old pairs cannot cross training boundaries. Pair bootstrap Brier intervals and exploratory paired ablation intervals/BH-adjusted p-values. Consented mutual second-date outcome export uses only pre-meeting features, excludes messages/safety/demo records, and remains evaluation-only |

## Changed files

- `R/brand.R`: shared logo helpers and brand moments.
- `www/brand/`: six independent SVG assets plus 32px favicon and touch-icon PNG fallbacks.
- `R/v1_services.R`: migration 4, context/eligibility, daily recommendations, privacy, outcomes, roles, rate limits, experiments, research aggregation and audit services.
- `R/v1_modules.R`: intentions/profile context, Dating Insights, post-date feedback and administrator modules.
- `R/ui.R`, `R/server.R`: application integration and actions.
- `R/database.R`, `R/migrations.R`, `R/matching.R`, `R/world.R`, `R/questionnaires.R`, `R/learning.R`: backward-compatible persistence integration, matching changes, registry invalidation and offline evaluation.
- `www/app.css`, `www/app.js`: brand sizing, loader, reduced motion, new module layouts and client initialization.
- `config/matching.json`: recommendation policy and weighted baseline coefficients.
- `scripts/admin.R`, `scripts/export_outcomes.R`, `scripts/retention.R`, `scripts/prepare_deploy.R`, updated training/export scripts: explicit operator workflows.
- `tests/testthat/test-v1.R` and updated existing tests: integration/regression coverage.
- `design/BRAND-ASSETS.md`, `design/soulmatch-spark-brand-sheet.svg`/`.png`: usage and vector proof sheet. The earlier design board is historical, not current UI evidence.
- `README.md`, `DEPLOYMENT-V1.md`, `VALIDATION.md`, `DESCRIPTION`, `.gitignore`, `.rscignore`: release and deployment documentation.

## Upgrade and rollback

Stop the old app. Make a consistent backup of the entire private data directory, including photos. If copying a live SQLite database, checkpoint WAL or use SQLite's backup API; stopping the app first is simplest. Replace source files while retaining the same SOULMATCH_DATA_DIR (and optional exact database path). Restart. Migration 4 is transactional and additive; all existing members start as ordinary active members, never administrators. No administrator is automatically assigned to a demo account.

For rollback, stop the app and restore BOTH the pre-upgrade code and its matching database/photos backup. Do not try to run older source against an arbitrarily downgraded schema. Retain the upgraded copy separately if you need to reconcile new pilot records before rollback.

## Operator commands

Run from the application folder. Administrator assignment requires trusted filesystem/database access; it is unavailable through registration.

```sh
Rscript scripts/admin.R role YOUR_USERNAME admin
Rscript scripts/admin.R experiment YOUR_USERNAME pilot_01 friends balanced rules
Rscript scripts/admin.R stop-experiment YOUR_USERNAME pilot_01
Rscript scripts/export_outcomes.R /private/path/outcomes.jsonl
Rscript scripts/train_model.R /private/path/decisions.jsonl /private/path/evaluation.rds --record-db
Rscript scripts/retention.R
Rscript scripts/retention.R --apply
```

Experiment assignment is participant-level randomization, not proof of an interference-free trial in a two-sided network. Pre-register the exposure policy, outcomes, time window and analysis; consent and review are operator responsibilities. Selection probabilities are conditional sequential choice probabilities, not marginal exposure probabilities for an entire day or population. Repeated batches and individual eligibility changes require appropriate weighting in future evaluation.

## What remains before public use

1. Wire and integration-test the full PostgreSQL/Supabase backend and private object storage; configure least-privilege credentials, encrypted storage and transport, backup/restore and host secrets. This release still uses SQLite and private local photos. The existing PostgreSQL component DDL is not a whole-app backend.
2. Add verified identity/account recovery, production abuse defenses, upload decoding isolation/moderation, operational monitoring, independent security testing, and a staffed report process.
3. Define and implement the operator's actual retention periods for each data category and backups. Only short-lived rate-limit cleanup is automated here; accounts and research histories are not silently aged out.
4. Perform target-host browser/mobile/WebSocket/reconnection/accessibility QA. Browser access to the local app was denied in the workspace; SVG proof inspection and server/HTTP checks do not replace browser QA.
5. Collect voluntary real outcomes before making efficacy claims. Evaluate cold-start users, temporal drift, independent later cohorts, exposure bias, subgroup fairness and multiple testing. Current operational dashboards are not a completed causal/psychometric validation study.
6. Geographic distance/radius and extra gender identity labels, independent values measures, formal reliability uncertainty, automated drift alerts, richer longitudinal follow-up scheduling, and advanced model families remain future extensions. Region is an optional exact-text field, not geolocation. No complex model is deployed without supporting data.

Security is layered but not absolute. The application does not encrypt its SQLite file or chats end to end. Trusted host/database operators can access records. Pseudonymous exports remain private data. This release does not assert GDPR compliance; the operator must establish the applicable purposes, legal bases, notices, rights processes and safeguards before recruiting real members.
