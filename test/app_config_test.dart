import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/config/app_config.dart';

void main() {
  group('password recovery deep link', () {
    test('accepts the configured MyFind callback', () {
      final uri = Uri.parse(
        'io.myfind.app://reset-password?code=recovery-code',
      );

      expect(AppConfig.isPasswordResetLink(uri), isTrue);
    });

    test('does not mistake the Supabase fallback site for the app callback', () {
      final uri = Uri.parse('http://localhost:3000');

      expect(AppConfig.isPasswordResetLink(uri), isFalse);
    });
  });
}
