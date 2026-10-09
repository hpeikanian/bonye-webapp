import 'dart:typed_data';
import 'dart:convert';
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bonye_customer/screens/pets.dart';
import 'api_test.dart' show MemoryTokens, session, success;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/core/pet_media.dart';
import 'package:bonye_customer/core/language.dart';

void main() {
  testWidgets(
      'species changes clear previous breed and controlled codes plus localized decimal reach API',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await appLanguage.select('fa');
    final store = MemoryTokens()..value = jsonEncode(session());
    Json? payload;
    final requested = <String>[];
    final api = BonyeApi(
        tokens: store,
        client: MockClient((request) async {
          if (request.method == 'POST') {
            payload = jsonDecode(request.body) as Json;
            return success({'id': 1});
          }
          final species = request.url.queryParameters['species']!;
          requested.add(species);
          return success({
            'breeds': [
              {
                'code': species == 'dog' ? 'golden' : 'persian',
                'name_fa': species == 'dog' ? 'گلدن' : 'پرشین'
              }
            ],
            'conditions': []
          });
        }));
    await api.restore();
    await tester.pumpWidget(MaterialApp(home: PetForm(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Luna');
    await tester.tap(find.byKey(const ValueKey('breed-dog-true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('گلدن').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('گربه').last);
    await tester.pumpAndSettle();
    expect(requested, ['dog', 'cat']);
    expect(find.text('گلدن'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('breed-cat-true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پرشین').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '۴٫۲۵');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیره پرونده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره پرونده'));
    await tester.pumpAndSettle();
    expect(payload?['weight_kg'], 4.25);
    expect(payload?['breed'], 'persian');
    expect(payload?['species'], 'cat');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  test(
      'localized decimals preserve fractional weights and reject grouping/invalid values',
      () {
    expect(double.parse(normalizeDecimal(' ۴٫۲۵ ')), 4.25);
    expect(double.parse(normalizeDecimal('٤,٢٥')), 4.25);
    expect(double.tryParse(normalizeDecimal('1,2,3')), isNull);
  });
  test(
      'photo encoding caps dimensions and bytes, strips metadata and rejects oversized/invalid inputs',
      () {
    final source = image.Image(width: 1700, height: 1200);
    image.fill(source, color: image.ColorRgb8(12, 180, 44));
    final bytes = preparePetPhoto(image.encodePng(source));
    final decoded = image.decodeJpg(bytes)!;
    expect(decoded.width, 1024);
    expect(decoded.height, lessThanOrEqualTo(1024));
    expect(bytes.length, lessThanOrEqualTo(maxPetPhotoBytes));
    expect(decoded.exif.isEmpty, isTrue);
    expect(() => preparePetPhoto(Uint8List(15 * 1024 * 1024 + 1)),
        throwsFormatException);
    expect(() => preparePetPhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });
  testWidgets('forward chevron uses one automatic RTL mirror', (tester) async {
    for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
      await tester.pumpWidget(Directionality(
          textDirection: direction, child: const ForwardChevron()));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.chevron_right);
      expect(icon.icon!.matchTextDirection, isTrue);
    }
  });
}
