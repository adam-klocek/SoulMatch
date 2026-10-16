# SoulMatch — Love, Friends, or both

**Connection, considered.** A functional R Shiny MVP with a warm Modern Romance identity, personality-informed introductions, optional interest/lifestyle discovery, and separate Love and Friends connections.

## Start here

Open the extracted `soulmatch` folder in RStudio (R 4.3+), set it as your working directory, and run:

```r
source("scripts/install.R")
shiny::runApp(".")
```

Or use a terminal:

```sh
Rscript scripts/install.R
R -e "shiny::runApp('.', host='127.0.0.1', port=3838)"
```

The app opens at `http://127.0.0.1:3838`. First run creates eight explicitly fictional adult accounts with synthetic questionnaire answers.

**Demo:** `alex` / `SoulMatchDemo!2026`. Other usernames: `maya`, `leo`, `sam`, `nora`, `adam`, `elena`, `jamie`; same password. Maya has expressed interest in Alex in both spaces. As Alex, find Maya and connect in Love or Friends; sign in as Maya in a separate browser profile/private window to reply. These are real persisted local messages, not automated replies.

Create a new account to try onboarding: save your profile, choose Love/Friends/both, and complete the ten-item personality introduction. The three additional reflections, height story, and interests/lifestyle journey are optional. Questionnaire progress can be saved and resumed.

For an empty pilot, choose a fresh private data directory:

```r
Sys.setenv(SOULMATCH_DEMO_MODE = "false", SOULMATCH_DATA_DIR = "pilot-data")
shiny::runApp(".")
```

The demo portraits are fictional AI-created assets; your uploaded photos take precedence. Never use shared demo credentials for real members. Demo accounts are excluded from model exports even if consent is later enabled.

## What changed in 0.3

The app now uses a centered, full-width workspace with a horizontal navigation bar, readable controls, restrained cards, and responsive desktop/mobile layouts. Custom CSS and JavaScript are embedded in the Shiny page; icons also have explicit fallback dimensions. Styling no longer depends on a separate app.css download or a stale CSS cache.

**Self-discovery** starts with six module tiles: personality, closeness, communication, flexibility, interests/everyday life, and the optional height story. Only the selected module is visible. Completed tiles have a more transparent surface and a checkmark; click to revisit. Interests and lifestyle have moved here from My world. Back on the first reflection/interest step returns to the collection. Other Back actions move one step, preserve partial responses, and never require completing the page. All modules is always available.

**My world** is a connection dashboard. It shows people you have chosen to connect with, separately labeled Request sent or Mutual interest, with Love/Friends and status filters. Every card has a photo area and seven aggregate metrics: overall fit, your preference fit, their preference fit, reflection similarity, lifestyle fit, shared interests, and activity potential. Unavailable optional comparisons are labeled Unavailable rather than displayed as measured neutral fit. Romantic preferences are labeled Not applied in Friends. Overall fit uses the Thoughtful balance baseline and can include neutral imputations for unanswered inputs; it is not a probability. Message opens the correct mode-specific conversation for mutual connections only. Incoming non-mutual requests, blocked people, paused spaces, private preference values, and individual questionnaire answers are not exposed.

**Upgrade:** stop the old app, back up your private data folder, replace the application source files with this version, retain the same private data directory, and restart. No new database migration is needed for 0.3. Use the whole extracted folder, including www; do not copy app.R alone. Existing accounts, decisions, photos, and conversations continue to use the same database.

## Existing MVP features


