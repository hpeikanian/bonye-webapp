#!/usr/bin/env python3
"""Scheduled runs only rebuild when canonical HEAD differs from deployed HEAD."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request

needed = True
if os.environ.get('EVENT') == 'schedule':
    revision = subprocess.check_output(['git', '-C', sys.argv[1], 'rev-parse', 'HEAD'], text=True).strip()
    try:
        request = urllib.request.Request(
            f'https://bonye.pet/app/source-revision.json?check={int(time.time())}',
            headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=20) as response:
            current = json.loads(response.read(16385))
        needed = current.get('commit') != revision
    except Exception:
        # Do not deploy blindly while the production check is unavailable.
        raise SystemExit('Cannot read deployed revision. Run the workflow manually for initial installation.') from None
with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
    output.write(f'needed={str(needed).lower()}\n')
print('Paired build needed.' if needed else 'Canonical revision already published; skipped build.')
