# Schema migrations

`R/migrations.R` applies the local SQLite migrations automatically and transactionally from `open_db()`.

- Version 1: original dating prototype.
- Version 2: removes the retired body-measurement column and obsolete preference keys; clears old directly entered height; discards old matching snapshots; adds private height questionnaire history, psychometric response history/drafts, and normalized interests/lifestyle tables. Existing profiles, accounts, messages, photos, decisions and questionnaire answers are retained.
- Version 3: adds selected connection modes; scopes decisions and conversations by Love/Friends. Existing people and conversations enter **Love only**. Users can explicitly enable Friends in their profiles. Global blocks remain global.

The retirement step enables secure deletion, checkpoints WAL and vacuums the active SQLite database. It cannot alter copies, exports or backups elsewhere. Make a private backup before upgrading a deployed database; retain it only under your own appropriate deletion policy. No such backup is copied into the deliverable.

`002_interests_postgresql.sql` supplies the independent component's PostgreSQL DDL. The DBI services in `R/interests_data.R` use bound parameters and portable `ON CONFLICT` writes. PostgreSQL connection/pool integration, whole-app SQL portability and deployment are **not implemented or tested** in this MVP. The running app remains a single-host SQLite application.

Seed files: `config/interests/categories.csv`, `interests.csv`, and `definition.json`. `seed_interest_catalog()` inserts stable metadata IDs idempotently. Never reorder IDs or reuse a retired ID for a different question or interest. Publish a new questionnaire version for changed meaning or scoring.
