import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

class PdfScannerService {
  static Future<Map<String, String>> scanPdf(
      Uint8List pdfBytes,
      ) async {
    if (pdfBytes.isEmpty) {
      return _emptyResult(
        error: 'The selected PDF is empty.',
      );
    }

    PdfDocument? document;

    try {
      document = await PdfDocument.openData(pdfBytes);
      final buffer = StringBuffer();

      for (int i = 0; i < document.pages.length; i++) {
        try {
          final pageText = await document.pages[i].loadText();

          if (pageText.fullText.trim().isNotEmpty) {
            buffer.writeln(pageText.fullText);
          }
        } catch (_) {
          continue;
        }
      }

      final fullText = buffer.toString().trim();

      if (fullText.isEmpty) {
        return _emptyResult(
          error: 'No readable text was detected in the PDF. '
              'The document may be scanned as an image.',
        );
      }

      return _parseExtractedText(fullText);
    } catch (_) {
      return _emptyResult(
        error: 'Unable to read the PDF.',
      );
    } finally {
      try {
        document?.dispose();
      } catch (_) {}
    }
  }

  static Map<String, String> _parseExtractedText(
      String text,
      ) {
    final normalized = _normalizeText(text);

    final referenceId = _extractReferenceId(normalized);
    final transactionId = _extractTransactionId(normalized);

    final fullName = _extractField(
      normalized,
      patterns: [
        RegExp(
          r'Full\s*Name\s*:\s*(.*?)\s*'
          r'(?=Passport\s*(?:No|Number)\s*:|$)',
          caseSensitive: false,
        ),
        RegExp(
          r'Name\s*:\s*(.*?)\s*'
          r'(?=Passport\s*(?:No|Number)\s*:|$)',
          caseSensitive: false,
        ),
      ],
    );

    final passportNumber = _extractField(
      normalized,
      patterns: [
        RegExp(
          r'Passport\s*(?:No|Number)\s*:\s*([A-Z0-9<]+)',
          caseSensitive: false,
        ),
      ],
    );

    final nationality = _extractField(
      normalized,
      patterns: [
        RegExp(
          r'Nationality\s*:\s*(.*?)\s*'
          r'(?=Country\s*of\s*Residence\s*:'
          r'|Purpose\s*of\s*Visit\s*:'
          r'|Intended\s*Destination\s*:'
          r'|$)',
          caseSensitive: false,
        ),
      ],
    );

    final purposeOfVisit = _extractField(
      normalized,
      patterns: [
        RegExp(
          r'Purpose\s*of\s*Visit\s*:\s*(.*?)\s*'
          r'(?=Intended\s*Destination\s*:'
          r'|Arrival\s*Date\s*:'
          r'|Departure\s*Date\s*:'
          r'|$)',
          caseSensitive: false,
        ),
      ],
    );

    final arrivalDate = _extractDate(
      normalized,
      labels: [
        'Arrival Date',
        'Arrival',
        'Date of Arrival',
      ],
    );

    final departureDate = _extractDate(
      normalized,
      labels: [
        'Departure Date',
        'Departure',
        'Date of Departure',
      ],
    );

    return {
      'referenceId': _cleanReferenceId(referenceId),
      'transactionId': _cleanTransactionId(transactionId),
      'fullName': _cleanValue(fullName),
      'passportNumber': _cleanPassport(passportNumber),
      'nationality': _cleanValue(nationality),
      'purposeOfVisit': _cleanValue(purposeOfVisit),
      'arrivalDate': arrivalDate,
      'departureDate': departureDate,
    };
  }

