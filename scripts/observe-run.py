#!/usr/bin/env python3
"""Read-only, bounded observation of an existing cleanup; never opens folder contents."""
import argparse
import datetime
import json
import pathlib
import sqlite3
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--database', type=pathlib.Path, required=True)
parser.add_argument('--run')
parser.add_argument('--follow', action='store_true')
parser.add_argument('--interval', type=int, default=60)
parser.add_argument('--seconds', type=int, default=3600)
args = parser.parse_args()
deadline = time.monotonic() + max(1, min(args.seconds, 43200))
run_id = args.run
while True:
    try:
        connection = sqlite3.connect(args.database.resolve().as_uri() + '?mode=ro', uri=True, timeout=1)
        try:
            connection.execute('PRAGMA query_only=ON')
            # One short read transaction gives consistent counts and status.
            connection.execute('BEGIN')
            row = connection.execute('SELECT id,status,planned,started_at FROM runs WHERE id=?', (run_id,)).fetchone() if run_id else connection.execute('SELECT id,status,planned,started_at FROM runs ORDER BY started_at DESC LIMIT 1').fetchone()
            if not row:
                raise ValueError('run_not_found')
            run_id = row[0]
            counts = dict(connection.execute('SELECT phase,count(*) FROM events WHERE run_id=? GROUP BY phase', (run_id,)))
            last = connection.execute('SELECT MAX(recorded_at) FROM events WHERE run_id=?', (run_id,)).fetchone()[0]
        finally:
            connection.close()
        print(json.dumps({'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'run': run_id, 'status': row[1], 'planned': row[2], 'started_at': row[3], 'counts': counts, 'last_activity': last}), flush=True)
        if row[1] != 'running':
            break
    except (sqlite3.Error, OSError, ValueError) as error:
        print(json.dumps({'observation_error': type(error).__name__}), flush=True)
        if not args.follow:
            raise SystemExit(1)
    if not args.follow or time.monotonic() >= deadline:
        break
    time.sleep(min(max(10, args.interval), max(0, deadline-time.monotonic())))
