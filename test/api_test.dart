import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bonye_customer/core/api.dart';

class MemoryTokens implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

Json session({
  bool expired = false,
  String access = 'access',
  String refresh = 'refresh',
}) =>
    {
      'access_token': access,
      'refresh_token': refresh,
      'access_expires_at': DateTime.now()
          .toUtc()
          .add(Duration(minutes: expired ? -1 : 15))
          .toIso8601String(),
      'refresh_expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String(),
    };
http.Response success(Json data) => http.Response(
      jsonEncode({
        'data': data,
        'meta': {'api_version': '1'},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
http.Response failure(String code, int status) => http.Response(
      jsonEncode({
        'error': {'code': code},
        'meta': {'request_id': 'test-id'},
      }),
      status,
    );

void main() {
  test(
    'password whitespace is preserved; Persian mobile digits normalize',
    () async {
      final store = MemoryTokens();
      final api = BonyeApi(
        tokens: store,
        client: MockClient((req) async {
          final b = jsonDecode(req.body) as Json;
          expect(req.url.path, '/totallsystem/api/v1/auth/login');
          expect(b['password'], ' secret with spaces ');
          expect(b['mobile'], '09121234567');
          return success(session());
        }),
      );
      await api.login('۰۹۱۲۱۲۳۴۵۶۷', ' secret with spaces ');
      expect(api.signedIn, isTrue);
      expect(store.value, isNotNull);
      api.dispose();
    },
  );
  test('concurrent expired requests share one refresh', () async {
    final store = MemoryTokens()..value = jsonEncode(session(expired: true));
    var rotations = 0;
    final gate = Completer<void>();
    final api = BonyeApi(
      tokens: store,
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          rotations++;
          await gate.future;
          return success(session(access: 'new-access', refresh: 'new-refresh'));
        }
        expect(req.headers['Authorization'], 'Bearer new-access');
        return success({'items': []});
      }),
    );
    await api.restore();
    final one = api.request('GET', '/pets');
    final two = api.request('GET', '/orders');
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([one, two]);
    expect(rotations, 1);
    api.dispose();
  });
  test(
    'lost refresh response destroys old token and does not retry it',
    () async {
      final store = MemoryTokens()..value = jsonEncode(session(expired: true));
      var requests = 0;
      final api = BonyeApi(
        tokens: store,
        client: MockClient((req) async {
          requests++;
          throw http.ClientException('offline');
        }),
      );
      await api.restore();
      await expectLater(
        api.request('GET', '/pets'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'refresh_failed'),
        ),
      );
      expect(api.signedIn, isFalse);
      expect(store.value, isNull);
      await expectLater(api.request('GET', '/pets'), throwsA(isA<ApiError>()));
      expect(requests, 1);
      api.dispose();
    },
  );
  test('write replay after 401 retains idempotency key and payload', () async {
    final store = MemoryTokens()..value = jsonEncode(session());
    final keys = <String?>[];
    final bodies = <String>[];
    var writes = 0;
    final api = BonyeApi(
      tokens: store,
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return success(session(access: 'new'));
        }
        keys.add(req.headers['Idempotency-Key']);
        bodies.add(req.body);
        writes++;
        return writes == 1
            ? failure('session_expired', 401)
            : success({'id': 1});
      }),
    );
    await api.restore();
    await api.request(
      'POST',
      '/pets',
      body: {'name': 'میشا', 'species': 'cat'},
      key: 'stable-operation-123456',
    );
    expect(keys, ['stable-operation-123456', 'stable-operation-123456']);
    expect(bodies[0], bodies[1]);
    api.dispose();
  });
  test(
    'late 401 responses do not rotate the already rotated session again',
    () async {
      final store = MemoryTokens()..value = jsonEncode(session());
      var rotations = 0;
      final gate = Completer<void>();
      final api = BonyeApi(
        tokens: store,
        client: MockClient((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            rotations++;
            return success(session(access: 'new'));
          }
          if (req.headers['Authorization'] == 'Bearer access') {
            if (req.url.path.endsWith('/orders')) {
              await gate.future;
            }
            return failure('session_expired', 401);
          }
          if (!gate.isCompleted) {
            gate.complete();
          }
          return success({'items': []});
        }),
      );
      await api.restore();
      await Future.wait([
        api.request('GET', '/pets'),
        api.request('GET', '/orders'),
      ]);
      expect(rotations, 1);
      api.dispose();
    },
  );
  test(
    '503 and 429 remain actionable and are never automatically replayed',
    () async {
      var count = 0;
      final api = BonyeApi(
        tokens: MemoryTokens(),
        client: MockClient((req) async {
          count++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'otp_cooldown'},
            }),
            429,
            headers: {'retry-after': '60'},
          );
        }),
      );
      await expectLater(
        api.challenge('09121234567', 'login'),
        throwsA(isA<ApiError>().having((e) => e.retryAfter, 'retryAfter', 60)),
      );
      expect(count, 1);
      api.dispose();
    },
  );
  test('HTML response is rejected without leaking it into the UI', () async {
    final api = BonyeApi(
      tokens: MemoryTokens(),
      client: MockClient(
        (req) async => http.Response('<html>internal error</html>', 502),
      ),
    );
    await expectLater(
      api.login('09121234567', 'secret'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'invalid_response'),
      ),
    );
    api.dispose();
  });
}
