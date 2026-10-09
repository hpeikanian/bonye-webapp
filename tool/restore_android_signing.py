#!/usr/bin/env python3
"""Restore the existing signing key from a GitHub secret, never print its contents."""
import base64
import os
from pathlib import Path
import subprocess

SIGNER = 'ea2c98d85ab41af5ef356940d6df2a9bc01f3effa415afae4c142a25b592ce19'
key = os.environ.get('BONYE_ANDROID_KEYSTORE_BASE64')
if not key:
    raise SystemExit('Missing BONYE_ANDROID_KEYSTORE_BASE64: publishing requires the existing app signing key')
root = Path(os.environ['ANDROID_USER_HOME'])
root.mkdir(parents=True, exist_ok=True)
path = root / 'debug.keystore'
try:
    path.write_bytes(base64.b64decode(key, validate=True))
    path.chmod(0o600)
    certificate = subprocess.check_output(['keytool', '-exportcert', '-keystore', str(path),
                                          '-alias', 'androiddebugkey', '-storepass', 'android'],
                                         stderr=subprocess.DEVNULL)
    import hashlib
    if hashlib.sha256(certificate).hexdigest() != SIGNER:
        raise ValueError('Wrong signer')
except Exception:
    path.unlink(missing_ok=True)
    raise SystemExit('Invalid signing secret or wrong certificate; publication stopped') from None
print('Existing Android signing identity restored and verified.')
