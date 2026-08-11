import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/exceptions/app_exceptions.dart';

class DocumentOcrService {
  static const unclearImageMessage =
      'The picture is not clear enough. Please take a photo again.';

  Future<String> extractAndValidate({
    required File image,
    required String requestedRole,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(image);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();

      final compactText = text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final wordCount = text
          .split(RegExp(r'\s+'))
          .where((word) => word.length >= 2)
          .length;
      if (compactText.length < 20 || wordCount < 3) {
        throw AppException(unclearImageMessage);
      }

      final normalized = text.toLowerCase();
      final looksLikeMyKad =
          normalized.contains('malaysia') ||
          normalized.contains('kad pengenalan') ||
          normalized.contains('identity card') ||
          normalized.contains('mykad');
      final looksLikePassport =
          normalized.contains('passport') ||
          normalized.contains('pasport') ||
          normalized.contains('p<');

      if (requestedRole == 'citizen' && !looksLikeMyKad) {
        throw AppException(
          'The image does not appear to be a MyKad. Please take a clear MyKad photo.',
        );
      }
      if (requestedRole == 'tourist' && !looksLikePassport) {
        throw AppException(
          'The image does not appear to be a passport. Please take a clear passport photo.',
        );
      }

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
