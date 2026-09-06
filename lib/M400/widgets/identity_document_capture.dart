import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../services/document_ocr_service.dart';
import 'auth_ui.dart';

class RecognizedDocument {
  final File image;
  final String extractedText;

  const RecognizedDocument({required this.image, required this.extractedText});
}

class IdentityDocumentCapture extends StatefulWidget {
  final String requestedRole;
  final String expectedIdentityNumber;
  final String? labelOverride;
  final IdentityDocumentSide side;
  final ValueChanged<RecognizedDocument?> onDocumentChanged;

  /// Passport autofill is independent of identity-number verification.
  /// Only onDocumentChanged may supply a document accepted for submission.
  final ValueChanged<String?>? onTextExtracted;
  final ImagePicker? imagePicker;
  final DocumentOcrService? ocrService;

  const IdentityDocumentCapture({
    super.key,
    required this.requestedRole,
    this.expectedIdentityNumber = '',
    required this.onDocumentChanged,
    this.labelOverride,
    this.side = IdentityDocumentSide.front,
    this.onTextExtracted,
    this.imagePicker,
    this.ocrService,
  });

  @override
  State<IdentityDocumentCapture> createState() =>
      _IdentityDocumentCaptureState();
}

class _IdentityDocumentCaptureState extends State<IdentityDocumentCapture> {
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  late final DocumentOcrService _ocrService =
      widget.ocrService ?? DocumentOcrService();

  File? _image;
  String? _extractedText;
  String? _error;
  bool _isProcessing = false;
  bool _isVerified = false;

  String get _documentLabel =>
      widget.labelOverride ??
      (widget.requestedRole == 'citizen' ? 'MyKad' : 'Passport');

  @override
  void didUpdateWidget(covariant IdentityDocumentCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_extractedText == null ||
        oldWidget.expectedIdentityNumber == widget.expectedIdentityNumber) {
      return;
    }

    final matches = _matchesExpectedNumber(_extractedText!);
    _isVerified = matches;
    _error = matches
        ? null
        : DocumentOcrService.identityMismatchMessage(widget.requestedRole);
    final expected = widget.expectedIdentityNumber;
    final text = _extractedText!;
    // Parent fields may be rebuilding now. Notify after this frame, and ignore
    // a stale recheck if the image/number changes again before delivery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _extractedText != text ||
          widget.expectedIdentityNumber != expected) {
        return;
      }
      widget.onDocumentChanged(
        matches
            ? RecognizedDocument(image: _image!, extractedText: text)
            : null,
      );
    });
  }

  bool _matchesExpectedNumber(String extractedText) =>
      widget.side == IdentityDocumentSide.back &&
          widget.requestedRole == 'citizen'
      ? DocumentOcrService.backIdentityNumberMatches(
          extractedText: extractedText,
          identityNumber: widget.expectedIdentityNumber,
        )
      : DocumentOcrService.identityNumberMatches(
          extractedText: extractedText,
          identityNumber: widget.expectedIdentityNumber,
          requestedRole: widget.requestedRole,
        );

  Future<void> _pick(ImageSource source) async {
    if (widget.requestedRole == 'citizen' &&
        widget.expectedIdentityNumber.trim().isEmpty) {
      setState(() {
        _isVerified = false;
        _error = 'Enter your MyKad number before adding the photo.';
      });
      widget.onDocumentChanged(null);
      return;
    }

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
        _isVerified = false;
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
      _isVerified = false;
      _isProcessing = true;
    });
    widget.onDocumentChanged(null);
    widget.onTextExtracted?.call(null);

    try {
      final text = await _ocrService.extractAndValidate(
        image: image,
        requestedRole: widget.requestedRole,
        side: widget.side,
      );
      if (!mounted) return;
      // Retain OCR text only in memory so a corrected typed number can be
      // checked again without exposing the extracted document contents.
      _extractedText = text;
      // A readable passport can help fill the form even before its number is
      // typed. A mismatch still leaves the submission document unset.
      widget.onTextExtracted?.call(text);
      if (!_matchesExpectedNumber(text)) {
        throw AppException(
          widget.expectedIdentityNumber.trim().isEmpty
              ? 'Passport scanned. Enter the passport number to verify it before registering.'
              : DocumentOcrService.identityMismatchMessage(
                  widget.requestedRole,
                ),
        );
      }
      setState(() {
        _isVerified = true;
      });
      widget.onDocumentChanged(
        RecognizedDocument(image: image, extractedText: text),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isVerified = false;
      });
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
          '$_documentLabel photo',
          style: const TextStyle(
            color: M400AuthColors.heading,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
              color: M400AuthColors.background,
              border: Border.all(color: M400AuthColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.requestedRole == 'citizen'
                      ? Icons.badge_outlined
                      : Icons.menu_book_outlined,
                  size: 42,
                  color: M400AuthColors.muted,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a clear $_documentLabel photo',
                  style: const TextStyle(
                    color: M400AuthColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: M400AuthColors.primary,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Reading document text...',
                  style: TextStyle(color: M400AuthColors.body),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: M400AuthColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                style: IconButton.styleFrom(
                  foregroundColor: M400AuthColors.primary,
                  side: const BorderSide(color: M400AuthColors.border),
                ),
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: 'Choose from gallery',
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: M400AuthColors.error, fontSize: 12),
          ),
        ],
        if (_isVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle, color: M400AuthColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.side == IdentityDocumentSide.back
                      ? 'MyKad back photo checked successfully.'
                      : 'Document number verified successfully.',
                  style: const TextStyle(
                    color: M400AuthColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'OCR runs privately to check the document. Review any autofilled details. An administrator will still verify your documents.',
            style: TextStyle(
              color: M400AuthColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
