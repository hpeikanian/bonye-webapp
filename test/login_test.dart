import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/main.dart';
import 'api_test.dart' show MemoryTokens;

void main() {
  testWidgets(
    'disabled registration shows server error instead of fake signup',
    (tester) async {
      final api = BonyeApi(
        tokens: MemoryTokens(),
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'error': {'code': 'registration_disabled'},
            }),
            503,
          ),
        ),
      );
      await api.restore();
      await tester.pumpWidget(BonyeApp(api: api));
      await tester.tap(find.text('عضویت'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '09121234567');
      await tester.ensureVisible(find.text('دریافت کد تأیید'));
      await tester.tap(find.text('دریافت کد تأیید'));
      await tester.pumpAndSettle();
      expect(find.text('ثبت‌نام هنوز فعال نشده است.'), findsOneWidget);
      expect(find.text('کد پیامکی'), findsNothing);
      api.dispose();
    },
  );
}
