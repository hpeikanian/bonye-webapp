#!/usr/bin/env python3
"""Cache the exact built shell, excluding private API data and downloaded audio."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
output = root / 'build/web'
(output / 'source-revision.json').write_bytes((root / 'source-revision.json').read_bytes())
files = sorted(p for p in output.rglob('*') if p.is_file()
               and p.name not in ['sw.js', 'flutter_service_worker.js', 'android-update.json']
               and 'downloads' not in p.relative_to(output).parts
               and not p.name.startswith('.')
               and not p.name.endswith(('.map', '.symbols')))
digest = hashlib.sha256()
for path in files:
    digest.update(path.read_bytes())
revision = digest.hexdigest()[:20]
# Avoid eager downloads of the large optional skwasm engine; cache on first use.
precache = [str(p.relative_to(output)) for p in files
            if not str(p.relative_to(output)).startswith('canvaskit/')
            or (p.name.startswith('canvaskit.') and p.suffix in ['.js', '.wasm'])]
resources = [str(p.relative_to(output)) for p in files]
script = """'use strict';
const SHELL_CACHE = 'bonye.shell.REVISION';
const RESOURCES = new Set(RESOURCES_JSON);
const PRECACHE = PRECACHE_JSON;
const base = new URL('./', self.location.href);
self.addEventListener('install', event => {
  event.waitUntil(caches.open(SHELL_CACHE).then(cache =>
    cache.addAll(PRECACHE.map(path => new Request(new URL(path, base).href, {cache: 'reload'})))));
});
// A new worker activates after old tabs close, so an active purchase is not interrupted.
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key.startsWith('bonye.shell.') && key !== SHELL_CACHE)
    .map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== base.origin ||
      !url.pathname.startsWith(base.pathname) || request.headers.has('Authorization')) return;
  let path = url.pathname.slice(base.pathname.length);
  if (path === '') path = 'index.html';
  // Exact shell allowlist: never cache API, checkout, customer data or arbitrary URLs.
  if (!RESOURCES.has(path) || url.search) return;
  const key = new URL(path, base).href;
  event.respondWith(caches.open(SHELL_CACHE).then(async cache => {
    const cached = await cache.match(key);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') await cache.put(key, response.clone());
    return response;
  }));
});
""".replace('REVISION', revision).replace('RESOURCES_JSON', json.dumps(resources)).replace('PRECACHE_JSON', json.dumps(precache))
(output / 'sw.js').write_text(script)
(output / '.htaccess').write_text('''Options -Indexes
<IfModule mod_mime.c>
  AddType application/wasm .wasm
  AddType application/vnd.android.package-archive .apk
  AddType application/manifest+json .webmanifest
</IfModule>
<IfModule mod_headers.c>
  <FilesMatch "\\.(js|wasm|json|ttf|otf)$|^index\\.html$">
    Header set Cache-Control "no-cache"
  </FilesMatch>
  Header always set X-Content-Type-Options "nosniff"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>
''')
print('PWA shell revision:', revision)
