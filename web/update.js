// Only static shell caches are touched. Account storage and podcast caches remain intact.
(() => {
  let registration, accepted = false, dismissedWorker;
  const box = document.createElement('aside');
  box.id = 'bonye-update'; box.setAttribute('role', 'status');
  box.style.cssText = 'display:none;position:fixed;z-index:2147483647;top:calc(env(safe-area-inset-top) + 8px);left:12px;right:12px;padding:14px;border-radius:16px;background:#274c3b;color:#fff;font:14px sans-serif;box-shadow:0 4px 16px #0003';
  const text = document.createElement('span'), apply = document.createElement('button'), later = document.createElement('button');
  for (const button of [apply, later]) button.style.cssText = 'margin:6px;padding:9px 14px;border:0;border-radius:10px;cursor:pointer';
  box.append(text, apply, later); document.body.append(box);
  const fa = () => document.documentElement.lang !== 'en';
  function show(message, ready = false) {
    box.dir = fa() ? 'rtl' : 'ltr'; text.textContent = message;
    apply.textContent = fa() ? 'به‌روزرسانی' : 'Update'; later.textContent = fa() ? 'بعداً' : 'Later';
    apply.hidden = !ready; box.style.display = 'block';
  }
  function offer() {
    if (registration?.waiting && registration.waiting !== dismissedWorker)
      show(fa() ? 'نسخه جدید آماده است؛ پیش از به‌روزرسانی فرم یا خرید را کامل کنید.' : 'Update ready. Finish any form or purchase before updating.', true);
  }
  later.onclick = () => { dismissedWorker = registration?.waiting; box.style.display = 'none'; };
  apply.onclick = () => {
    if (!registration?.waiting) return;
    accepted = true; apply.disabled = true;
    registration.waiting.postMessage({type: 'ACTIVATE_UPDATE'});
  };
  navigator.serviceWorker?.addEventListener('message', event => {
    if (event.data?.type === 'OTHER_WINDOWS_OPEN') {
      accepted = false; apply.disabled = false;
      show(fa() ? 'برای آپدیت، سایر پنجره‌های بنیه را ببندید و دوباره تلاش کنید.' : 'Close other bonYe windows, then try again.', true);
    }
  });
  navigator.serviceWorker?.addEventListener('controllerchange', () => { if (accepted) window.location.reload(); });
  async function check(manual = false) {
    if (!registration || !navigator.onLine) {
      if (manual) show(fa() ? 'برای بررسی نسخه به اینترنت متصل شوید.' : 'Connect to the internet to check for updates.');
      return;
    }
    try {
      if (manual) show(fa() ? 'در حال بررسی نسخه…' : 'Checking for updates…');
      await registration.update();
      if (manual) dismissedWorker = undefined;
      if (registration.waiting) offer();
      else if (manual && !registration.installing) show(fa() ? 'اپ شما به‌روز است.' : 'Your app is up to date.');
    } catch (_) { if (manual) show(fa() ? 'بررسی نسخه ممکن نشد؛ دوباره تلاش کنید.' : 'Could not check for updates. Try again.'); }
  }
  window.addEventListener('bonye:check-update', () => check(true));
  window.bonyeWebUpdater = {attach(reg) {
    registration = reg;
    reg.addEventListener('updatefound', () => {
      const worker = reg.installing;
      worker?.addEventListener('statechange', () => { if (worker.state === 'installed') offer(); });
    });
    offer(); check();
    document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
    setInterval(() => { if (!document.hidden) check(); }, 5 * 60 * 1000);
  }};
})();
