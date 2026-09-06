import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/services/identity_number_service.dart';
import 'package:my_find/core/exceptions/app_exceptions.dart';

void main() {
  for (final role in ['citizen', 'tourist']) {
    for (final available in [true, false]) {
      test(
        '$role availability=$available is checked with normalized number',
        () async {
          final client = SupabaseClient(
            'https://project.example.test',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              expect(
                request.url.path,
                '/rest/v1/rpc/module400_registration_identity_available',
              );
              expect(jsonDecode(request.body), {
                'p_role': role,
                'p_identity_number': role == 'citizen'
                    ? '900101145566'
                    : 'C03005988',
              });
              return http.Response(
                '$available',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }),
          );
          addTearDown(client.dispose);
          final action = IdentityNumberService(client: client).ensureAvailable(
            role: role,
            number: role == 'citizen' ? '900101-14-5566' : 'c03005988',
          );
          await expectLater(
            action,
            available
                ? completes
                : throwsA(
                    isA<AppException>().having(
                      (e) => e.code,
                      'code',
                      'identity_already_registered',
                    ),
                  ),
          );
        },
      );
    }
  }

  for (final response in [
    (404, '{"code":"PGRST202","message":"Missing function"}'),
    (403, '{"code":"42501","message":"Permission denied"}'),
    (200, 'null'),
    (200, '[]'),
    (200, '"true"'),
  ]) {
    test('lookup fails closed for $response', () async {
      final client = SupabaseClient(
        'https://project.example.test',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            response.$2,
            response.$1,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        IdentityNumberService(
          client: client,
        ).ensureAvailable(role: 'citizen', number: '900101145566'),
        throwsA(isA<AppException>()),
      );
    });
  }

  test('normalized unique index violations produce a useful message', () {
    for (final key in ['ic_number', 'passport_number']) {
      final error = ExceptionMapper.map(
        PostgrestException(
          code: '23505',
          message:
              'duplicate key value violates unique constraint module400_${key}_normalized_key',
        ),
      );
      expect(error.message, contains('already registered'));
      expect(error.message, isNot(contains('This record')));
    }
  });
}
