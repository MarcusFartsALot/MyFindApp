import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/mykad_details_parser.dart';
import 'package:my_find/M400/services/passport_details_parser.dart';

void main() {
  test('MyKad reads explicit name, citizen marker and printed gender', () {
    final details = MyKadDetailsParser.parse(
      'MALAYSIA\nNAMA: ALI BIN AHMAD\nWARGANEGARA\nLELAKI',
    );
    expect(details.name, 'ALI BIN AHMAD');
    expect(details.nationality, 'Malaysian');
    expect(details.gender, 'male');
  });
  test('MyKad reads the name immediately below the document number', () {
    final details = MyKadDetailsParser.parse(
      'KAD PENGENALAN\n900101-14-5566\nSITI AMINAH\nPEREMPUAN',
    );
    expect(details.name, 'SITI AMINAH');
    expect(details.gender, 'female');
    expect(details.nationality, isNull);
  });
  test(
    'MyKad does not turn an address, heading or noncitizen text into identity details',
    () {
      final details = MyKadDetailsParser.parse(
        '900101-14-5566\nJALAN MERANTI\nBUKAN WARGANEGARA',
      );
      expect(details.name, isNull);
      expect(details.nationality, isNull);
      expect(details.gender, isNull);
    },
  );
  test('passport labels fill details without needing a readable MRZ', () {
    final details = PassportDetailsParser.parse(
      'Name: JANE DOE\nNationality: MALAYSIAN\nIssuing Country: MALAYSIA\nDate of issue: 2025-01-02',
    );
    expect(details.name, 'JANE DOE');
    expect(details.nationality, 'MALAYSIAN');
    expect(details.issuingCountry, 'MALAYSIA');
    expect(details.issueDate, DateTime(2025, 1, 2));
    expect(details.number, isNull);
  });
  test('passport label without a value does not consume the next label', () {
    final details = PassportDetailsParser.parse('NAME\nNATIONALITY\nMALAYSIAN');
    expect(details.name, isNull);
    expect(details.nationality, 'MALAYSIAN');
  });
}
