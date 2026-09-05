import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/services/document_duplicate_service.dart';
import 'package:my_find/core/exceptions/app_exceptions.dart';

void main() {
  late Directory temp;
  late File first;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('m400-duplicates-test-');
    first = await File('${temp.path}/test.jpg').writeAsBytes([1, 2, 3, 4]);
  });
  tearDown(() async => temp.delete(recursive: true));
  test(
    'renaming a file retains its fingerprint; different bytes differ',
    () async {
      final renamed = await first.copy('${temp.path}/renamed.jpg');
      final different = await File(
        '${temp.path}/different.jpg',
      ).writeAsBytes([4, 3, 2, 1]);
      expect(
        await DocumentDuplicateService.fingerprint(first),
        await DocumentDuplicateService.fingerprint(renamed),
      );
      expect(
        await DocumentDuplicateService.fingerprint(first),
        isNot(await DocumentDuplicateService.fingerprint(different)),
      );
    },
  );
  for (final available in [true, false]) {
    test('database availability $available is respected', () async {
      final client = SupabaseClient(
        'http://localhost:1234',
        'test-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/module400_registration_document_available',
          );
          expect(request.body, contains('p_fingerprint'));
          return http.Response(
            '$available',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final action = DocumentDuplicateService(
        client: client,
      ).ensureAvailable(first);
      if (available) {
        await expectLater(action, completes);
      } else {
        await expectLater(
          action,
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              DocumentDuplicateService.duplicateMessage,
            ),
          ),
        );
      }
    });
  }
  test('missing database migration fails closed with a setup error', () async {
    final client = SupabaseClient(
      'http://localhost:1234',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"code":"PGRST202","message":"Missing function"}',
          404,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      DocumentDuplicateService(client: client).ensureAvailable(first),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('not configured'),
        ),
      ),
    );
  });
}
