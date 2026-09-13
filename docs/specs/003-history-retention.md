# History, diagnostics and retention

Local development scope; no replacement of an application performing a cleanup.

- Record live counters, last activity and finish time atomically with journal events.
- Show worked-on folders, per-operation root/mode/result and a bounded event viewer.
- Diagnostic JSONL: typed messages without user paths or arbitrary error strings; rotate at 2 MiB and daily, expire after 30 days and cap total storage at 10 MiB by default.
- Operation history: retain completed runs and their recovery paths for 180 days by default. Never automatically prune running, cancelled, stopped, errored or unresolved operations.
- User settings: 1–3650 days for either retention period; 1–100 MiB diagnostic budget. Explain loss of old recovery records before saving; settings never empty Trash or alter worked-on folders.
- History maintenance at startup, after work and periodically while idle. No history maintenance during a scan or cleanup. Diagnostic segments rotate on write to enforce the disk budget even during long operations. SQLite freed pages are reused; no disruptive automatic VACUUM.
- Schema 2 is additive. Back up a populated schema-1 database with SQLite's online backup API before migrating. Preserve this migration backup; it is outside automatic retention.
- Diagnostic failures remain visible but never erase a recovery journal. Journal failure still stops cleanup.
- Validation uses isolated synthetic databases/logs only, including the announced expiration of synthetic records and log segments. Do not run native Trash/UI execution tests against the ongoing user session.
- Rollback of development uses the preceding Git commit. Do not open a schema-2 database with v0.2.0. A migration backup is a historical snapshot, not a safe automatic rollback after later operations.
