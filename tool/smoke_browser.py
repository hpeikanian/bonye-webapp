from playwright.sync_api import sync_playwright
import argparse, json, re, os, shutil
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--base-url', default='http://127.0.0.1:8765/app/')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1] / 'docs'
root.mkdir(exist_ok=True)
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=os.environ.get('CHROME_EXECUTABLE') or shutil.which('chromium'),headless=True,args=['--no-sandbox'])
 context=browser.new_context(viewport={'width':390,'height':844})
 page=context.new_page(); errors=[]; calls=[]; offline=[False]
 page.on('pageerror',lambda e:errors.append(str(e)))
 def api(route):
  if offline[0]:
   route.abort();return
  req=route.request; calls.append(req.url)
  headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'*','Access-Control-Allow-Methods':'GET,POST,PUT,DELETE,OPTIONS'}
  if req.method=='OPTIONS':route.fulfill(status=204,headers=headers);return
  path=req.url.split('/api/v1')[-1].split('?')[0]
  data={'/auth/login':{'access_token':'browser-test-access','refresh_token':'browser-test-refresh','access_expires_at':'2099-01-01T00:00:00Z','refresh_expires_at':'2099-02-01T00:00:00Z'},'/me':{'name':'Demo','member_no':'DEMO-1'},'/products':{'items':[{'variant_id':1,'name':'Demo product','sellable_quantity':10,'sale_price':1000000,'quick_buy_available':False}]},'/pets':{'items':[]}}
  route.fulfill(status=200,headers=headers,content_type='application/json',body=json.dumps({'data':data.get(path,{'items':[],'pagination':{'next_page':None}}),'meta':{'api_version':'1'}}))
 page.route('https://bonye.pet/totallsystem/api/v1/**',api)
 page.goto(args.base_url);page.wait_for_timeout(5000)
 page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
 page.screenshot(path=str(root/'login-fa-web.png'))
 page.get_by_role('button',name=re.compile('زبان اپ')).click()
 page.get_by_text('English',exact=True).click()
 page.get_by_role('button',name='Sign in to bonYe!',exact=True).wait_for()
 page.screenshot(path=str(root/'login-en-web.png'))

 page.get_by_label('Mobile number',exact=True).fill('09121234567')
 page.get_by_label('Password',exact=True).fill('demo-password-only')
 page.get_by_role('button',name='Sign in to bonYe!',exact=True).click()
 page.wait_for_timeout(3000)
 assert 'DEMO-1' in page.locator('body').inner_text()
 page.screenshot(path=str(root/'home-en-web.png'))
 page.get_by_role('button',name='Products',exact=True).click(timeout=5000)
 page.wait_for_timeout(1500)
 assert any('/products?' in call for call in calls)
 page.screenshot(path=str(root/'products-en-web.png'))
 # Shell and locale must survive an offline reload. Live API remains unavailable.
 page.evaluate('navigator.serviceWorker.ready')
 caches_before=page.evaluate('caches.keys()')
 assert any(name.startswith('bonye.shell.') for name in caches_before)
 cache_urls=page.evaluate('''async () => {const urls=[];for(const name of await caches.keys()){if(name.startsWith('bonye.shell.')){for(const req of await (await caches.open(name)).keys())urls.push(req.url)}}return urls}''')
 assert not any('/api/v1/' in url for url in cache_urls)
 # Explicitly allow worker activation and precaching to settle.
 page.wait_for_timeout(2000)
 offline[0]=True
 context.set_offline(True)
 page.reload()
 page.wait_for_timeout(5000)
 page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
 assert page.locator('flt-glass-pane').count() == 1
 assert page.locator('#loading').count() == 0
 assert not errors, errors
 print('PASS browser: real startup, English locale, mocked login/home/product stock, offline shell; no JS exceptions')
 browser.close()
