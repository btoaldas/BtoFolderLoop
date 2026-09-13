ALTER TABLE runs ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
ALTER TABLE runs ADD COLUMN finished_at TEXT;
ALTER TABLE runs ADD COLUMN skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped >= 0);
ALTER TABLE runs ADD COLUMN errors INTEGER NOT NULL DEFAULT 0 CHECK(errors >= 0);
CREATE INDEX events_run_id_id ON events(run_id,id);
UPDATE runs SET
  updated_at=COALESCE((SELECT MAX(recorded_at) FROM events WHERE run_id=runs.id),started_at),
  finished_at=CASE WHEN status!='running' THEN COALESCE((SELECT MAX(recorded_at) FROM events WHERE run_id=runs.id),started_at) END,
  moved=MAX(moved,(SELECT COUNT(*) FROM events WHERE run_id=runs.id AND phase='moved')),
  skipped=(SELECT COUNT(*) FROM events WHERE run_id=runs.id AND phase='skipped'),
  errors=(SELECT COUNT(*) FROM events WHERE run_id=runs.id AND phase='error');
CREATE INDEX runs_activity ON runs(updated_at DESC);
CREATE TRIGGER events_live_counts AFTER INSERT ON events BEGIN
  UPDATE runs SET updated_at=NEW.recorded_at,
    moved=moved+CASE WHEN NEW.phase='moved' THEN 1 ELSE 0 END,
    skipped=skipped+CASE WHEN NEW.phase='skipped' THEN 1 ELSE 0 END,
    errors=errors+CASE WHEN NEW.phase='error' THEN 1 ELSE 0 END
  WHERE id=NEW.run_id;
END;
PRAGMA user_version = 2;
