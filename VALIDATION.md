# SoulMatch 1.0.1 — Executed validation, 17 October 2026 (Europe/Prague)

## Final results

- **10 JavaScript startup regression tests pass**: missed/already-fired connection event, connection without content, pre-rendered content, script-before-DOM timing, missing Shiny, partial client API initialization, slow startup, missing MutationObserver, content without lifecycle events, and non-blocking CSS/no-JavaScript fallback. These use a DOM/timer stub, not a browser.
- **Real Shiny WebSocket integration passed**: HTTP upgrade 101, session initialization, server-delivered authentication UI, demo login and server-delivered member/Daily Connections UI. This is protocol verification without a rendering engine; it does not verify the reporting user's browser, host or network.

- **351 passing expectations across 34 behavioral tests**, with no failures or warnings in the final run (`Rscript scripts/test.R`).
- Actual Shiny startup and HTTP entry page: **200**. All **18 checked local assets** returned **200** with nonempty content, including Bootstrap/Shiny dependencies, fictional portrait atlas, all six new SVG brand assets, favicon PNG and touch-icon fallback, and preserved legacy vector mark. The entry-page check also confirms the responsive application CSS and JavaScript are embedded in the HTML, rather than fetched through separate app.css/app.js links.
- All **41 R source files** parsed; application modules sourced; client JavaScript passed `node --check`.
- The new SVG logo proof sheet was rendered and visually inspected across primary, dark, standalone and monochrome treatments. Six SVG assets were checked for viewBox/accessibility names and absence of raster images, scripts and external font dependencies. The earlier 0.2 UI board remains historical; neither proof sheet nor board is a running-app browser screenshot.
- Text contrast spot checks: primary teal on ivory **7.62:1**; supporting text #5F6C65 on ivory **4.74:1**; paper text on teal actions **8.64:1**. These checks do not establish full accessibility conformance.

## Behavioral coverage

- Version 1: mutual essential context requirements, soft preference handling, Friends isolation, paused discovery, six-entry persisted daily batches, no duplicate refresh impressions, separate saved profiles, explicit extra collections, bounded recorded selection probabilities, rendered-card impression recording and ownership checks.
- Private outcomes: two independent meeting confirmations; separate matching/safety tables; owner-only exports; mutual consent and demo exclusion; valid pre-meeting feature export; research withdrawal; mode-scoped unmatch and subsequent chat denial.
- Administration: denied member access, explicit operator role assignment, non-demo-only aggregate metrics, algorithm disabling, suspension/login denial, audited controls, shared rate limits and stable version-pinned random assignments.
- Scientific infrastructure: chronological pair mapping independent of input order, temporal record/outcome boundaries, held-out Brier bootstrap intervals, exploratory paired ablations and multiple-comparison adjustment. Synthetic fixtures verify computation only, not real-world reliability, validity or efficacy.
- Existing actual Shiny observers additionally exercise Save for later, revisiting a saved profile, intentions/availability saving, Dating Insights and the administrator gate. Brand helper integration is checked without requiring external font loads.

- Revised navigation: six module tiles, initial collection state, completion styling/checkmarks, selecting each kind of module, return to collection, first-page Back, previous-page Back, partial draft preservation and resuming through an explicit step output instead of hidden Bootstrap tabs.
- My world: outgoing requests versus mutual interest, seven metric fields, missing optional comparisons, no romantic preference metrics in Friends, photo-key updates, block/mode-pause suppression, aggregate-only presentation fields, absence of other people’s raw responses in rendered cards, status filters, and opening the correct mutual conversation.

- Accounts: password verification, invalid credentials, parameterized SQL, adult profile checks and escaped text.
- Personality: exactly ten items/two per domain, reverse scoring, invalid/incomplete answers, current/archived version isolation, append-only completion history and independent retirement of the three optional tools.
- Height: all eleven original sum inputs, regression/interval calculation, incomplete answers, missing reference, no automatic nonbinary norm, optional sharing, direct-height-injection prevention, private raw scores and draft save.
- Interests: all sixteen categories/195 IDs; idempotent seeding; distinct enjoyment/frequency/sharing importance; missing SQL values; valid snapshots; cross-user session-ID protection; immutable completed history; nominal versus ordinal feature handling; six-step Shiny flow; saved draft restoration; optional answers and clearing every selected interest.
- Love/Friends: mutually enabled modes, friendship eligibility without romantic preferences, mode-specific requests/passes, prevention of cross-mode impression forgery, isolated chat messages, mode pausing and global blocks.
- Migration: a version-1 fixture retains accounts/passwords/Love conversations while removing the legacy measurement column, obsolete preference keys and direct height; current schema is version 4. Legacy/current database-path selection is checked.
- Existing flows: mutual chat access, unauthorized-read/write rejection, block enforcement, image-signature validation/re-encoding/access, photo/account deletion and cascades.
- Learning: historical/current consent, demo exclusion, mode-aware snapshots, supervised fitting, separate calibration, held-out metrics, ablations, compatible activation and registry invalidation. Synthetic fixtures verify code only, not actual predictive performance.
- Actual Shiny observers: sign-in, discovery, mode switching, mutual connection, message sending, logout; new adult registration/profile creation, two-page personality completion, draft persistence, discovery unlock and account deletion.

## Environment

R 4.3.3; shiny 1.8.0; bslib 0.6.1; DBI 1.2.2; RSQLite 2.3.4; jsonlite 1.8.8; sodium 1.3.1; png 0.1.8; jpeg 0.1.10; testthat 3.2.1.

The workspace initially lacked R, so checks used an isolated extracted Ubuntu runtime. Its distribution-patched jquerylib expects a registered system package database; the HTTP harness supplied a runtime lookup for its actual installed jQuery 3.6.1. This workaround is not present in the deliverable. Normal setups use the CRAN installation script or Dockerfile.

## Limits and next deployment checks

Interactive browser verification of the local app was attempted but browser access was denied. No interactive browser, device, screen-reader or browser-to-browser WebSocket visual test was completed. The historical design reference does not verify the revised CSS rendering on a target browser. Actual Shiny observers and HTTP/static resources were exercised. Browser reconnection, native file-picker behavior, mobile viewport/layout, scrolling, focus order and complete accessibility require target-host QA.

The Docker image was not built. The PostgreSQL component DDL was not executed and full-app Postgres/pool wiring is not included. No public deployment, load testing, penetration testing, identity/age verification, staffed moderation or real-world psychometric/predictive validation was performed. Default fit scores remain experimental; no trained real-world probability model is shipped.

## Re-run

From the extracted `soulmatch` folder:

```sh
Rscript scripts/install.R
Rscript scripts/test.R
```

Then use `shiny::runApp('.')` and the two-browser demo walkthrough in README.md. See RELEASE-V1.md and DEPLOYMENT-V1.md for staged scope, upgrade/rollback, operator controls and the unimplemented Supabase connection. 
