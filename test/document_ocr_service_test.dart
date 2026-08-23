import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/document_ocr_service.dart';

void main() {
  group('private OCR identity-number matching', () {
    test('matches a formatted MyKad number in extracted text', () {
      final matches = DocumentOcrService.identityNumberMatches(
        extractedText: 'KAD PENGENALAN MALAYSIA\n550106-12-5821',
        identityNumber: '550106125821',
        requestedRole: 'citizen',
      );

      expect(matches, isTrue);
    });

    test('matches a passport number regardless of spacing or case', () {
      final matches = DocumentOcrService.identityNumberMatches(
        extractedText: 'PASSPORT NO. C03 005 988\nP<MYS',
        identityNumber: 'c03005988',
        requestedRole: 'tourist',
      );

      expect(matches, isTrue);
    });

    test('rejects a number that is absent from the document', () {
      final matches = DocumentOcrService.identityNumberMatches(
        extractedText: 'PASSPORT NO. A12345678\nP<MYS',
        identityNumber: 'C03005988',
        requestedRole: 'tourist',
      );

      expect(matches, isFalse);
    });
  });
}
