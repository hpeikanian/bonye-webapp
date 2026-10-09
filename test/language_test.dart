import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:bonye_customer/core/api.dart';
import 'package:bonye_customer/core/language.dart';
import 'package:bonye_customer/main.dart';
import 'package:bonye_customer/screens/pets.dart';
import 'api_test.dart' show MemoryTokens, session, success, failure;

Future<void> capture(WidgetTester tester, String name) async {
  if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('/workspace/bonyeapp/docs/previews')
          .create(recursive: true);
      await File('/workspace/bonyeapp/docs/previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await appLanguage.select('fa');
    // Tests do not load packaged fonts automatically.
    for (final entry in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'Cormorant': 'assets/fonts/CormorantGaramond.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  tearDown(() async => appLanguage.select('fa'));

  test('language survives restart and unknown preference uses Persian',
      () async {
    final controller = LanguageController();
    expect(await controller.select('en'), isTrue);
    final restored = LanguageController();
    await restored.restore();
    expect(restored.locale.languageCode, 'en');
    FlutterSecureStorage.setMockInitialValues(
        {LanguageController.preferenceKey: 'xx'});
    final invalid = LanguageController();
    await invalid.restore();
    expect(invalid.locale.languageCode, 'fa');
  });

  test('UI templates translate while user text stays unchanged', () {
    expect(tr('سلام مریم 👋', english: true), 'Hello مریم');
    expect(
        tr('موجودی قابل فروش: 20 بسته', english: true), 'Available: 20 packs');
    expect(tr('گربه · 4.2 کیلوگرم', english: true), 'Cat · 4.2 kg');
    expect(tr('50 امتیاز به کوپن خرید تبدیل شود؟', english: true),
        'Redeem 50 points for a shopping coupon?');
    expect(tr('مریم', english: true), 'مریم');
  });

  testWidgets('login language selector updates direction, fields and errors',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = BonyeApi(
        tokens: MemoryTokens(),
        client: MockClient((_) async => failure('registration_disabled', 503)));
    await api.restore();
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('preview'), child: BonyeApp(api: api)));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(TextField).first)),
        TextDirection.rtl);
    expect(
        Theme.of(tester.element(find.byType(TextField).first))
            .textTheme
            .bodyMedium
            ?.fontFamily,
        'IRANSans');
    await capture(tester, 'login-fa');
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(TextField).first)),
        TextDirection.ltr);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
        Theme.of(tester.element(find.byType(TextField).first))
            .textTheme
            .bodyMedium
            ?.fontFamily,
        'NotoSansArabic');
    await capture(tester, 'login-en');
    await tester.ensureVisible(find.text('Join'));
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '09121234567');
    await tester.ensureVisible(find.text('Send verification code'));
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(find.text('Registration is not enabled yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('English navigation, club and pet form preserve API values',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await appLanguage.select('en');
    Json? submittedPet;
    final store = MemoryTokens()..value = jsonEncode(session());
    final api = BonyeApi(
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/pet-reference')) {
            return success({'breeds': [], 'conditions': []});
          }
          if (request.method == 'POST' && request.url.path.endsWith('/pets')) {
            submittedPet = jsonDecode(request.body) as Json;
            return success({'id': 1});
          }
          if (request.url.path.endsWith('/me')) {
            return success({
              'name': 'مریم',
              'mobile': '09121234567',
              'member_no': 'B-100'
            });
          }
          if (request.url.path.endsWith('/club')) {
            return success({
              'points': 250,
              'tier': {'name': 'عضو باشگاه'},
              'credit': {'amount': '100000'}
            });
          }
          return success({'items': [], 'pagination': {}});
        }));
    await api.restore();
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('preview'), child: BonyeApp(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Hello مریم'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await capture(tester, 'home-en');
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Club')));
    await tester.pumpAndSettle();
    expect(find.text('Your points'), findsOneWidget);
    await capture(tester, 'club-en');
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('My pets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add pet'));
    await tester.pumpAndSettle();
    expect(find.byType(PetForm), findsOneWidget);
    expect(find.text('Pet’s name'), findsOneWidget);
    final petType = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first);
    expect(petType.initialValue, 'dog');
    expect(find.text('Dog'), findsWidgets);
    // Existing nested routes and fields must also rebuild when locale changes.
    await appLanguage.select('fa');
    await tester.pumpAndSettle();
    expect(find.text('نام پت'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(PetForm))),
        TextDirection.rtl);
    await appLanguage.select('en');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Luna');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(submittedPet?['species'], 'dog');
    expect(submittedPet?['name'], 'Luna');
    expect(submittedPet?['life_stage'], 'adult');
    await tester.tap(find.text('My account'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('09121234567'), findsWidgets);
    expect(find.text('مریم'), findsWidgets);
    expect(find.text('App language'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets(
      'small-screen login and large text have no overflow in either language',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = BonyeApi(
        tokens: MemoryTokens(),
        client: MockClient((_) async => failure('api_disabled', 503)));
    await api.restore();
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final code in ['fa', 'en']) {
      await appLanguage.select(code);
      await tester.pumpWidget(BonyeApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
