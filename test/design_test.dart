import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/core/language.dart';
import 'package:bonye_customer/core/widgets.dart';
import 'package:bonye_customer/screens/home.dart';
import 'api_test.dart' show MemoryTokens, success, session;

void main() {
  testWidgets(
      'catalog search filters locally without fetching or mixing product state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await appLanguage.select('fa');
    int requests = 0;
    final api = BonyeApi(
        tokens: MemoryTokens()..value = jsonEncode(session()),
        client: MockClient((_) async {
          requests++;
          return success({
            'items': [
              {
                'variant_id': 1,
                'name': 'Alpha',
                'sku': 'DOG-1',
                'price': {'amount': '1000000.00'},
                'sellable_quantity': 3,
                'quick_buy_available': true
              },
              {
                'variant_id': 2,
                'name': 'Beta',
                'sku': 'CAT-2',
                'price': {'amount': '200000.50'},
                'sellable_quantity': 0,
                'quick_buy_available': false
              }
            ]
          });
        }));
    await api.restore();
    await tester.pumpWidget(MaterialApp(home: ProductsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byType(ProductCard), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'cat-2');
    await tester.pumpAndSettle();
    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(requests, 1);
    final buy = tester.widget<FilledButton>(find.ancestor(
        of: find.text('خرید فوری'), matching: find.byType(FilledButton)));
    expect(buy.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('محصولی با این جستجو پیدا نشد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  test(
      'price display groups digits without changing currency or fractional values',
      () {
    expect(money('1000000.00'), '1,000,000 ریال');
    expect(money('200000.50'), '200,000.5 ریال');
    expect(money(0), '0 ریال');
    expect(money('-1234'), '-1,234 ریال');
  });
}