  static String _extractReferenceId(String text) {
    final patterns = [
      RegExp(
        r'Reference\s*ID\s*:\s*#?\s*([A-Z0-9]{8,})',
        caseSensitive: false,
      ),
      RegExp(
        r'Reference\s*(?:No|Number)\s*:\s*#?\s*([A-Z0-9]{8,})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);

      if (match != null) {
        final value = match.group(1)?.trim() ?? '';

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  static String _extractTransactionId(String text) {
    final patterns = [
      RegExp(
        r'Transaction\s*ID\s*:\s*([^\s]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'Transaction\s*(?:No|Number)\s*:\s*([^\s]+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);

      if (match != null) {
        final value = match.group(1)?.trim() ?? '';

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  static String _extractField(
      String text, {
        required List<RegExp> patterns,
      }) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);

      if (match != null) {
        final value = match.group(1)?.trim() ?? '';

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  static String _extractDate(
      String text, {
        required List<String> labels,
      }) {
    for (final label in labels) {
      final escapedLabel = RegExp.escape(label);

      final pattern = RegExp(
        '$escapedLabel\\s*:\\s*'
        r'(\d{4}[-/]\d{1,2}[-/]\d{1,2}'
        r'|\d{1,2}[-/]\d{1,2}[-/]\d{4})',
        caseSensitive: false,
      );

      final match = pattern.firstMatch(text);

      if (match != null) {
        final rawDate = match.group(1)?.trim() ?? '';
        final normalizedDate = _normalizeDate(rawDate);

        if (normalizedDate.isNotEmpty) {
          return normalizedDate;
        }
      }
    }

    return '';
  }

  static String _normalizeDate(String value) {
    final cleaned = value.trim().replaceAll('/', '-');

    final yyyyMmDd = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
    );

    final yyyyMatch = yyyyMmDd.firstMatch(cleaned);

    if (yyyyMatch != null) {
      final year = yyyyMatch.group(1)!;
      final month = _twoDigits(yyyyMatch.group(2)!);
      final day = _twoDigits(yyyyMatch.group(3)!);

      return '$year-$month-$day';
    }

    final ddMmYyyy = RegExp(
      r'^(\d{1,2})-(\d{1,2})-(\d{4})$',
    );

    final ddMatch = ddMmYyyy.firstMatch(cleaned);

    if (ddMatch != null) {
      final day = _twoDigits(ddMatch.group(1)!);
      final month = _twoDigits(ddMatch.group(2)!);
      final year = ddMatch.group(3)!;

      return '$year-$month-$day';
    }

    return '';
  }

  static String _twoDigits(String value) {
    final number = int.tryParse(value);

    if (number == null) {
      return value;
    }

    return number.toString().padLeft(2, '0');
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanValue(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(
      RegExp(r'\s*:\s*$'),
      '',
    );
  }

  static String _cleanPassport(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .trim()
        .toUpperCase();
  }

  static String _cleanReferenceId(String value) {
    return value
        .replaceAll('#', '')
        .trim()
        .toUpperCase();
  }

  static String _cleanTransactionId(String value) {
    return value
        .trim()
        .replaceAll(
      RegExp(r'[,.;]+$'),
      '',
    );
  }

  static Map<String, String> _emptyResult({
    required String error,
  }) {
    return {
      'referenceId': '',
      'transactionId': '',
      'fullName': '',
      'passportNumber': '',
      'nationality': '',
      'purposeOfVisit': '',
      'arrivalDate': '',
      'departureDate': '',
      'scanError': error,
    };
  }

  static bool hasExtractedData(
      Map<String, String> result,
      ) {
    const requiredFields = [
      'referenceId',
      'transactionId',
      'passportNumber',
      'arrivalDate',
      'departureDate',
    ];

    return requiredFields.every(
          (field) => (result[field] ?? '').trim().isNotEmpty,
    );
  }

  static bool hasApplicationIdentifiers(
      Map<String, String> result,
      ) {
    return (result['referenceId'] ?? '').trim().isNotEmpty &&
        (result['transactionId'] ?? '').trim().isNotEmpty;
  }

  static bool hasScanError(
      Map<String, String> result,
      ) {
    return (result['scanError'] ?? '').trim().isNotEmpty;
  }
}
