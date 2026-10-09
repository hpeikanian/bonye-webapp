#!/usr/bin/env python3
"""Deploy only through an FTP account chrooted to public_html/app. Never delete files."""
import argparse
import ftplib
import os
from pathlib import Path
import ssl
import uuid

ENTRYPOINTS = ['main.dart.js', 'flutter.js', 'flutter_bootstrap.js',
               'index.html', 'sw.js', 'source-revision.json', 'android-update.json']


def inventory(root):
    root = root.resolve()
    files = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('Symlinks are not deployable')
        if path.is_file():
            relative = path.relative_to(root).as_posix()
            if any(part in ('', '.', '..') or '\\' in part or '\n' in part or '\r' in part
                   for part in Path(relative).parts):
                raise ValueError('Invalid deployment filename')
            if relative.endswith(('.map', '.symbols')):
                continue
            files.append((relative, path))
    names = {name for name, _ in files}
    if not {'index.html', 'sw.js', 'android-update.json', 'source-revision.json'} <= names:
        raise ValueError('Expected a complete paired publication')
    rank = {name: i for i, name in enumerate(ENTRYPOINTS)}
    return sorted(files, key=lambda item: (rank.get(item[0], -1), item[0]))


def upload(ftp, files):
    # Account root MUST be restricted to /app; no arbitrary remote-path option.
    ftp.cwd('/')
    made = set()
    for relative, path in files:
        parent = Path(relative).parent
        if str(parent) != '.':
            accumulated = ''
            for part in parent.parts:
                accumulated += '/' + part
                if accumulated not in made:
                    try:
                        ftp.mkd(accumulated)
                    except ftplib.error_perm as error:
                        if not str(error).startswith('550'):
                            raise
                        # Distinguish an existing directory from a permissions failure.
                        ftp.cwd(accumulated)
                        ftp.cwd('/')
                    made.add(accumulated)
        temporary = str(parent / ('.bonye-upload-' + uuid.uuid4().hex))
        with path.open('rb') as stream:
            ftp.storbinary('STOR ' + temporary, stream, blocksize=256 * 1024)
        ftp.rename(temporary, relative)
        # No chmod or deletion of pre-existing host files; retained APKs remain installable.
    return len(files)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    files = inventory(args.directory)
    required = ['BONYE_FTP_HOST', 'BONYE_FTP_USER', 'BONYE_FTP_PASSWORD']
    if any(not os.environ.get(name) for name in required):
        raise SystemExit('Missing FTPS secrets; configure the app-only FTP account in GitHub Secrets')
    if os.environ.get('BONYE_FTP_APP_ONLY') != 'true':
        raise SystemExit('Confirm BONYE_FTP_APP_ONLY=true only for an account restricted to public_html/app')
    ftp = ftplib.FTP_TLS(context=ssl.create_default_context(), timeout=120)
    try:
        ftp.connect(os.environ['BONYE_FTP_HOST'], int(os.environ.get('BONYE_FTP_PORT', '21')))
        ftp.login(os.environ['BONYE_FTP_USER'], os.environ['BONYE_FTP_PASSWORD'])
        ftp.prot_p()  # Encrypt data as well as credentials; never fall back to plain FTP.
        ftp.set_pasv(True)
        count = upload(ftp, files)
        ftp.quit()
    except Exception:
        ftp.close()
        # FTP exceptions can contain server responses. Do not log credentials/server detail.
        raise SystemExit('FTPS publication failed. Check TLS certificate, restricted account and host logs.') from None
    print(f'Published {count} files through verified FTPS; no remote files deleted.')


if __name__ == '__main__':
    main()
