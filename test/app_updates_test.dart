import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bonye_customer/core/app_updates.dart';

Map<String, dynamic> manifest(int build) => {
      'package_name': androidPackage,
      'signer_sha256': androidSigner,
      'version': '0.2.3',
      'version_code': build,
      'apk_url': 'https://bonye.pet/app/downloads/bonYe-v0.2.3-$build.apk',
      'sha256': List.filled(64, 'a').join(),
      'size_bytes': 1024,
    };
Future<PackageInfo> installed() async => PackageInfo(
    appName: 'bonYe!',
    packageName: androidPackage,
    version: '0.2.2',
    buildNumber: '5');
void main() {
  testWidgets(
      'opening update page does not notify ancestors during navigation build',
      (tester) async {
    final updates = AppUpdates(
        installed: installed,
        client: MockClient(
            (_) async => http.Response(jsonEncode(manifest(6)), 200)));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => UpdateScope(
          updates: updates,
          child: ListenableBuilder(
              listenable: updates, builder: (_, __) => child!)),
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Open updates'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => UpdatePage(updates: updates)))),
              )),
    ));
    await tester.tap(find.text('Open updates'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('دریافت آپدیت'), findsOneWidget);
    expect(updates.release?.build, 6);
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
  });
  test('new build is offered; same or lower build is not', () async {
    for (final build in [4, 5, 6]) {
      final updates = AppUpdates(
          installed: installed,
          client: MockClient((request) async {
            expect(request.url.host, 'bonye.pet');
            expect(request.headers.containsKey('authorization'), false);
            expect(request.url.queryParameters.containsKey('check'), true);
            return http.Response(jsonEncode(manifest(build)), 200);
          }));
      await updates.check();
      expect(updates.failed, false);
      expect(updates.release?.build, build > 5 ? build : null);
      updates.dispose();
    }
  });
  test('foreign links, wrong signer, and wrong package are rejected', () {
    for (final change in [
      {'apk_url': 'https://evil.example/app/downloads/bonYe-v0.2.3-6.apk'},
      {'apk_url': 'http://bonye.pet/app/downloads/bonYe-v0.2.3-6.apk'},
      {
        'apk_url':
            'https://bonye.pet/app/downloads/bonYe-v0.2.3-6.apk?redirect=x'
      },
      {'package_name': 'another.app'},
      {'signer_sha256': 'wrong'},
      {'version_code': -1},
      {'sha256': 'bad'}
    ]) {
      expect(() => AndroidRelease.parse({...manifest(6), ...change}),
          throwsFormatException);
    }
  });
  test('single flight, hourly throttle, forced retry and transient failure',
      () async {
    final pending = Completer<http.Response>();
    int calls = 0;
    final updates = AppUpdates(
        installed: installed,
        client: MockClient((request) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(http.Response('error', 503));
        }));
    final first = updates.check();
    final second = updates.check(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(http.Response(jsonEncode(manifest(6)), 200));
    await Future.wait([first, second]);
    updates.dismiss();
    await updates.check();
    expect(calls, 1);
    await updates.check(force: true);
    expect(calls, 2);
    expect(updates.failed, true);
    expect(updates.release?.build, 6);
    expect(updates.dismissed, true);
    updates.dispose();
  });
}
