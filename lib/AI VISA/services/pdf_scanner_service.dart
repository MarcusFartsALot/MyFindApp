import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';

class PdfScannerService {

  static Future<Map<String, String>> scanPdf(Uint8List pdfBytes) async {
    try {
      // ✅ 使用 pdfrx 加载 PDF
      final document = await PdfDocument.openData(pdfBytes);

      String fullText = '';

      // ✅ 用 pages 列表遍历
      for (int i = 0; i < document.pages.length; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();  // ✅ 提取文字
        fullText += pageText.fullText + '\n';
      }

      return _parseExtractedText(fullText);

    } catch (e) {
      return {
        'fullName': 'Scan failed: $e',
        'passportNumber': 'Scan failed',
        'nationality': 'Scan failed',
        'purposeOfVisit': 'Scan failed',
        'arrivalDate': '',
        'departureDate': '',
      };
    }
  }

  static Map<String, String> _parseExtractedText(String text) {
    final clean = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    final nameRegex = RegExp(r'Full Name:\s*([A-Za-z\s]+?)(?=\s+Passport No:|$)');
    final passportRegex = RegExp(r'Passport No:\s*([A-Z0-9]+)');
    final nationalityRegex = RegExp(r'Nationality:\s*([A-Za-z\s]+?)(?=\s+Country of Residence:|$)');
    final purposeRegex = RegExp(r'Purpose of Visit:\s*([A-Za-z\s]+?)(?=\s+Intended Destination:|$)');
    final arrivalRegex = RegExp(r'Arrival Date:\s*(\d{4}-\d{2}-\d{2})');
    final departureRegex = RegExp(r'Departure Date:\s*(\d{4}-\d{2}-\d{2})');

    return {
      'fullName': nameRegex.firstMatch(clean)?.group(1)?.trim() ?? 'Not detected',
      'passportNumber': passportRegex.firstMatch(clean)?.group(1)?.trim() ?? 'Not detected',
      'nationality': nationalityRegex.firstMatch(clean)?.group(1)?.trim() ?? 'Not detected',
      'purposeOfVisit': purposeRegex.firstMatch(clean)?.group(1)?.trim() ?? 'Not detected',
      'arrivalDate': arrivalRegex.firstMatch(clean)?.group(1)?.trim() ?? '',
      'departureDate': departureRegex.firstMatch(clean)?.group(1)?.trim() ?? '',
    };
  }
}