| Area | Implemented behavior |
| --- | --- |
| Brand | SoulMatch name, interlaced loop mark, exact teal/coral/peach/ivory/lavender palette, editorial typography, responsive cards and horizontal navigation |
| Intentions | Enable Love, Friends, or both simultaneously; switch discovery views without changing your saved intentions |
| Connections | Requests and passes are scoped by mode; a Love decision never creates a Friends match. Separate conversations with the same person are supported |
| Profile | Identity, romantic gender interest, city, bio, style, intention, optional income, photos, modes and preferences remain editable |
| Personality | Ten public-domain IPIP items: two per Big Five domain, with reverse coding. This custom experimental screener is **not a standard BFI-2 form** |
| Short reflections | Three independent optional four-item experimental tools: Communication & repair; Closeness & independence; Curiosity & everyday flexibility |
| Height | The linked Brno 11-item questionnaire, original Czech plus an explicitly unvalidated English translation; optional private regression estimate and interval; no direct height input |
| Removed measurement | No weight collection, profile display, preference, feature, seed value or matching contribution. Migration removes the legacy column/keys and discards old matching snapshots |
| Interests | All 16 supplied categories and 195 stable interest IDs; expandable chip selectors, search and a custom suggestion field |
| Follow-ups | Separate optional enjoyment, participation frequency and importance of sharing for every selected interest |
| Lifestyle | Seven supplied lifestyle questions, each with independently recorded partner-matching importance |
| Together | Shared activities from selected interests plus all 12 supplied defaults; optional Nice to have / Important / Essential ratings |
| Persistence | Normalized tables, private drafts, six-step resume, immutable completed snapshots, questionnaire versions and timestamps |
| Matching | Two selectable baselines plus optional evaluated supervised model infrastructure; independent interest/lifestyle feature extraction; both similarity and complementarity available for future research |
| Control | Mutual connection required for chat, two-second message polling, global blocking, report records, photo removal and password-confirmed deletion |

## Love and Friends are independent spaces

Both people must enable the selected mode. Adults only, self-exclusion and global blocks apply everywhere.

**Love** respects mutual romantic gender interest and both people's explicit firm romantic boundaries. Soft preferences influence ranking. Approximate height can only influence a soft preference when the other member explicitly enables a questionnaire estimate. Unknown height never excludes someone.

**Friends** considers interests, activities and lifestyle context. Romantic gender, age-range, height, style, income, smoking and relationship-intention preferences are not applied to friendship eligibility. Adults of any selected gender identity can appear when both enable Friends. The matching feature interface marks the mode explicitly.

A mutual connection must be formed within the same space before chat opens there. Passing someone in Love does not remove them from Friends. Blocking applies across both. Pausing one mode in My profile pauses its discovery and makes its conversations inaccessible until both people enable it again; it does not delete the other mode's conversations or erase prior history.

## Short questionnaires: naming and validity

The old 50-item IPIP measure and six-item context tool are retired in configuration, with historical responses preserved. BFI-2/XS/S metadata remain inactive placeholders.

The active personality introduction selects two keyed public-domain IPIP factor-marker items for each domain. It is an original ten-item selection, **not BFI-2, TIPI, or a validated replacement**. The three four-item tools contain original exploratory questions; they have no established reliability, norms, clinical meaning or predictive validity. The UI states this. Similarity is an experimental ranking choice, not proof of emotional compatibility.

Questionnaire JSON/CSV files in `config/questionnaires/` define IDs, versions, labels, bounds, items, reverse keys, page size, required status, activation and matching inclusion. Raw answers and private mean scores are version-specific. Completion appends to `response_history`; latest responses remain in `responses`. Incomplete answers are held in `response_drafts` and do not count as completed questionnaires. Never silently edit wording or keys under a released version.

## Height without asking for a number

Source: https://fssvm6.fss.muni.cz/vyska/ and its GPL-3.0 source repository, preserved in `third_party/height/`.

The service in `R/height.R` reproduces the original 11-item sum, regression coefficients and approximate 95% prediction interval. The original separate men/women reference samples were primarily young Czech adults; their raw scores are not directly comparable across those groups, and there are no nonbinary-specific norms. The app **never chooses a reference from gender identity**. Anyone may select no centimetre estimate; no invented nonbinary norm is supplied.

Original Czech items are available. The English wording is a new unvalidated translation. Results are educational estimates, not measured physical height. Raw scores stay private and never enter matching. An optional selected-reference estimate appears on a profile and influences soft Love preferences only after explicit permission. Choosing no reference means no estimate or matching contribution, regardless of the permission checkbox. A profile update cannot inject a directly supplied height. Older directly entered heights are cleared by migration.

Because this app incorporates the GPL-licensed height adaptation, the combined distribution uses **GPL-3.0**. Full original code/license and attribution are included; original MIT notices from the earlier project are also retained.

## Interest/lifestyle component

Reusable Shiny modules in `R/interests_modules.R`:

