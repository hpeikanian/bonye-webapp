import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'language.dart';
import 'widgets.dart';

const androidPackage = 'pet.bonye.customer';
const androidSigner =
    'ea2c98d85ab41af5ef356940d6df2a9bc01f3effa415afae4c142a25b592ce19';
final updateEndpoint = Uri.parse('https://bonye.pet/app/android-update.json');

class AndroidRelease {
  final int build;
  final String version;
  final Uri url;
  AndroidRelease(this.build, this.version, this.url);

  factory AndroidRelease.parse(Map<String, dynamic> data) {
    final url = Uri.parse(data['apk_url'] as String);
    final build = data['version_code'];
    final version = data['version'];
    if (data['package_name'] != androidPackage ||
        data['signer_sha256'] != androidSigner ||
        build is! int ||
        build < 1 ||
        version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        url.scheme != 'https' ||
        url.host != updateEndpoint.host ||
        url.port != 443 ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !RegExp(r'^/app/downloads/bonYe-v\d+\.\d+\.\d+-\d+\.apk$')
            .hasMatch(url.path) ||
        url.path != '/app/downloads/bonYe-v$version-$build.apk' ||
        data['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['sha256'] as String) ||
        data['size_bytes'] is! int ||
        (data['size_bytes'] as int) < 1) {
      throw const FormatException('Invalid Android update manifest');
    }
    return AndroidRelease(build, version, url);
  }
}

class AppUpdates extends ChangeNotifier {
  AppUpdates({http.Client? client, Future<PackageInfo> Function()? installed})
      : _client = client ?? http.Client(),
        _installed = installed ?? PackageInfo.fromPlatform;
  final http.Client _client;
  final Future<PackageInfo> Function() _installed;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AndroidRelease? release;
  String? installedVersion;
  bool checking = false, failed = false, checked = false, dismissed = false;
  bool _disposed = false;
  DateTime? _lastAttempt;
  Future<void>? _pending;

  Future<void> check({bool force = false}) {
    if (_disposed) return Future.value();
    if (_pending != null) return _pending!;
    if (!force &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(hours: 1)) {
      return Future.value();
    }
    _pending = _check().whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<void> _check() async {
    checking = true;
    failed = false;
    _lastAttempt = DateTime.now();
    _notify();
    try {
      final info = await _installed();
      installedVersion = info.version;
      final installedBuild = int.parse(info.buildNumber);
      if (info.packageName != androidPackage) throw const FormatException();
      final response = await _client.get(
          updateEndpoint.replace(queryParameters: {
            'check': DateTime.now().millisecondsSinceEpoch.toString()
          }),
          headers: {
            'Cache-Control': 'no-cache'
          }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 16384) {
        throw const FormatException();
      }
      final candidate = AndroidRelease.parse(
          jsonDecode(response.body) as Map<String, dynamic>);
      if (candidate.build > installedBuild) {
        if (release?.build != candidate.build) dismissed = false;
        release = candidate;
      } else {
        release = null;
      }
      checked = true;
    } catch (_) {
      // A failed check must not block login, checkout or the existing app.
      failed = true;
    } finally {
      checking = false;
      _notify();
    }
  }

  void dismiss() {
    dismissed = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

class UpdateScope extends InheritedNotifier<AppUpdates> {
  const UpdateScope(
      {super.key, required AppUpdates updates, required super.child})
      : super(notifier: updates);
  static AppUpdates of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UpdateScope>()!.notifier!;
}

class UpdateHost extends StatefulWidget {
  const UpdateHost({super.key, required this.child, required this.navigator});
  final Widget child;
  final GlobalKey<NavigatorState> navigator;
  @override
  State<UpdateHost> createState() => _UpdateHostState();
}

class _UpdateHostState extends State<UpdateHost> with WidgetsBindingObserver {
  final updates = AppUpdates();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AppUpdates.supported) unawaited(updates.check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppUpdates.supported && state == AppLifecycleState.resumed) {
      unawaited(updates.check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UpdateScope(
        updates: updates,
        child: ListenableBuilder(
            listenable: updates,
            builder: (context, _) => Column(
                  children: [
                    if (AppUpdates.supported &&
                        updates.release != null &&
                        !updates.dismissed)
                      Material(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(start: 16),
                              child: Row(children: [
                                const Expanded(
                                    child: AppText('نسخه جدید اپ آماده است.')),
                                TextButton(
                                    onPressed: () => widget
                                        .navigator.currentState
                                        ?.push(MaterialPageRoute<void>(
                                            builder: (_) =>
                                                UpdatePage(updates: updates))),
                                    child: const AppText('به‌روزرسانی')),
                                IconButton(
                                    tooltip: tr('بعداً'),
                                    onPressed: updates.dismiss,
                                    icon: const Icon(Icons.close)),
                              ]),
                            )),
                      ),
                    Expanded(child: widget.child),
                  ],
                )),
      );
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.updates});
  final AppUpdates updates;
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.updates.check(force: true));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('به‌روزرسانی اپ')),
        body: ListenableBuilder(
            listenable: widget.updates,
            builder: (context, _) {
              final updates = widget.updates;
              return PageBody(children: [
                if (updates.installedVersion != null)
                  Text('${tr('نسخه نصب‌شده')}: ${updates.installedVersion}',
                      textDirection: TextDirection.ltr),
                if (updates.checking) const LinearProgressIndicator(),
                if (updates.failed)
                  const AppText('بررسی نسخه ممکن نشد؛ دوباره تلاش کنید.'),
                if (updates.release != null) ...[
                  Text('${tr('نسخه جدید')}: ${updates.release!.version}',
                      textDirection: TextDirection.ltr),
                  const AppText(
                      'فایل آپدیت در مرورگر دانلود می‌شود. پس از دانلود، فایل را باز و نصب را تأیید کنید. حذف اپ لازم نیست.'),
                  FilledButton.icon(
                      onPressed: () async {
                        try {
                          await externalLink(updates.release!.url.toString());
                        } catch (error) {
                          if (context.mounted) showError(context, error);
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const AppText('دریافت آپدیت')),
                ] else if (updates.checked &&
                    !updates.failed &&
                    !updates.checking)
                  const AppText('اپ شما به‌روز است.'),
                OutlinedButton(
                    onPressed: updates.checking
                        ? null
                        : () => updates.check(force: true),
                    child: const AppText('بررسی نسخه جدید')),
              ]);
            }),
      );
}
