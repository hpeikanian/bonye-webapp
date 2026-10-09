import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/screens/home.dart';
import 'package:bonye_customer/screens/orders.dart';
import 'api_test.dart' show MemoryTokens, success, session;

void main() {
  test('checkout language preserves the ticket and other URL parameters', () {
    final url = Uri.parse(
        'https://bonye.pet/?bonye_checkout=1#bonye_checkout=opaque-ticket');
    final fa = checkoutLanguageUrl(url, false);
    final en = checkoutLanguageUrl(url, true);
    expect(fa.queryParameters['bonye_lang'], 'fa');
    expect(en.queryParameters['bonye_lang'], 'en');
    expect(en.queryParameters['bonye_checkout'], '1');
    expect(fa.fragment, url.fragment);
    expect(en.fragment, url.fragment);
    expect(en.host, url.host);
  });
  testWidgets(
      'quantity respects stock and replay keys bind to the chosen quantity',
      (tester) async {
    final tokens = MemoryTokens()..value = jsonEncode(session());
    final quantities = <int>[];
    final keys = <String>[];
    final api = BonyeApi(
        tokens: tokens,
        client: MockClient((request) async {
          quantities.add(jsonDecode(request.body)['quantity'] as int);
          keys.add(request.headers['Idempotency-Key']!);
          // Avoid opening a real checkout; the host guard produces a recoverable error.
          return success({'url': 'https://foreign.invalid/checkout'});
        }));
    await api.restore();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProductCard(api: api, product: {
      'variant_id': 1,
      'name': 'bonDog',
      'quick_buy_available': true,
      'sellable_quantity': 2
    }))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('افزایش تعداد'));
    await tester.pumpAndSettle();
    final plus = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.add), matching: find.byType(IconButton)));
    expect(plus.onPressed, isNull);
    await tester.tap(find.text('خرید فوری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خرید فوری'));
    await tester.pumpAndSettle();
    expect(quantities, [2, 2]);
    expect(keys[0], keys[1]);
    await tester.tap(find.byTooltip('کاهش تعداد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خرید فوری'));
    await tester.pumpAndSettle();
    expect(quantities, [2, 2, 1]);
    expect(keys[2], isNot(keys[1]));
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  test('unknown purchase channel stays unknown; app overrides legacy website',
      () {
    expect(orderChannel({}), 'کانال خرید مشخص نشده');
    expect(orderChannel({'sales_channel': 'وب‌سایت', 'purchase_origin': 'app'}),
        'خرید از اپ');
    expect(orderChannel({'sales_channel': 'branch'}), 'خرید حضوری از شعبه');
  });
  testWidgets('legacy products never enable unconfigured quick checkout',
      (tester) async {
    final api = BonyeApi(
        tokens: MemoryTokens(), client: MockClient((_) async => success({})));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProductCard(api: api, product: {
      'variant_id': 1,
      'name': 'bonDog',
      'purchase_link_available': true
    }))));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('خرید فوری'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    expect(find.text('مشاهده در سایت'), findsOneWidget);
    api.dispose();
  });
  testWidgets('checkout rejects foreign hosts and suppresses duplicate taps',
      (tester) async {
    final tokens = MemoryTokens()..value = jsonEncode(session());
    var requests = 0;
    final api = BonyeApi(
        tokens: tokens,
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          expect(jsonDecode(request.body), {'quantity': 1});
          return success({'url': 'https://foreign.invalid/checkout'});
        }));
    await api.restore();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProductCard(api: api, product: {
      'variant_id': 1,
      'name': 'bonDog',
      'quick_buy_available': true
    }))));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('خرید فوری'), matching: find.byType(FilledButton)));
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
