import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  SecureTokenStore({this.storage = const FlutterSecureStorage()});
  @override
  Future<String?> read() => storage.read(key: 'bonye.session.v1');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'bonye.session.v1', value: value);
  @override
  Future<void> clear() => storage.delete(key: 'bonye.session.v1');
}

class ApiError implements Exception {
  final String code;
  final int status;
  final String? requestId;
  final int? retryAfter;
  ApiError(this.code, {this.status = 0, this.requestId, this.retryAfter});
  String get message {
    const messages = <String, String>{
      'api_disabled': 'API اپ هنوز در بنیه فعال نشده است.',
      'migration_required': 'ارتقای پایگاه داده باید در بنیه تکمیل شود.',
      'sms_not_configured':
          'ارسال پیامک هنوز آماده نیست؛ از ورود با رمز استفاده کنید.',
      'auth_method_disabled': 'این روش ورود غیرفعال است.',
      'otp_login_disabled': 'ورود پیامکی غیرفعال است.',
      'recovery_disabled': 'بازیابی رمز غیرفعال است.',
      'database_unavailable': 'پایگاه داده موقتاً در دسترس نیست.',
      'recovery_required': 'برای این حساب ابتدا رمز را بازیابی کنید.',
      'registration_disabled': 'ثبت‌نام هنوز فعال نشده است.',
      'invalid_credentials': 'شماره موبایل یا رمز درست نیست.',
      'mobile_verification_required': 'شماره موبایل باید تأیید شود.',
      'otp_required': 'برای ورود به این حساب کد پیامکی لازم است.',
      'invalid_otp': 'کد معتبر نیست یا مهلت آن تمام شده است.',
      'invalid_challenge': 'کد معتبر نیست یا مهلت آن تمام شده است.',
      'feeding_disabled': 'داده تغذیه‌ای تأییدشده هنوز آماده نیست.',
      'feeding_review_required':
          'برنامه غذایی هنوز برای استفاده عمومی تأیید و فعال نشده است.',
      'password_policy':
          'رمز جدید باید ۱۲ تا ۷۲ بایت باشد؛ یک رمز طولانی‌تر انتخاب کنید.',
      'sms_delivery_failed':
          'ارسال کد انجام نشد؛ پس از کمی انتظار دوباره تلاش کنید.',
      'nutrition_data_required': 'داده تغذیه‌ای تأییدشده هنوز آماده نیست.',
      'veterinary_guidance_required':
          'برای شرایط این پت، راهنمایی دامپزشک لازم است.',
      'podcast_not_configured': 'پادکست هنوز در سایت تنظیم نشده است.',
      'session_expired': 'نشست شما پایان یافت؛ دوباره وارد شوید.',
      'refresh_failed': 'نشست شما پایان یافت؛ دوباره وارد شوید.',
      'network_error': 'ارتباط برقرار نشد؛ اتصال اینترنت را بررسی کنید.',
      'invalid_response': 'پاسخ سرور قابل خواندن نیست.',
    };
    if (messages.containsKey(code)) {
      return messages[code]!;
    }
    switch (status) {
      case 401:
        return 'برای ادامه دوباره وارد شوید.';
      case 403:
        return 'این عملیات برای حساب شما مجاز نیست.';
      case 404:
        return 'اطلاعات موردنظر پیدا نشد.';
      case 409:
        return 'اطلاعات تغییر کرده است؛ صفحه را تازه کنید.';
      case 422:
      case 400:
        return 'اطلاعات واردشده را بررسی کنید.';
      case 429:
        return 'درخواست‌ها زیاد شده؛ ${retryAfter ?? 60} ثانیه دیگر تلاش کنید.';
      case 503:
        return 'این سرویس فعلاً آماده نیست.';
      default:
        return 'عملیات انجام نشد؛ دوباره تلاش کنید.';
    }
  }

  @override
  String toString() => message;
}

String operationKey() => List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
String normalizeDigits(String value) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return value;
}

class BonyeApi extends ChangeNotifier {
  static const defaultBase = 'https://bonye.pet/totallsystem/api/v1';
  final String base;
  final http.Client client;
  final TokenStore tokens;
  Json? _session;
  Future<void>? _refreshing;
  bool restored = false;
  bool get signedIn => _session != null;
  BonyeApi({
    this.base = const String.fromEnvironment(
      'BONYE_API_BASE',
      defaultValue: defaultBase,
    ),
    http.Client? client,
    TokenStore? tokens,
  })  : client = client ?? http.Client(),
        tokens = tokens ?? SecureTokenStore() {
    if (Uri.parse(base).scheme != 'https') {
      throw ArgumentError('API requires HTTPS');
    }
  }
  Future<void> restore() async {
    try {
      final saved = await tokens.read();
      if (saved != null) {
        final parsed = jsonDecode(saved) as Json;
        if (DateTime.parse(
          parsed['refresh_expires_at'] as String,
        ).isAfter(DateTime.now().toUtc())) {
          _session = parsed;
        } else {
          await tokens.clear();
        }
      }
    } catch (_) {
      await tokens.clear();
    }
    restored = true;
    notifyListeners();
  }

