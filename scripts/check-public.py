#!/usr/bin/env python3
"""Check the versioned/staged public surface without printing secret values."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
patterns = [
    r'/Users/[^/\s]+/', r'BTO-HARNESS', r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    r'gh[pousr]_[A-Za-z0-9]{30,}', r'github_pat_[A-Za-z0-9_]{35,}',
    r'AKIA[0-9A-Z]{16}', r'sk-[A-Za-z0-9]{30,}',
]
failures = []
for name in filter(None, paths):
    path = root / name
    if not path.exists():
        continue
    if name.startswith(('.evidence/', '.tmp/', 'dist/', '.build/')) or path.suffix in {'.db', '.sqlite', '.p12', '.pfx', '.pem'}:
        failures.append((name, 'private/generated artifact'))
        continue
    if name == 'scripts/check-public.py':
        continue
    try:
        content = path.read_text()
    except UnicodeDecodeError:
        continue
    if any(re.search(pattern, content) for pattern in patterns):
        failures.append((name, 'sensitive pattern'))
if failures:
    print('\n'.join(f'{path}: {reason}' for path,reason in failures))
    sys.exit(1)
print(f'Public surface checked: {sum(bool(p) for p in paths)} tracked files; no flagged secrets/private paths.')
