import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/core/validators/validators.dart';

void main() {
  group('Module 400 validators', () {
    test('accepts valid Citizen and Tourist identity numbers', () {
      expect(Validators.malaysianIC('900101-14-5566'), isNull);
      expect(Validators.passportNumber('A1234567'), isNull);
      expect(Validators.passportNumber('C03005988'), isNull);
    });

    test('rejects malformed identity numbers', () {
      expect(Validators.malaysianIC('123'), isNotNull);
      expect(Validators.passportNumber('ABC!'), isNotNull);
      expect(Validators.passportNumber('A1234'), isNotNull);
    });

    test('requires a strong matching password', () {
      const password = 'Secure1!';
      expect(Validators.password(password), isNull);
      expect(Validators.password('weak'), isNotNull);
      expect(Validators.confirmPassword(password, password), isNull);
      expect(Validators.confirmPassword('Different1!', password), isNotNull);
    });

    test('validates email format', () {
      expect(Validators.email('citizen@example.com'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
    });
  });
}
