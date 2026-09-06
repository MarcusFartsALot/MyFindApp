import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/passport_details_parser.dart';

void main() {
  test(
    'reads MRZ fields when trailing filler characters are cropped by OCR',
    () {
      final details = PassportDetailsParser.parse(
        'P<UTOERIKSSON<<ANNA<MARIA\nL898902C36UTO7408122F1204159',
      );
      expect(details.issuingCountry, 'UTO');
      expect(details.expiryDate, DateTime(2012, 4, 15));
      expect(details.issueDate, isNull);
    },
  );
  test(
    'expiry has its own checksum and does not depend on the number checksum',
    () {
      final details = PassportDetailsParser.parse(
        'P<UTOERIKSSON<<ANNA<MARIA\nL898902C37UTO7408122F1204159',
      );
      expect(details.number, isNull);
      expect(details.issuingCountry, 'UTO');
      expect(details.expiryDate, DateTime(2012, 4, 15));
      final badExpiry = PassportDetailsParser.parse(
        'P<UTOERIKSSON<<ANNA<MARIA\nL898902C36UTO7408122F1204158',
      );
      expect(badExpiry.expiryDate, isNull);
    },
  );
  test('supports country code and bilingual abbreviated printed dates', () {
    final details = PassportDetailsParser.parse(
      'PASSPORT\nCOUNTRY CODE: MYS\nDATE OF ISSUE / DATE DE DÉLIVRANCE\n16 APR / AVR 25\n'
      'DATE OF EXPIRATION: 16 APR / AVR 2030',
    );
    expect(details.issuingCountry, 'MYS');
    expect(details.issueDate, DateTime(2025, 4, 16));
    expect(details.expiryDate, DateTime(2030, 4, 16));
  });
  test('reads English month names and country on the following line', () {
    final details = PassportDetailsParser.parse(
      'PASSPORT\nISSUING COUNTRY\nMALAYSIA\n'
      'DATE OF ISSUE\n02 JAN 2025\nDATE OF EXPIRY: 02 JANUARY 2030',
    );
    expect(details.issuingCountry, 'MALAYSIA');
    expect(details.issueDate, DateTime(2025, 1, 2));
    expect(details.expiryDate, DateTime(2030, 1, 2));
  });

  test('reads bilingual captions, Malay months and dotted dates', () {
    final details = PassportDetailsParser.parse(
      'TARIKH DIKELUARKAN / DATE OF ISSUE: 23 MAC/MAR 2025\n'
      'TARIKH TAMAT: 23.03.2030\nCODE OF ISSUING STATE: MYS',
    );
    expect(details.issueDate, DateTime(2025, 3, 23));
    expect(details.expiryDate, DateTime(2030, 3, 23));
    expect(details.issuingCountry, 'MYS');
  });

  test('missing issue date never borrows birth or expiry date', () {
    for (final text in [
      'DATE OF ISSUE\nDATE OF BIRTH: 02 JAN 1999\nDATE OF EXPIRY: 02 JAN 2030',
      'DATE OF ISSUE DATE OF BIRTH 02 JAN 1999\nDATE OF EXPIRY 02 JAN 2030',
      'DATE OF BIRTH 02 JAN 1999\nDATE OF EXPIRY 02 JAN 2030',
    ]) {
      final details = PassportDetailsParser.parse(text);
      expect(details.issueDate, isNull);
      expect(details.expiryDate, DateTime(2030, 1, 2));
    }
  });

  test('rejects impossible printed dates, including non-leap February', () {
    expect(
      PassportDetailsParser.parse('ISSUE DATE 29 FEB 2025').issueDate,
      isNull,
    );
    expect(
      PassportDetailsParser.parse('ISSUE DATE 29 FEB 2024').issueDate,
      DateTime(2024, 2, 29),
    );
    expect(
      PassportDetailsParser.parse('DATE OF EXPIRY 31/04/2030').expiryDate,
      isNull,
    );
  });

  final firstScan = PassportDetails(
    number: 'C03005988',
    name: 'OCR NAME',
    nationality: 'MYS',
    issueDate: DateTime(2025, 1, 2),
    expiryDate: DateTime(2030, 1, 2),
    issuingCountry: 'MYS',
  );

  test('only the three requested fields are autofilled', () {
    final merged = PassportDetailsParser.mergeAutofill(
      current: const PassportDetails(
        number: 'MANUAL123',
        name: 'Manual Name',
        nationality: 'Malaysian',
      ),
      scanned: firstScan,
    );
    expect(merged.issueDate, firstScan.issueDate);
    expect(merged.expiryDate, firstScan.expiryDate);
    expect(merged.issuingCountry, 'MYS');
    expect(merged.number, 'MANUAL123');
    expect(merged.name, 'Manual Name');
    expect(merged.nationality, 'Malaysian');
  });

  test('retake refreshes OCR fields and keeps manual corrections', () {
    final secondScan = PassportDetails(
      issueDate: DateTime(2026, 3, 4),
      expiryDate: DateTime(2031, 3, 4),
      issuingCountry: 'MYS',
    );
    final merged = PassportDetailsParser.mergeAutofill(
      current: PassportDetails(
        issueDate: firstScan.issueDate,
        expiryDate: DateTime(2032, 5, 6),
        issuingCountry: 'Malaysia',
      ),
      scanned: secondScan,
      previous: firstScan,
    );
    expect(merged.issueDate, secondScan.issueDate);
    expect(merged.expiryDate, DateTime(2032, 5, 6));
    expect(merged.issuingCountry, 'Malaysia');
  });

  test('unreadable retake fields do not retain old OCR details', () {
    final merged = PassportDetailsParser.mergeAutofill(
      current: firstScan,
      scanned: const PassportDetails(),
      previous: firstScan,
    );
    expect(merged.issueDate, isNull);
    expect(merged.expiryDate, isNull);
    expect(merged.issuingCountry, isNull);
  });
}
