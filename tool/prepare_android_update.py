#!/usr/bin/env python3
"""Publish a verified APK and uncached manifest after the web shell is built."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

SIGNER = 'ea2c98d85ab41af5ef356940d6df2a9bc01f3effa415afae4c142a25b592ce19'
PACKAGE = 'pet.bonye.customer'


def prepare(source, apk, output, apksigner, aapt):
    version = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
                        (source / 'pubspec.yaml').read_text(), re.M)
    if not version:
        raise ValueError('Expected semantic version and increasing Android build number')
    name, code = version[1], int(version[2])
    signature = subprocess.check_output([apksigner, 'verify', '--print-certs', str(apk)], text=True)
    if f'Signer #1 certificate SHA-256 digest: {SIGNER}' not in signature:
        raise ValueError('APK signer differs from the installed bonYe app; refusing publication')
    package = subprocess.check_output([aapt, 'dump', 'badging', str(apk)], text=True).splitlines()[0]
    expected = f"package: name='{PACKAGE}' versionCode='{code}' versionName='{name}'"
    if not package.startswith(expected):
        raise ValueError('APK package/version does not match canonical source')
    filename = f'bonYe-v{name}-{code}.apk'
    target = output / 'downloads' / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(apk, target)
    with apk.open('rb') as stream:
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    manifest = {'package_name': PACKAGE, 'version': name, 'version_code': code,
                'apk_url': f'https://bonye.pet/app/downloads/{filename}',
                'signer_sha256': SIGNER, 'sha256': checksum,
                'size_bytes': apk.stat().st_size,
                'published_at': datetime.now(timezone.utc).isoformat()}
    (output / 'android-update.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Prepared Android {name}+{code}; signature and package verified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('apk', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--apksigner', required=True)
    parser.add_argument('--aapt', required=True)
    args = parser.parse_args()
    prepare(args.source, args.apk, args.output, args.apksigner, args.aapt)
