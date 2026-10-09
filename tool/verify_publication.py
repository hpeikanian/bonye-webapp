#!/usr/bin/env python3
"""Read-only HTTPS verification; never include private FTP or app credentials."""
import json
from pathlib import Path
import sys
import time
import urllib.request

root = Path(sys.argv[1])

def get(path):
    request = urllib.request.Request('https://bonye.pet/app/' + path + f'?check={int(time.time())}',
                                     headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read(16385))

try:
    revision = json.loads((root / 'source-revision.json').read_text())
    manifest = json.loads((root / 'android-update.json').read_text())
    if get('source-revision.json') != revision or get('android-update.json') != manifest:
        raise ValueError('Published metadata differs')
    request = urllib.request.Request(manifest['apk_url'], method='HEAD')
    with urllib.request.urlopen(request, timeout=30) as response:
        if int(response.headers.get('Content-Length', '-1')) != manifest['size_bytes']:
            raise ValueError('Published APK size differs')
except Exception:
    raise SystemExit('Published HTTPS verification failed; inspect the host before announcing the update.') from None
print('Published source revision, Android manifest and APK size verified over HTTPS.')
