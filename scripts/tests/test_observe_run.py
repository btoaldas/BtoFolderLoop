"""Synthetic checks for the read-only observer. Fixtures are retained in .tmp."""
import hashlib
import json
import pathlib
import sqlite3
import subprocess
import sys
import unittest
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]


class ObserverTests(unittest.TestCase):
    def setUp(self):
        self.directory = ROOT / '.tmp' / ('observer-' + str(uuid.uuid4()))
        self.directory.mkdir(parents=True)
        self.database = self.directory / 'settings.sqlite'

    def observe(self, *extra):
        return subprocess.run([sys.executable, str(ROOT / 'scripts/observe-run.py'), '--database', str(self.database), *extra], capture_output=True, text=True, timeout=5)

    def test_missing_database_is_not_created(self):
        result = self.observe()
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.database.exists())
        self.assertIn('observation_error', json.loads(result.stdout))

    def test_completed_followup_reports_events_without_writing_or_disclosing_paths(self):
        with sqlite3.connect(self.database) as connection:
            connection.executescript((ROOT / 'Sources/BtoFolderLoopStorage/Resources/001_initial.sql').read_text())
            connection.execute("INSERT INTO runs VALUES('synthetic','2026-01-01T00:00:00Z','/private-example','cascade','completed',1,0)")
            for index, phase in enumerate(['prepared', 'moved']):
                connection.execute("INSERT INTO events VALUES(?,?,?,?,?,?,?)", (index, 'synthetic', '2026-01-01T00:00:01Z', '/private-example/empty', phase, None, None))
        original = hashlib.sha256(self.database.read_bytes()).hexdigest()
        result = self.observe('--follow', '--run', 'synthetic')
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(value['counts']['moved'], 1)
        self.assertEqual(value['status'], 'completed')
        self.assertNotIn('/private-example', result.stdout)
        self.assertEqual(hashlib.sha256(self.database.read_bytes()).hexdigest(), original)


if __name__ == '__main__':
    unittest.main()