  Future<void> _setSession(Json data) async {
    await tokens.write(jsonEncode(data));
    _session = data;
    notifyListeners();
  }

  Future<void> forget() async {
    _session = null;
    await tokens.clear();
    notifyListeners();
  }

  Future<Json> _send(
    String method,
    String path, {
    Json? body,
    String? key,
    String? access,
  }) async {
    final req = http.Request(
      method,
      Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}$path'),
    );
    req.headers['Accept'] = 'application/json';
    if (access != null) {
      req.headers['Authorization'] = 'Bearer $access';
    }
    if (key != null) {
      req.headers['Idempotency-Key'] = key;
    }
    if (method != 'GET') {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body ?? <String, dynamic>{});
    }
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiError('network_error');
    }
    Json envelope;
    try {
      envelope = jsonDecode(response.body) as Json;
    } catch (_) {
      throw ApiError('invalid_response', status: response.statusCode);
    }
    if (response.statusCode >= 400) {
      throw ApiError(
        envelope['error']?['code'] as String? ?? 'server_error',
        status: response.statusCode,
        requestId: envelope['meta']?['request_id'] as String?,
        retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }
    if (envelope['data'] is! Map<String, dynamic>) {
      throw ApiError('invalid_response');
    }
    return envelope['data'] as Json;
  }

  Future<void> _refresh() =>
      _refreshing ??= _rotate().whenComplete(() => _refreshing = null);
  Future<void> _rotate() async {
    final refresh = _session?['refresh_token'] as String?;
    if (refresh == null) {
      throw ApiError('session_expired', status: 401);
    }
    // Consume before sending: a lost response must never cause old-token reuse.
    _session = null;
    try {
      await tokens.clear();
      final next = await _send(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': refresh},
      );
      await _setSession(next);
    } catch (_) {
      await forget();
      throw ApiError('refresh_failed', status: 401);
    }
  }

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? key,
  }) async {
    if (_refreshing != null) {
      await _refreshing;
    }
    if (!signedIn) {
      throw ApiError('session_expired', status: 401);
    }
    final expires = DateTime.tryParse(
      _session?['access_expires_at'] as String? ?? '',
    );
    if (expires == null ||
        expires.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        )) {
      await _refresh();
    }
    final writeKey = method == 'GET' || path.startsWith('/auth/')
        ? null
        : key ?? operationKey();
    final access = _session?['access_token'] as String?;
    try {
      return await _send(
        method,
        path,
        body: body,
        key: writeKey,
        access: access,
      );
    } on ApiError catch (e) {
      if (e.status != 401) {
        rethrow;
      }
      if (_refreshing != null) {
        await _refreshing;
      } else if (_session?['access_token'] == access) {
        await _refresh();
      }
      if (!signedIn) {
        throw ApiError('session_expired', status: 401);
      }
      final rotatedAccess = _session?['access_token'] as String?;
      try {
        return await _send(
          method,
          path,
          body: body,
          key: writeKey,
          access: rotatedAccess,
        );
      } on ApiError catch (next) {
        if (next.status == 401) {
          await forget();
        }
        rethrow;
      }
    }
  }

  Future<void> login(String mobile, String password) async {
    await _setSession(
      await _send(
        'POST',
        '/auth/login',
        body: {
          'mobile': normalizeDigits(mobile.trim()),
          'password': password,
          'device_name': kIsWeb ? 'bonYe Web' : 'bonYe Android',
        },
      ),
    );
  }

  Future<Json> challenge(String mobile, String purpose) => _send(
        'POST',
        '/auth/otp/request',
        body: {'mobile': normalizeDigits(mobile.trim()), 'purpose': purpose},
      );
  Future<void> verify(
    String challenge,
    String code, {
    String? name,
    String? password,
  }) async {
    await _setSession(
      await _send(
        'POST',
        '/auth/otp/verify',
        body: {
          'challenge_id': challenge,
          'code': normalizeDigits(code.trim()),
          'device_name': kIsWeb ? 'bonYe Web' : 'bonYe Android',
          if (name != null) 'name': name,
          if (password != null) 'new_password': password,
        },
      ),
    );
  }

  Future<void> logout() async {
    try {
      await request('POST', '/auth/logout');
    } finally {
      await forget();
    }
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
