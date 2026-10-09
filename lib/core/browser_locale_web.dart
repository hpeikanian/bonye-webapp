import 'package:web/web.dart' as web;

void setBrowserLocale(String code) {
  web.document.documentElement?.setAttribute('lang', code);
  web.document.documentElement
      ?.setAttribute('dir', code == 'fa' ? 'rtl' : 'ltr');
}

void checkBrowserUpdate() {
  web.window.dispatchEvent(web.Event('bonye:check-update'));
}
