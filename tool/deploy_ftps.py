#!/usr/bin/env python3
"""Deploy only through an FTP account chrooted to public_html/app. Never delete files."""
import argparse
import ftplib
import os
import re
import socket
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


def failure_message(error, stage):
    """Expose only stable categories; server messages can contain credentials."""
    if isinstance(error, ssl.SSLCertVerificationError):
        code = 'TLS_HOSTNAME_MISMATCH' if error.verify_code == 62 else 'TLS_CERTIFICATE_UNTRUSTED'
        hint = 'Use the FTPS server hostname matching its certificate; ask hosting support for the correct FTPS hostname and certificate.'
    elif isinstance(error, socket.gaierror):
        code, hint = 'DNS_LOOKUP_FAILED', 'BONYE_FTP_HOST must be a hostname only, without https://, ftp://, a path or port.'
    elif isinstance(error, (TimeoutError, socket.timeout)):
        code, hint = 'CONNECTION_TIMEOUT', 'Check FTPS port, passive data ports and hosting firewall access from GitHub Actions.'
    elif isinstance(error, ConnectionRefusedError):
        code, hint = 'CONNECTION_REFUSED', 'Check BONYE_FTP_PORT and confirm explicit FTPS is enabled on the host.'
    elif isinstance(error, ssl.SSLError):
        code, hint = 'TLS_NEGOTIATION_FAILED', 'Ask hosting support to check explicit FTPS/TLS and encrypted passive data connections.'
    elif isinstance(error, ftplib.Error):
        match = re.match(r'^(\d{3})', str(error))
        response = match[1] if match else 'unknown'
        code = 'FTP_RESPONSE_' + response
        if response == '530':
            hint = 'Check the full BONYE_FTP_USER and BONYE_FTP_PASSWORD for the app-only account.'
        elif response in ('550', '553'):
            hint = 'Check account root, app folder write permission and permission to rename uploaded files.'
        elif response in ('425', '426', '522'):
            hint = 'Ask hosting support to check passive ports, encrypted data connections and TLS session reuse requirements.'
        else:
            hint = 'Ask hosting support to inspect the FTPS server log for this stage and response code.'
    else:
        code, hint = 'FTPS_OPERATION_FAILED', 'Check the account and hosting logs for this stage.'
    return f'FTPS {code}; stage={stage}. {hint} No credentials were printed.'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path, nargs='?')
    parser.add_argument('--check-connection', action='store_true',
                        help='Read-only connection check before expensive builds')
    args = parser.parse_args()
    if not args.check_connection and args.directory is None:
        parser.error('directory is required for publication')
    files = None if args.check_connection else inventory(args.directory)
    required = ['BONYE_FTP_HOST', 'BONYE_FTP_USER', 'BONYE_FTP_PASSWORD']
    if any(not os.environ.get(name) for name in required):
        raise SystemExit('Missing FTPS secrets; configure the app-only FTP account in GitHub Secrets')
    if os.environ.get('BONYE_FTP_APP_ONLY') != 'true':
        raise SystemExit('Confirm BONYE_FTP_APP_ONLY=true only for an account restricted to public_html/app')
    host = os.environ['BONYE_FTP_HOST'].strip()
    if not re.fullmatch(r'[A-Za-z0-9.-]+', host):
        raise SystemExit('FTPS INVALID_HOST: BONYE_FTP_HOST must contain only the server hostname, without protocol, path or port.')
    try:
        port = int(os.environ.get('BONYE_FTP_PORT', '21'))
        if not 1 <= port <= 65535:
            raise ValueError()
    except ValueError:
        raise SystemExit('FTPS INVALID_PORT: BONYE_FTP_PORT must be a number between 1 and 65535.') from None
    ftp = ftplib.FTP_TLS(context=ssl.create_default_context(), timeout=45)
    stage = 'connect'
    try:
        ftp.connect(host, port)
        stage = 'tls'
        ftp.auth()
        stage = 'login'
        ftp.login(os.environ['BONYE_FTP_USER'].strip(), os.environ['BONYE_FTP_PASSWORD'])
        stage = 'protect-data'
        ftp.prot_p()
        ftp.set_pasv(True)
        stage = 'account-root'
        ftp.cwd('/')
        if args.check_connection:
            ftp.pwd()  # Read-only. Do not print the private server path.
            count = 0
        else:
            stage = 'upload-or-rename'
            count = upload(ftp, files)
        stage = 'disconnect'
        ftp.quit()
    except Exception as error:
        ftp.close()
        raise SystemExit(failure_message(error, stage)) from None
    if args.check_connection:
        print('FTPS preflight passed: certificate, login and account root checked; no files changed.')
    else:
        print(f'Published {count} files through verified FTPS; no remote files deleted.')


if __name__ == '__main__':
    main()
