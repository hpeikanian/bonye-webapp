"""Exercise the shipped updater and service worker across two revisions in a real browser."""
from pathlib import Path
import functools, http.server, json, shutil, threading, tempfile
from playwright.sync_api import sync_playwright
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='bonye-update-', dir='/workspace/scratch') as temp:
    host = Path(temp); app = host/'app'; app.mkdir()
    shutil.copyfile(root/'web/update.js', app/'update.js')
    (app/'index.html').write_text('''<html lang="en"><body><p>Fixture shell</p><script src="update.js"></script><script>navigator.serviceWorker.register('sw.js',{updateViaCache:'none'}).then(reg=>window.bonyeWebUpdater.attach(reg));</script></body></html>''')
    original = (root/'build/web/sw.js').read_text()
    # Keep the generated install/activate/message/fetch behavior, with a small fixture resource set.
    import re
    original = re.sub(r'const RESOURCES = new Set\(.*?\);', 'const RESOURCES = new Set(["index.html", "update.js"]);', original)
    original = re.sub(r'const PRECACHE = .*?;', 'const PRECACHE = ["index.html", "update.js"];', original)
    original = re.sub(r"bonye.shell.[a-f0-9]+", 'bonye.shell.test-old', original)
    (app/'sw.js').write_text(original)
    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_): pass
        def end_headers(self):
            self.send_header('Cache-Control','no-store')
            super().end_headers()
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(host)))
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
            context=browser.new_context();page=context.new_page()
            url=f'http://127.0.0.1:{server.server_port}/app/'
            page.goto(url)
            page.wait_for_function('navigator.serviceWorker.controller !== null')
            page.evaluate("localStorage.setItem('account-fixture','preserve-me')")
            page.evaluate("caches.open('bonye.audio.fixture').then(cache=>cache.put('/downloaded-audio',new Response('saved audio')))")
            (app/'sw.js').write_text(original.replace('test-old','test-new'))
            page.evaluate("navigator.serviceWorker.getRegistration().then(reg=>reg.update())")
            page.get_by_role('button',name='Update',exact=True).wait_for()
            second=context.new_page();second.goto(url)
            page.get_by_role('button',name='Update',exact=True).click()
            page.get_by_text('Close other bonYe windows, then try again.',exact=True).wait_for()
            second.close()
            page.wait_for_timeout(300)
            page.get_by_role('button',name='Update',exact=True).click()
            page.wait_for_function("document.querySelector('#bonye-update').style.display === 'none'")
            page.wait_for_function("caches.keys().then(keys=>keys.includes('bonye.shell.test-new')&&!keys.includes('bonye.shell.test-old'))")
            assert page.evaluate("localStorage.getItem('account-fixture')") == 'preserve-me'
            assert 'bonye.audio.fixture' in page.evaluate('caches.keys()')
            browser.close()
        print('PASS: new worker offered after install; multiple-window guard; consent reload; old shell cache removed; account storage preserved')
    finally:
        server.shutdown();server.server_close()
