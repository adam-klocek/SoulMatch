# Executed validation — 16 October 2026

## Final results

- **250 passing expectations across 24 behavioral tests**, with no failures or warnings in the final run (`Rscript scripts/test.R`).
- Actual Shiny startup and HTTP entry page: **200**. All **10 checked local assets** returned **200** with nonempty content, including Bootstrap/Shiny dependencies, fictional portrait atlas and vector mark. The entry-page check also confirms the responsive application CSS and JavaScript are embedded in the HTML, rather than fetched through separate app.css/app.js links.
- Application R modules were parsed/sourced; client JavaScript passed `node --check`.
- The earlier 0.2 illustrative mobile design board is preserved as a historical reference. It does not verify the revised 0.3 layout or browser rendering.
- Text contrast spot checks: primary teal on ivory **7.62:1**; supporting text #5F6C65 on ivory **4.74:1**; paper text on teal actions **8.64:1**. These checks do not establish full accessibility conformance.

## Behavioral coverage

- Revised navigation: six module tiles, initial collection state, completion styling/checkmarks, selecting each kind of module, return to collection, first-page Back, previous-page Back, partial draft preservation and resuming through an explicit step output instead of hidden Bootstrap tabs.
- My world: outgoing requests versus mutual interest, seven metric fields, missing optional comparisons, no romantic preference metrics in Friends, photo-key updates, block/mode-pause suppression, aggregate-only presentation fields, absence of other people’s raw responses in rendered cards, status filters, and opening the correct mutual conversation.

- Accounts: password verification, invalid credentials, parameterized SQL, adult profile checks and escaped text.
- Personality: exactly ten items/two per domain, reverse scoring, invalid/incomplete answers, current/archived version isolation, append-only completion history and independent retirement of the three optional tools.
- Height: all eleven original sum inputs, regression/interval calculation, incomplete answers, missing reference, no automatic nonbinary norm, optional sharing, direct-height-injection prevention, private raw scores and draft save.
- Interests: all sixteen categories/195 IDs; idempotent seeding; distinct enjoyment/frequency/sharing importance; missing SQL values; valid snapshots; cross-user session-ID protection; immutable completed history; nominal versus ordinal feature handling; six-step Shiny flow; saved draft restoration; optional answers and clearing every selected interest.
- Love/Friends: mutually enabled modes, friendship eligibility without romantic preferences, mode-specific requests/passes, prevention of cross-mode impression forgery, isolated chat messages, mode pausing and global blocks.
- Migration: a version-1 fixture retains accounts/passwords/Love conversations while removing the legacy measurement column, obsolete preference keys and direct height; current schema is version 3. Legacy/current database-path selection is checked.
- Existing flows: mutual chat access, unauthorized-read/write rejection, block enforcement, image-signature validation/re-encoding/access, photo/account deletion and cascades.
- Learning: historical/current consent, demo exclusion, mode-aware snapshots, supervised fitting, separate calibration, held-out metrics, ablations, compatible activation and registry invalidation. Synthetic fixtures verify code only, not actual predictive performance.
- Actual Shiny observers: sign-in, discovery, mode switching, mutual connection, message sending, logout; new adult registration/profile creation, two-page personality completion, draft persistence, discovery unlock and account deletion.

## Environment

R 4.3.3; shiny 1.8.0; bslib 0.6.1; DBI 1.2.2; RSQLite 2.3.4; jsonlite 1.8.8; sodium 1.3.1; png 0.1.8; jpeg 0.1.10; testthat 3.2.1.

The workspace initially lacked R, so checks used an isolated extracted Ubuntu runtime. Its distribution-patched jquerylib expects a registered system package database; the HTTP-only harness supplied a runtime lookup for its actual installed jQuery 3.6.1. This workaround is not present in the deliverable. Normal setups use the CRAN installation script or Dockerfile.

## Limits and next deployment checks

Interactive browser verification of the local app was attempted but browser access was denied. No interactive browser, device, screen-reader or browser-to-browser WebSocket visual test was completed. The historical design reference does not verify the revised CSS rendering on a target browser. Actual Shiny observers and HTTP/static resources were exercised. Browser reconnection, native file-picker behavior, mobile viewport/layout, scrolling, focus order and complete accessibility require target-host QA.

The Docker image was not built. The PostgreSQL component DDL was not executed and full-app Postgres/pool wiring is not included. No public deployment, load testing, penetration testing, identity/age verification, staffed moderation or real-world psychometric/predictive validation was performed. Default fit scores remain experimental; no trained real-world probability model is shipped.

## Re-run

From the extracted `soulmatch` folder:

```sh
Rscript scripts/install.R
Rscript scripts/test.R
```

Then use `shiny::runApp('.')` and the two-browser demo walkthrough in README.md. 
