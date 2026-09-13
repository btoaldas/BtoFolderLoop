PRAGMA foreign_keys = ON;
CREATE TABLE settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);
CREATE TABLE runs (
  id TEXT PRIMARY KEY NOT NULL,
  started_at TEXT NOT NULL,
  root_path TEXT NOT NULL,
  mode TEXT NOT NULL CHECK(mode IN ('singlePass','cascade')),
  status TEXT NOT NULL CHECK(status IN ('running','completed','cancelled','stopped')),
  planned INTEGER NOT NULL CHECK(planned >= 0),
  moved INTEGER NOT NULL DEFAULT 0 CHECK(moved >= 0)
);
CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE RESTRICT,
  recorded_at TEXT NOT NULL,
  source_path TEXT NOT NULL,
  phase TEXT NOT NULL CHECK(phase IN ('prepared','moved','skipped','error')),
  destination_path TEXT,
  detail TEXT
);
PRAGMA user_version = 1;
