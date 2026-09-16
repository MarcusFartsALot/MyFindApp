import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class VisaPdfViewerScreen extends StatelessWidget {
  final Uri pdfUri;
  final String? fileName;

  const VisaPdfViewerScreen({
    super.key,
    required this.pdfUri,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final title = fileName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title == null || title.isEmpty
              ? 'Visa PDF'
              : title,
        ),
      ),
      body: PdfViewer.uri(
        pdfUri,
        params: PdfViewerParams(
          loadingBannerBuilder: (
            context,
            bytesDownloaded,
            totalBytes,
          ) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: totalBytes != null && totalBytes > 0
                        ? bytesDownloaded / totalBytes
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Loading PDF...'),
                ],
              ),
            );
          },
          errorBannerBuilder: (
            context,
            error,
            stackTrace,
            documentRef,
          ) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 48,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Unable to load this PDF.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
