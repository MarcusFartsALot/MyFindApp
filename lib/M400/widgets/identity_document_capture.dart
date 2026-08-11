import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/document_ocr_service.dart';

class RecognizedDocument {
  final File image;
  final String extractedText;

  const RecognizedDocument({required this.image, required this.extractedText});
}

class IdentityDocumentCapture extends StatefulWidget {
  final String requestedRole;
  final String? labelOverride;
  final bool requiresOcr;
  final ValueChanged<RecognizedDocument?> onDocumentChanged;

  const IdentityDocumentCapture({
    super.key,
    required this.requestedRole,
    required this.onDocumentChanged,
    this.labelOverride,
    this.requiresOcr = true,
  });

  @override
  State<IdentityDocumentCapture> createState() =>
      _IdentityDocumentCaptureState();
}

class _IdentityDocumentCaptureState extends State<IdentityDocumentCapture> {
  final ImagePicker _picker = ImagePicker();
  final DocumentOcrService _ocrService = DocumentOcrService();

  File? _image;
  String? _extractedText;
  String? _error;
  bool _isProcessing = false;

  String get _documentLabel =>
      widget.labelOverride ??
      (widget.requestedRole == 'citizen' ? 'MyKad' : 'Passport');

  Future<void> _pick(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The camera or photo library could not be opened.';
        _isProcessing = false;
      });
      widget.onDocumentChanged(null);
      return;
    }
    if (picked == null || !mounted) return;

    final image = File(picked.path);
    setState(() {
      _image = image;
      _extractedText = null;
      _error = null;
      _isProcessing = true;
    });
    widget.onDocumentChanged(null);

    if (!widget.requiresOcr) {
      setState(() => _isProcessing = false);
      widget.onDocumentChanged(
        RecognizedDocument(image: image, extractedText: ''),
      );
      return;
    }

    try {
      final text = await _ocrService.extractAndValidate(
        image: image,
        requestedRole: widget.requestedRole,
      );
      if (!mounted) return;
      setState(() => _extractedText = text);
      widget.onDocumentChanged(
        RecognizedDocument(image: image, extractedText: text),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      widget.onDocumentChanged(null);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identity Document: $_documentLabel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _image!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.requestedRole == 'citizen'
                  ? Icons.badge_outlined
                  : Icons.menu_book_outlined,
              size: 48,
              color: Colors.grey,
            ),
          ),
        const SizedBox(height: 8),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Reading document text...'),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _image == null
                        ? 'Capture $_documentLabel'
                        : 'Retake $_documentLabel',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: 'Choose from gallery',
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ],
        if (widget.requiresOcr && _extractedText != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Text extracted. Confirm the preview below.'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(_extractedText!),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'OCR assists document review and does not prove identity. An administrator will verify the application.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
