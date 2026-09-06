import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/passport_details_parser.dart';
import 'package:my_find/core/validators/validators.dart';

void main() {
  test('reads standard TD3 MRZ with checked number and expiry', () {
    final result = PassportDetailsParser.parse(
      '${'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<')}\n'
      'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
    );
    expect(result.number, 'L898902C3');
    expect(result.name, 'ERIKSSON ANNA MARIA');
    expect(result.nationality, 'UTO');
    expect(result.issuingCountry, 'UTO');
    expect(result.expiryDate, DateTime(2012, 4, 15));
    expect(result.issueDate, isNull);
  });
  test('rejects corrupted MRZ number and leaves missing fields empty', () {
    final result = PassportDetailsParser.parse(
      '${'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<')}\n'
      'L898902C37UTO7408122F1204159ZE184226B<<<<<10',
    );
    expect(result.number, isNull);
    expect(result.name, isNull);
  });
  test('reads explicitly labelled passport number and dates', () {
    final result = PassportDetailsParser.parse(
      'Passport No: C03005988\nDate of issue: 01/02/2025\n'
      'Date of expiry: 2030-02-01',
    );
    expect(result.number, 'C03005988');
    expect(result.issueDate, DateTime(2025, 2, 1));
    expect(result.expiryDate, DateTime(2030, 2, 1));
  });
  test('does not invent details or normalize impossible dates', () {
    final result = PassportDetailsParser.parse('Date of issue: 31/02/2025');
    expect(result.number, isNull);
    expect(result.issueDate, isNull);
  });
  test('MyKad gender validates odd, even, mismatch, missing and malformed', () {
    expect(Validators.myKadGender('900101-14-5567', 'male'), isNull);
    expect(Validators.myKadGender('900101-14-5566', 'female'), isNull);
    expect(Validators.myKadGender('900101-14-5567', 'female'), isNotNull);
    expect(Validators.myKadGender('900101-14-5566', null), isNotNull);
    expect(Validators.myKadGender('123', 'male'), isNotNull);
  });
}
