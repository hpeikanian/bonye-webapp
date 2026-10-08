#!/usr/bin/env python3
"""Create a hosting ZIP with public-readable files regardless of build umask."""
from pathlib import Path
import shutil
import stat
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'build/web'
archive = root / 'downloads/bonye-webapp-v0.2.1-fixed.zip'
archive.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for path in sorted(output.rglob('*')):
        if not path.is_file() or path.name.endswith(('.symbols', '.map')):
            continue
        info = zipfile.ZipInfo(str(path.relative_to(output)),
                               (2026, 10, 8, 0, 0, 0))
        info.create_system = 3
        info.external_attr = (stat.S_IFREG | 0o644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, path.read_bytes())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(((i.external_attr >> 16) & 0o777) == 0o644 for i in z.infolist())
shutil.copy2(archive, root / 'downloads/bonye-webapp-v0.2.1.zip')
print('PASS: ZIP CRC and all file permissions 0644')