- `interestCategoryUI/Server`: broad category chips.
- `interestChipUI/Server`: stable interest choices, expandable categories, client-side search, suggestion.
- `interestDetailsUI/Server`: separate enjoyment, frequency and partner-sharing importance.
- `lifestyleUI/Server`: categorical/ordinal responses and separate importance.
- `sharedActivitiesUI/Server`: selected interests plus the supplied activity defaults.
- `interestsModuleUI/Server`: six-step orchestration, progress, review, navigation and persistence.

All questions in this journey are optional. About 5–10 interests is a recommendation, not a restriction. Users can select fewer/more, leave follow-ups blank, go backward, save, resume and revise. Unanswered fields are SQL `NULL`, not zero. A custom suggestion is saved separately and does not automatically create a matching feature.

`R/interests_data.R` separates metadata, validation and DBI persistence. Tables include all ten requested entities plus a private suggestion table. Records carry stable user/session/version/question IDs and timestamps. Draft updates reuse a user's draft snapshot. Completing it freezes that snapshot; subsequent edits create another session, retaining prior completed responses for longitudinal work. Draft-only changes do not affect ranking until completion.

Definitions are in `config/interests/`: 16 categories, 195 interests, seven lifestyle dimensions and 12 shared-activity defaults. Overlapping labels have distinct category-scoped IDs. Treat IDs as permanent; create a new instrument version when meaning or measurement changes.

### Integrating into another Shiny app

```r
# Source utils, interests_data and interests_modules; provide existing authenticated user ID.
# On startup, run the component schema and seed_interest_catalog(con, catalog).
interestsModuleUI("interests")
# In server, where current_user_id is a trusted reactive:
interestsModuleServer("interests", con, current_user_id, catalog, on_saved = refresh_profile)
```

The provided app handles migrations and seeding. The standalone component expects the same schema and shared helpers (`panel`, `pill`, `empty_state`). Never accept a user ID from an editable browser field as authentication.

## Feature extraction and algorithms

`extract_interest_features(state_a, state_b, catalog)` is independent from UI/persistence. `interest_pair_features()` loads current completed snapshots. Features include overlap, enjoyment similarity, asymmetric sharing-preference satisfaction, frequency alignment, lifestyle compatibility, ordinal complementarity, shared-activity potential and coverage.

Unselected interests are **not automatically dislikes**. Sharing satisfaction uses explicit partner importance and the other person's reported enjoyment where both are available. Nominal lifestyle options use equality, not arbitrary numeric distances. Ordinal options use normalized distances. Complementarity is exposed separately, not assumed good or automatically added to baseline ranking. Baselines use importance-weighted lifestyle features; an interest you love is not automatically an interest you need to share.

Raw extraction preserves unavailable values as `NA`. Model inputs impute a neutral 0.5 with separate coverage indicators; discovery labels these placeholders; My world shows unavailable component measurements explicitly. These are provisional implementation choices to evaluate, not psychometric claims.

`R/matching.R` separates eligibility, direction-aware features and registered scorers. Both current rankers return experimental 0–100 fit points. Exploration promotes people outside soft Love preferences while respecting firm boundaries and mode eligibility. The optional learned ranker estimates a **connection request after a logged view**, conditional on mode. It does not predict a relationship, and it never multiplies two directional outputs into an asserted mutual probability.

Add a trusted scorer with `register_algorithm()`, returning a finite number in `[0,1]`. Keep eligibility outside the scorer. If features change, update `FEATURE_NAMES`, snapshots and tests together. A new questionnaire/feature registry invalidates older trained artifacts.

## Offline learning and retirement research

```sh
Rscript scripts/export_training.R /private/path/decisions.jsonl
Rscript scripts/train_model.R /private/path/decisions.jsonl /private/path/evaluation.rds
```

Exports require both people's consent before a view and continued consent at export. They exclude demo users, raw answers, photos, messages, usernames and exact preferences. Explicit mode-scoped connection/pass decisions are labels; silence is never rejection. Pseudonymous behavioral feature records still require private handling. Withdrawal excludes prior pair records from later exports, but cannot recall previous exports or retrain a deployed model.

Training requires at least 2,000 explicit decisions; uses fitting, Platt calibration and held-out test partitions grouped by unordered pair's first appearance; reports AUROC, Brier, ECE, baseline Brier, per-mode metrics and exploratory questionnaire ablations. Users can occur across partitions; grouped first-appearance splitting is **not a strict future-only or cold-start-user evaluation**. Repeated selection on one test set, exposure-policy bias and absent subgroup audits remain research limitations.

