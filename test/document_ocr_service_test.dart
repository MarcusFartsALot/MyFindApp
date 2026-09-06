import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/document_ocr_service.dart';
import 'package:my_find/core/exceptions/app_exceptions.dart';

void main() {
  group('MyKad document screening on both sides', () {
    for (final side in IdentityDocumentSide.values) {
      test('$side rejects a readable non-MyKad photo', () {
        expect(
          () => DocumentOcrService.validateDocumentText(
            text: 'MALAYSIA SHOPPING RECEIPT TOTAL 123.00 THANK YOU',
            requestedRole: 'citizen',
            side: side,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.toString(),
              'message',
              DocumentOcrService.notMyKadMessage,
            ),
          ),
        );
      });
      test('$side rejects unreadable OCR', () {
        expect(
          () => DocumentOcrService.validateDocumentText(
            text: 'x',
            requestedRole: 'citizen',
            side: side,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.toString(),
              'message',
              DocumentOcrService.unclearImageMessage,
            ),
          ),
        );
      });
      test('$side does not mistake a Malaysian passport for MyKad', () {
        expect(
          () => DocumentOcrService.validateDocumentText(
            text: 'MALAYSIA PASPORT PASSPORT C03005988',
            requestedRole: 'citizen',
            side: side,
          ),
          throwsA(isA<AppException>()),
        );
      });
    }
    test('front accepts a readable MyKad heading', () {
      expect(
        () => DocumentOcrService.validateDocumentText(
          text: 'KAD PENGENALAN MALAYSIA\n900101-14-5566\nSITI AMINAH',
          requestedRole: 'citizen',
        ),
        returnsNormally,
      );
    });
    test(
      'back accepts reverse-side wording without requiring front heading',
      () {
        const text = 'KETUA PENGARAH\nPENDAFTARAN NEGARA\n900101-14-5566';
        expect(
          () => DocumentOcrService.validateDocumentText(
            text: text,
            requestedRole: 'citizen',
            side: IdentityDocumentSide.back,
          ),
          returnsNormally,
        );
        expect(
          () => DocumentOcrService.validateDocumentText(
            text: text,
            requestedRole: 'citizen',
          ),
          throwsA(isA<AppException>()),
        );
      },
    );
    test('readable complete number on reverse must agree', () {
      for (final text in ['900101-14-5566', '900101 14 5566', '900101145566']) {
        expect(
          DocumentOcrService.backIdentityNumberMatches(
            extractedText: 'KETUA PENGARAH PENDAFTARAN NEGARA\n$text',
            identityNumber: '900101-14-5566',
          ),
          isTrue,
        );
      }
      expect(
        DocumentOcrService.backIdentityNumberMatches(
          extractedText: 'KETUA PENGARAH PENDAFTARAN NEGARA\n900101-14-5567',
          identityNumber: '900101-14-5566',
        ),
        isFalse,
      );
    });
    test(
      'reverse without a complete number relies on required front match',
      () {
        expect(
          DocumentOcrService.backIdentityNumberMatches(
            extractedText: 'KETUA PENGARAH PENDAFTARAN NEGARA',
            identityNumber: '900101-14-5566',
          ),
          isTrue,
        );
        expect(
          DocumentOcrService.backIdentityNumberMatches(
            extractedText: 'KETUA PENGARAH PENDAFTARAN NEGARA',
            identityNumber: '',
          ),
          isFalse,
        );
      },
    );
  });

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
