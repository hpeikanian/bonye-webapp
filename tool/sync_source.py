#!/usr/bin/env python3
"""Materialize canonical Flutter source; never edit generated directories here."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path, help='bonyeapp checkout at the revision to build')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = args.source.resolve()
if source == root or not (source / 'lib/main.dart').is_file():
    raise SystemExit('Expected a separate bonyeapp source checkout')
for name in ['lib', 'assets', 'test']:
    target = root / name
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source / name, target)
for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml']:
    shutil.copy2(source / name, root / name)
for path in (root / 'browser_test').glob('*.dart'):
    shutil.copy2(path, root / 'test' / path.name)
revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
digest = hashlib.sha256()
for path in sorted((root / 'lib').rglob('*.dart')):
    digest.update(str(path.relative_to(root)).encode())
    digest.update(path.read_bytes())
(root / 'source-revision.json').write_text(json.dumps({
    'repository': 'hpeikanian/bonyeapp', 'commit': revision,
    'lib_sha256': digest.hexdigest(),
}, indent=2) + '\n')
print('Shared Flutter source synchronized:', revision)
