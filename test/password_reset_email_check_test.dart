import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/services/auth_service.dart';
import 'package:my_find/core/exceptions/app_exceptions.dart';

class MemoryRecoveryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reset lookup transport returns a scalar eligibility result', () async {
    final client = SupabaseClient(
      'https://project.example.test',
      'test-anon-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryRecoveryStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          '"eligible"',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    expect(
      await client.rpc(
        'module400_password_reset_eligibility',
        params: {'p_email': 'member@example.test'},
      ),
      'eligible',
    );
  });
  for (final entry in {
    'not_registered': 'reset_email_not_registered',
    'not_active': 'reset_account_not_active',
    'admin_portal': 'reset_admin_portal_required',
  }.entries) {
    test('${entry.key} is rejected without requesting an email', () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://project.example.test',
        'test-anon-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MemoryRecoveryStorage(),
        ),
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(jsonDecode(request.body), {'p_email': 'member@example.test'});
          return http.Response(
            jsonEncode(entry.key),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        AuthService(
          client: client,
        ).sendPasswordResetEmail(' MEMBER@EXAMPLE.TEST '),
        throwsA(isA<AppException>().having((e) => e.code, 'code', entry.value)),
      );
      expect(paths, ['/rest/v1/rpc/module400_password_reset_eligibility']);
    });
  }

  for (final rateLimited in [false, true]) {
    test('registered account: provider rate-limited=$rateLimited', () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://project.example.test',
        'test-anon-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MemoryRecoveryStorage(),
        ),
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.contains('/rpc/')) {
            return http.Response(
              '"eligible"',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(request.url.path, '/auth/v1/recover');
          expect(jsonDecode(request.body)['email'], 'member@example.test');
          expect(jsonDecode(request.body)['code_challenge_method'], 's256');
          expect(jsonDecode(request.body)['code_challenge'], isNotEmpty);
          return http.Response(
            rateLimited ? '{"msg":"email rate limit exceeded"}' : '{}',
            rateLimited ? 429 : 200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final request = AuthService(
        client: client,
      ).sendPasswordResetEmail(' MEMBER@EXAMPLE.TEST ');
      if (rateLimited) {
        await expectLater(
          request,
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'reset_email_rate_limit',
            ),
          ),
        );
      } else {
        await request;
      }
      expect(paths, [
        '/rest/v1/rpc/module400_password_reset_eligibility',
        '/auth/v1/recover',
      ]);
    });
  }

  test('missing database function never falls back to sending', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'test-anon-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryRecoveryStorage(),
      ),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '{"code":"PGRST202","message":"Function not found"}',
          404,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      AuthService(client: client).sendPasswordResetEmail('member@example.test'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'reset_email_check_not_configured',
        ),
      ),
    );
    expect(paths, ['/rest/v1/rpc/module400_password_reset_eligibility']);
  });
}
