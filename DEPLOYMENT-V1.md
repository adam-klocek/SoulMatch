# SoulMatch 1.0 deployment boundaries

## Local pilot

Use the whole extracted soulmatch directory with R 4.3+:

```r
source("scripts/install.R")
shiny::runApp(".")
```

For an empty private pilot, use a fresh private persistent directory:

```r
Sys.setenv(SOULMATCH_DEMO_MODE="false",SOULMATCH_DATA_DIR="/your/private/persistent/soulmatch-data")
shiny::runApp(".")
```

The directory must be writable by the app process and outside www. Restrict its operating-system permissions, encrypt the host volume, configure HTTPS on the hosting endpoint, and back up the database and photos together. The SQLite file is chmod 0600; this is file access control, not encryption. Use a single host/process deployment appropriate for SQLite, not independently replicated ephemeral containers.

## GitHub and Posit

Commit code/configuration/assets and generated dependency metadata. Never commit the data directory, .Renviron, credentials, JSONL exports or private models. From a normal CRAN-based development environment, run scripts/prepare_deploy.R to generate the dependency manifest; commit it beside app.R. Review the file list before pushing. This workspace's extracted distribution packages are not used to fabricate a CRAN dependency lockfile.

Posit Cloud can import the repository as an RStudio project for development. Posit Connect Cloud can deploy from GitHub, but the current local persistence layer must be replaced before collecting real data on ephemeral hosting. Publishing the current archive there is a disposable demo, not durable member storage. Keep demo accounts excluded from any real research dataset.

## Supabase migration still required

There is deliberately no claimed working SUPABASE_DATABASE_URL switch. Required work: a complete PostgreSQL schema migration and SQL/parameter adapter, connection pooling, a restricted non-owner backend database role, private raw-response schema not exposed in the Data API, session-identity-bound access policies/authorization, private photo object upload/download/delete handlers, migration of existing IDs/response versions/photos, and remote integration tests. Do not run the partial interest-component DDL and assume all application tables have been migrated.

Keep credentials in hosting secrets. Use verified encrypted database connections and private object storage. If API/RLS access is introduced, policies must reflect verified member identity; an unrestricted backend or privileged key bypass is not made safe merely by turning RLS on. Test member isolation, cross-mode chat, blocked/suspended access, owner exports, deletion, restored backups and photo access before enabling real accounts.

## Optional flame motion

Set SOULMATCH_FLAME_ANIMATION=true before app startup to animate only the initial loading icon for two slow cycles. Default is false. Reduced-motion overrides the animation. SVG assets remain static and self-contained.
