#!/usr/bin/env python3
"""Reject an accidental rollback of the public Android update build number."""
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

candidate = json.loads((Path(sys.argv[1]) / 'android-update.json').read_text())
try:
    request = urllib.request.Request(
        f'https://bonye.pet/app/android-update.json?check={int(time.time())}',
        headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        current = json.loads(response.read(16385))
except urllib.error.HTTPError as error:
    if error.code != 404:
        raise SystemExit('Cannot validate currently published Android version') from None
    current = None  # First publication has no Android manifest yet.
except Exception:
    raise SystemExit('Cannot validate currently published Android version') from None
if current is not None:
    if current.get('package_name') != candidate['package_name']:
        raise SystemExit('Unexpected published package; publication stopped')
    if current['version_code'] > candidate['version_code']:
        raise SystemExit('Refusing an Android version downgrade')
print('Published Android build number will not decrease.')
