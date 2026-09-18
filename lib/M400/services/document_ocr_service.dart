import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/exceptions/app_exceptions.dart';

enum IdentityDocumentSide { front, back }

class DocumentOcrService {
  static const unclearImageMessage =
      'The picture is not clear enough. Please take a photo again.';
  static const notMyKadMessage =
      'The image does not appear to be a MyKad. Please take a clear MyKad photo.';

  /// Text-level checks shared by capture and submission. OCR is a screening
  /// aid, not proof that an identity document is genuine.
  static void validateDocumentText({
    required String text,
    required String requestedRole,
    IdentityDocumentSide side = IdentityDocumentSide.front,
  }) {
    final compact = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final words = text.split(RegExp(r'\s+')).where((word) => word.length >= 2);
    if (compact.length < 20 || words.length < 3) {
      throw AppException(unclearImageMessage);
    }
    final looksLikePassport = RegExp(
      r'\b(PASSPORT|PASPORT)\b|P\s*<',
      caseSensitive: false,
    ).hasMatch(text);
    final myKadHeading =
        compact.contains('MYKAD') ||
        compact.contains('KADPENGENALAN') ||
        (compact.contains('MALAYSIA') && compact.contains('IDENTITYCARD'));
    final reverseHeading =
        compact.contains('PENDAFTARANNEGARA') ||
            compact.contains('KETUAPENGARAH') ||
            compact.contains('JABATANPENDAFTARANNEGARA');
    if (requestedRole == 'citizen' &&
        (looksLikePassport ||
            !(myKadHeading ||
                (side == IdentityDocumentSide.back && reverseHeading)))) {
      throw AppException(notMyKadMessage);
    }
    if (requestedRole == 'tourist' && !looksLikePassport) {
      throw AppException(
        'The image does not appear to be a passport. Please take a clear passport photo.',
      );
    }
  }

  /// The front is the required number-match source. If the reverse OCR also
  /// contains a complete MyKad number, it must agree with the typed number.
  static bool backIdentityNumberMatches({
    required String extractedText,
    required String identityNumber,
  }) {
    final expected = normalizeIdentityNumber(
      identityNumber,
      requestedRole: 'citizen',
    );

    // The typed MyKad number must remain the standard 12-digit number.
    if (expected.length != 12) return false;

    final matches = RegExp(
      r'(?<!\d)'
      r'(\d{6})[\s-]?'
      r'(\d{2})[\s-]?'
      r'(\d{4})'
      r'(?:[\s-]?\d{2}[\s-]?\d{2})?'
      r'(?!\d)',
    ).allMatches(extractedText);

    return matches.any((match) {
      final firstTwelveDigits =
          '${match.group(1)}${match.group(2)}${match.group(3)}';

      return firstTwelveDigits == expected;
    });
  }

  /// OCR text stays inside the application and is never presented to the
  /// citizen or tourist. Only this boolean verification result reaches the UI.
  static bool identityNumberMatches({
    required String extractedText,
    required String identityNumber,
    required String requestedRole,
  }) {
    final expected = normalizeIdentityNumber(
      identityNumber,
      requestedRole: requestedRole,
    );
    if (expected.isEmpty) return false;

    final normalizedOcr = requestedRole == 'citizen'
        ? extractedText.replaceAll(RegExp(r'[^0-9]'), '')
        : extractedText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return normalizedOcr.contains(expected);
  }

  static String normalizeIdentityNumber(
    String value, {
    required String requestedRole,
  }) {
    if (requestedRole == 'citizen') {
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String identityMismatchMessage(String requestedRole) {
    final label = requestedRole == 'citizen'
        ? 'MyKad number'
        : 'passport number';
    return 'The $label in the photo does not match the number you entered. '
        'Check the number or retake the photo.';
  }

  Future<String> extractAndValidate({
    required File image,
    required String requestedRole,
    IdentityDocumentSide side = IdentityDocumentSide.front,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(image);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();

      validateDocumentText(
        text: text,
        requestedRole: requestedRole,
        side: side,
      );

      return text;
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException(unclearImageMessage);
    } finally {
      await recognizer.close();
    }
  }
}