An evaluation artifact stays inactive. After independent review, an operator can request a limited pilot:

```sh
Rscript scripts/train_model.R /private/path/decisions.jsonl config/models/like_glm.rds --approve-for-pilot
```

Overall gates: at least 300 held-out decisions, ≥50 positives and negatives, Brier better than the training-prevalence baseline, ECE ≤0.10 and a positive calibration slope. A mode is offered only if it has at least 100 held-out cases, ≥25 of each outcome and ECE ≤0.15. These are basic pilot gates, **not validation standards**. No real-world trained model is included. Before public probability claims, use independent later/user-disjoint evaluation, representative exposure, uncertainty estimates, subgroup calibration and relevant relationship outcomes.

Questionnaire ablations are exploratory incremental-prediction checks, not a causal validity test or automatic retirement policy. The normalized histories support later question-level research, subject to appropriate consent and data governance.

## Data, upgrades and deployment

Runtime: SQLite/WAL, parameterized queries, foreign keys, one connection per Shiny session, two-second chat polling. Runtime data and photos are outside public `www/`. Set `SOULMATCH_DATA_DIR` to a private persistent local directory; `SOULMATCH_DB_PATH` optionally names an exact database. The app and export script reuse a legacy `kindred.sqlite` in that directory when no `soulmatch.sqlite` exists. `KINDRED_DATA_DIR` remains a compatibility fallback.

Migrations run automatically. Existing real accounts, photos, psychometric history, messages and Love decisions are retained; older people default to **Love only**, so Friends is never silently enabled. Legacy direct height and retired measurement data are removed, and old matching snapshots are purged. External exports/backups are not modified. Synthetic demo passwords are updated to the documented SoulMatch demo password only for accounts marked as demo.

See `migrations/README.md` and `R/migrations.R`. PostgreSQL DDL for the independent interest component is supplied, but whole-app PostgreSQL/pool integration is not wired or tested. This local MVP is not a horizontally scalable production deployment.

```sh
docker build -t soulmatch .
docker run --rm -p 127.0.0.1:3838:3838 -v soulmatch-data:/srv/shiny-server/soulmatch/data soulmatch
```

Docker defaults to a fresh non-demo app. Docker itself was not built here; dependencies are not a complete reproducible lockfile. Use an R-capable host. The app has not been publicly deployed.

Before real public use, add hardened/verified identity and recovery, global abuse prevention, HTTPS, encrypted durable storage and backup policy, upload processing isolation/moderation, report review/escalation and appropriate age/privacy/retention processes. Current registration only has a per-session delay. Uploaded images are decoded/re-encoded and limited to 5 MB/12 MP, but the pixel check occurs after decoding. Chat is not end-to-end encrypted. Deletion removes active records and photos, not external copies or backups. No emails, unsolicited messages or reports are sent to outside services.

## Visual reference and verification

- `design/mobile-design-board.png` / `.svg`: the earlier 0.2 illustrative mobile reference, not the current 0.3 layout or a browser screenshot.
- `design/identity.md`: visual system.
- `design/ASSETS.md`: fictional portrait provenance and generation prompt.
- `www/assets/soulmatch-mark.svg`: reusable vector mark.
- `VALIDATION.md`: executed checks and limits.

```sh
Rscript scripts/test.R
```

Tests exercise actual Shiny observers, scoring, draft resume, six-step interest flow, normalized history, height estimates/permission, independent connection modes/chat, migration, authentication, photo access, blocks, deletion, consent and offline learning. Browser visual/accessibility QA remains a deployment check; the design reference is not a screenshot.

## Folder map

```text
app.R                       Shiny entry point and configuration
R/                          UI, modules, validation, persistence, features, models
config/questionnaires/      Versioned short reflection definitions and archived tools
config/interests/           Stable categories/interests/lifestyle/activity seed metadata
config/height.json          Original Czech items and experimental English translation
config/models/              Trusted operator-approved model artifact (none included)
migrations/                 Upgrade notes and PostgreSQL component DDL
scripts/                    Install, tests, private export and offline training
www/                        Design tokens, responsive styles, light client behaviors, assets
design/                     Brand guide and illustrative mobile visual reference
tests/testthat/             Behavioral tests and fixtures
third_party/height/         Original GPL-3.0 source and attribution
data/                      Runtime records/photos; excluded from source archive
```
