import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_find/M500/models/visa_submission_models.dart';
import 'package:my_find/M500/screens/visa_pdf_viewer_screen.dart';
import 'package:my_find/M500/services/pdf_scanner_service.dart';
import 'package:my_find/M500/services/visa_submission_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

extension SubmissionStatusExtension on SubmissionStatus {
  String get displayName {
    switch (this) {
      case SubmissionStatus.pending:
        return 'Pending';
      case SubmissionStatus.approved:
        return 'Approved';
      case SubmissionStatus.rejected:
        return 'Rejected';
      case SubmissionStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case SubmissionStatus.pending:
        return const Color(0xFFD97706);
      case SubmissionStatus.approved:
        return const Color(0xFF16A34A);
      case SubmissionStatus.rejected:
        return const Color(0xFFDC2626);
      case SubmissionStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }
}

enum PdfScanStage {
  idle,
  reading,
  validating,
  extracting,
  checking,
  completed,
  error,
}

class VisaSubmitScreenM500 extends StatefulWidget {
  final String profileId;

  const VisaSubmitScreenM500({
    super.key,
    required this.profileId,
  });

  @override
  State<VisaSubmitScreenM500> createState() =>
      _VisaSubmitScreenM500State();
}

class _VisaSubmitScreenM500State
    extends State<VisaSubmitScreenM500> {
  final _supabase = Supabase.instance.client;
  final VisaSubmissionService _submissionService =
  VisaSubmissionService();

  String _visaType = 'SEV';

  String _referenceId = '';
  String _transactionId = '';
  String _fullName = '';
  String _passportNumber = '';
  String _nationality = '';
  String _purposeOfVisit = '';
  String _arrivalDate = '';
  String _departureDate = '';

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;

  List<VisaSubmission> _submissions = [];
  Set<String> _completedSevSubmissionIds = <String>{};

  File? _selectedPdfFile;
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfFileName;

  bool _hasExtractedInfo = false;
  bool _isScanning = false;

  PdfScanStage _scanStage = PdfScanStage.idle;
  String? _scanError;

  bool get _hasPendingSubmission {
    return _submissionService.hasPendingSubmission(
      _submissions,
    );
  }

  bool get _hasBlockingApprovedVisa {
    return _submissionService.hasBlockingApprovedVisa(
      submissions: _submissions,
      completedSevSubmissionIds: _completedSevSubmissionIds,
    );
  }

  bool get _isVisaSubmissionBlocked {
    return _hasPendingSubmission || _hasBlockingApprovedVisa;
  }

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  // Load submissions
  Future<void> _loadSubmissions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final submissions =
      await _submissionService.loadSubmissions(
        widget.profileId,
      );

      if (!mounted) return;

      final completedSevSubmissionIds =
      await _submissionService.loadCompletedSevSubmissionIds(
        submissions,
      );

      if (!mounted) return;

      setState(() {
        _submissions = submissions;
        _completedSevSubmissionIds =
            completedSevSubmissionIds;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar(
        'Unable to load visa submissions.',
        isError: true,
      );
    }
  }

  // Select PDF
  Future<void> _pickPDF() async {
    if (_isVisaSubmissionBlocked ||
        _isScanning ||
        _isSubmitting) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final file = result.files.single;

      if (file.size > 10 * 1024 * 1024) {
        _showSnackBar(
          'File size exceeds the 10MB limit.',
          isError: true,
        );
        return;
      }

      if (!kIsWeb && file.path == null) {
        _showSnackBar(
          'Unable to access the selected PDF.',
          isError: true,
        );
        return;
      }

      if (kIsWeb && file.bytes == null) {
        _showSnackBar(
          'Unable to read the selected PDF.',
          isError: true,
        );
        return;
      }

      setState(() {
        if (kIsWeb) {
          _selectedPdfBytes = file.bytes;
          _selectedPdfFile = null;
        } else {
          _selectedPdfFile = File(file.path!);
          _selectedPdfBytes = null;
        }

        _selectedPdfFileName = file.name;
        _hasExtractedInfo = false;
        _scanError = null;
        _scanStage = PdfScanStage.idle;

        _clearExtractedInformation();
      });

      _showSnackBar(
        'PDF selected: ${file.name}',
      );
    } catch (_) {
      _showSnackBar(
        'Error selecting PDF.',
        isError: true,
      );
    }
  }

  Future<Uint8List> _readSelectedPdfBytes() async {
    if (kIsWeb) {
      if (_selectedPdfBytes == null) {
        throw Exception(
          'Unable to read the selected PDF.',
        );
      }

      return _selectedPdfBytes!;
    }

    if (_selectedPdfFile == null) {
      throw Exception(
        'Unable to access the selected PDF.',
      );
    }

    return await _selectedPdfFile!.readAsBytes();
  }

  void _validatePdfBytes(Uint8List pdfBytes) {
    if (pdfBytes.isEmpty) {
      throw Exception(
        'The selected PDF is empty.',
      );
    }

    if (pdfBytes.length > 10 * 1024 * 1024) {
      throw Exception(
        'File size exceeds the 10MB limit.',
      );
    }

    if (pdfBytes.length < 5) {
      throw Exception(
        'The selected file is not a valid PDF.',
      );
    }

    final signature = String.fromCharCodes(
      pdfBytes.take(5),
    );

    if (!signature.startsWith('%PDF-')) {
      throw Exception(
        'The selected file is not a valid PDF.',
      );
    }
  }

  // Scan PDF
  Future<void> _scanAndExtractPDF() async {
    if (_isVisaSubmissionBlocked) {
      _showSnackBar(
        _hasPendingSubmission
            ? 'You already have a pending visa application.'
            : 'You already have a valid approved visa.',
        isError: true,
      );
      return;
    }

    if (_selectedPdfFile == null &&
        _selectedPdfBytes == null) {
      _showSnackBar(
        'Please select a PDF first.',
        isError: true,
      );
      return;
    }

    if (_isScanning ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _isScanning = true;
      _hasExtractedInfo = false;
      _scanError = null;
      _scanStage = PdfScanStage.reading;
    });

    try {
      final pdfBytes =
      await _readSelectedPdfBytes();

      if (!mounted) return;

      setState(() {
        _scanStage = PdfScanStage.validating;
      });

      _validatePdfBytes(pdfBytes);

      if (!mounted) return;

      setState(() {
        _scanStage = PdfScanStage.extracting;
      });

      final extractedInfo =
      await PdfScannerService.scanPdf(
        pdfBytes,
      );

      final scanError =
      extractedInfo['scanError']
          ?.toString()
          .trim();

      if (scanError != null &&
          scanError.isNotEmpty) {
        throw Exception(scanError);
      }

      if (!PdfScannerService.hasExtractedData(
        extractedInfo,
      )) {
        throw Exception(
          'No useful information was detected in the PDF.',
        );
      }

      if (!mounted) return;

      setState(() {
        _scanStage = PdfScanStage.checking;
      });

      final referenceId =
          extractedInfo['referenceId']
              ?.toString()
              .trim()
              .toUpperCase() ??
              '';

      final transactionId =
          extractedInfo['transactionId']
              ?.toString()
              .trim() ??
              '';

      final fullName =
          extractedInfo['fullName']
              ?.toString()
              .trim() ??
              '';

      final passportNumber =
          extractedInfo['passportNumber']
              ?.toString()
              .trim()
              .toUpperCase() ??
              '';

      final nationality =
          extractedInfo['nationality']
              ?.toString()
              .trim() ??
              '';

      final purpose =
          extractedInfo['purposeOfVisit']
              ?.toString()
              .trim() ??
              '';

      final arrival =
          extractedInfo['arrivalDate']
              ?.toString()
              .trim() ??
              '';

      final departure =
          extractedInfo['departureDate']
              ?.toString()
              .trim() ??
              '';

      if (referenceId.isEmpty) {
        throw Exception(
          'Reference ID could not be detected.',
        );
      }

      if (transactionId.isEmpty) {
        throw Exception(
          'Transaction ID could not be detected.',
        );
      }

      if (passportNumber.isEmpty) {
        throw Exception(
          'Passport number could not be detected.',
        );
      }

      if (arrival.isEmpty ||
          departure.isEmpty) {
        throw Exception(
          'Travel dates could not be detected.',
        );
      }

      if (!mounted) return;

      setState(() {
        _referenceId = referenceId;
        _transactionId = transactionId;
        _fullName = fullName;
        _passportNumber = passportNumber;
        _nationality = nationality;
        _purposeOfVisit = purpose;
        _arrivalDate = arrival;
        _departureDate = departure;
        _hasExtractedInfo = true;
        _scanStage = PdfScanStage.completed;
        _scanError = null;
        _isScanning = false;
      });

      _showSnackBar(
        'PDF scanned successfully. Please review the extracted information.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _hasExtractedInfo = false;
        _scanStage = PdfScanStage.error;
        _scanError = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });

      _showSnackBar(
        _scanError ?? 'Error processing PDF.',
        isError: true,
      );
    }
  }

  // Cancel pending submission
  Future<void> _cancelPendingVisa(
      VisaSubmission submission,
      ) async {
    if (_isCancelling ||
        submission.status != SubmissionStatus.pending) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Visa Application?',
          ),
          content: const Text(
            'This pending visa application will be cancelled. '
                'You can submit a new application later.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Keep Application'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Cancel Application'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      await _submissionService.cancelPendingSubmission(
        submission: submission,
        profileId: widget.profileId,
      );

      _clearSelectedPdf();

      await _loadSubmissions();

      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      _showSnackBar(
        'Visa application cancelled successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      _showSnackBar(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
        isError: true,
      );
    }
  }

  // Submit visa
  Future<void> _submitVisa() async {
    if (_isSubmitting ||
        _isVisaSubmissionBlocked) {
      return;
    }

    if (!_hasExtractedInfo) {
      _showSnackBar(
        'Please select and scan a PDF first.',
        isError: true,
      );
      return;
    }

    final validationError =
    _validateSubmission();

    if (validationError != null) {
      _showSnackBar(
        validationError,
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pdfBytes =
      await _readSelectedPdfBytes();

      _validatePdfBytes(pdfBytes);

      final submittedReference =
      await _submissionService.submitVisa(
        profileId: widget.profileId,
        referenceId: _referenceId,
        transactionId: _transactionId,
        fullName: _fullName,
        passportNumber: _passportNumber,
        nationality: _nationality,
        purposeOfVisit: _purposeOfVisit,
        arrivalDate: _arrivalDate,
        departureDate: _departureDate,
        visaType: _visaType,
        pdfBytes: pdfBytes,
        pdfFileName: _selectedPdfFileName,
      );

      await _loadSubmissions();

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _selectedPdfFile = null;
        _selectedPdfBytes = null;
        _selectedPdfFileName = null;
        _hasExtractedInfo = false;
        _scanError = null;
        _scanStage = PdfScanStage.idle;
        _clearExtractedInformation();
        _visaType = 'SEV';
      });

      _showSnackBar(
        'Visa submitted successfully. '
            'Reference: $submittedReference',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showSnackBar(
        _friendlySubmissionError(e),
        isError: true,
      );
    }
  }

  // Validate submission
  String? _validateSubmission() {
    if (_referenceId.trim().isEmpty) {
      return 'Reference ID could not be detected.';
    }

    if (_transactionId.trim().isEmpty) {
      return 'Transaction ID could not be detected.';
    }

    if (_fullName.trim().isEmpty) {
      return 'Full name could not be detected.';
    }

    if (_passportNumber.trim().isEmpty) {
      return 'Passport number could not be detected.';
    }

    if (_nationality.trim().isEmpty) {
      return 'Nationality could not be detected.';
    }

    if (_purposeOfVisit.trim().isEmpty) {
      return 'Purpose of visit could not be detected.';
    }

    if (_arrivalDate.trim().isEmpty) {
      return 'Arrival date could not be detected.';
    }

    if (_departureDate.trim().isEmpty) {
      return 'Departure date could not be detected.';
    }

    final arrival =
    DateTime.tryParse(
      _arrivalDate.trim(),
    );

    final departure =
    DateTime.tryParse(
      _departureDate.trim(),
    );

    if (arrival == null) {
      return 'Invalid arrival date detected.';
    }

    if (departure == null) {
      return 'Invalid departure date detected.';
    }

    if (departure.isBefore(arrival)) {
      return 'Departure date cannot be before arrival date.';
    }

    final plannedArrivalDate = DateTime(
      arrival.year,
      arrival.month,
      arrival.day,
    );
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (plannedArrivalDate.isBefore(today)) {
      return 'Planned arrival date cannot be before today.';
    }

    if (_visaType != 'SEV' &&
        _visaType != 'MEV') {
      return 'Please select a valid visa type.';
    }

    return null;
  }

  String _friendlySubmissionError(
      Object error,
      ) {
    final message =
    error.toString().replaceFirst(
      'Exception: ',
      '',
    );

    if (message.contains(
      'APPLICATION_NOT_FOUND',
    )) {
      return 'The visa application could not be identified from the PDF.';
    }

    if (message.contains(
      'APPLICATION_AMBIGUOUS',
    )) {
      return 'The PDF matches multiple applications. Submission has been blocked for safety.';
    }

    if (message.contains(
      'PASSPORT_MISMATCH',
    )) {
      return 'Passport number does not match the visa application.';
    }

    if (message.contains(
      'DATE_MISMATCH',
    )) {
      return 'Travel dates do not match the visa application.';
    }

    if (message.contains(
      'APPLICATION_NOT_OWNED',
    )) {
      return 'This visa application does not belong to the current account.';
    }

    if (message.contains(
      'APPLICATION_ALREADY_USED',
    )) {
      return 'This AI visa application has already been used for an approved visa. Please complete a new AI visa application before applying again.';
    }

    if (message.contains(
      'OPEN_TRIP_EXISTS',
    )) {
      return 'Please report your departure before submitting a new visa application.';
    }

    if (message.contains(
      'VISA_NOT_ELIGIBLE',
    )) {
      return message;
    }

    if (message.contains(
      'INVALID_TRAVEL_DATES',
    )) {
      return 'Invalid travel dates.';
    }

    return message.isEmpty
        ? 'Error submitting visa application.'
        : message;
  }

  void _clearExtractedInformation() {
    _referenceId = '';
    _transactionId = '';
    _fullName = '';
    _passportNumber = '';
    _nationality = '';
    _purposeOfVisit = '';
    _arrivalDate = '';
    _departureDate = '';
  }

  void _clearSelectedPdf() {
    if (!mounted) return;

    setState(() {
      _selectedPdfFile = null;
      _selectedPdfBytes = null;
      _selectedPdfFileName = null;
      _hasExtractedInfo = false;
      _scanError = null;
      _isScanning = false;
      _scanStage = PdfScanStage.idle;
      _clearExtractedInformation();
    });
  }

  void _showSnackBar(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF15803D),
        behavior:
        SnackBarBehavior.floating,
        duration:
        const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(
      DateTime date,
      ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour =
    date.hour.toString().padLeft(
      2,
      '0',
    );

    final minute =
    date.minute.toString().padLeft(
      2,
      '0',
    );

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year} '
        '$hour:$minute';
  }

  String _scanStageText() {
    switch (_scanStage) {
      case PdfScanStage.reading:
        return 'Reading PDF...';
      case PdfScanStage.validating:
        return 'Validating PDF...';
      case PdfScanStage.extracting:
        return 'Extracting application information...';
      case PdfScanStage.checking:
        return 'Validating extracted information...';
      case PdfScanStage.completed:
        return 'Scan completed';
      case PdfScanStage.error:
        return 'Scan failed';
      case PdfScanStage.idle:
        return 'Ready to scan';
    }
  }

  int _scanStageIndex() {
    switch (_scanStage) {
      case PdfScanStage.reading:
        return 0;
      case PdfScanStage.validating:
        return 1;
      case PdfScanStage.extracting:
        return 2;
      case PdfScanStage.checking:
        return 3;
      case PdfScanStage.completed:
        return 4;
      case PdfScanStage.error:
      case PdfScanStage.idle:
        return -1;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Visa Submission',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor:
        Colors.white,
        elevation: 1,
        iconTheme:
        const IconThemeData(
          color: Color(0xFF0F172A),
        ),
        actions: [
          if (_submissions.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.only(
                right: 16,
              ),
              child: Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(0xFFEFF6FF),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  '${_submissions.length} submitted',
                  style:
                  const TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(
          color:
          Color(0xFF1E3A8A),
        ),
      )
          : ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          _buildVisaTypeSection(),
          const SizedBox(
            height: 24,
          ),
          _buildPdfSection(),
          if (_hasExtractedInfo)
            _buildExtractedSection(),
          if (_submissions.isNotEmpty)
            _buildSubmissionsSection(),
        ],
      ),
    );
  }

  Widget _buildVisaTypeSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Visa Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
            color:
            Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select Single Entry (SEV) or Multiple Entry (MEV) for your travel purpose.',
          style: TextStyle(
            fontSize: 13,
            color:
            Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(
              12,
            ),
            border:
            Border.all(
              color:
              const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child:
                _buildVisaTypeOption(
                  'SEV',
                  'Single Entry',
                  Icons.arrow_forward,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child:
                _buildVisaTypeOption(
                  'MEV',
                  'Multiple Entry',
                  Icons.arrow_outward,
                ),
              ),
            ],
          ),
        ),
        if (_hasPendingSubmission) ...[
          const SizedBox(
            height: 10,
          ),
          _buildPendingNotice(),
        ],
      ],
    );
  }

  Widget _buildPendingNotice() {
    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration:
      BoxDecoration(
        color:
        const Color(0xFFFFFBEB),
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFFDE68A),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 17,
            color:
            Color(0xFFD97706),
          ),
          SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              'You already have a pending visa submission. '
                  'PDF scanning and new submissions are disabled until it is approved, rejected, or cancelled.',
              style: TextStyle(
                fontSize: 12,
                color:
                Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfSection() {
    final hasSelectedFile =
        _selectedPdfFile != null ||
            _selectedPdfBytes != null;

    final borderColor =
    _hasExtractedInfo
        ? const Color(0xFF16A34A)
        : hasSelectedFile
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Visa Document',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
            color:
            Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the AI visa assessment report PDF. The application and travel information will be verified before submission.',
          style: TextStyle(
            fontSize: 13,
            color:
            Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(
              12,
            ),
            border:
            Border.all(
              color: borderColor,
              width:
              _hasExtractedInfo
                  ? 2
                  : 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _hasExtractedInfo
                        ? Icons.check_circle
                        : hasSelectedFile
                        ? Icons.upload_file
                        : Icons.picture_as_pdf,
                    color:
                    _hasExtractedInfo
                        ? const Color(
                      0xFF16A34A,
                    )
                        : hasSelectedFile
                        ? const Color(
                      0xFF1E3A8A,
                    )
                        : const Color(
                      0xFF94A3B8,
                    ),
                    size: 28,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasExtractedInfo
                              ? 'Scanned: ${_selectedPdfFileName ?? 'PDF'}'
                              : (_selectedPdfFileName ??
                              'No file selected'),
                          style: TextStyle(
                            fontWeight:
                            _hasExtractedInfo ||
                                _selectedPdfFileName !=
                                    null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                            _hasExtractedInfo ||
                                _selectedPdfFileName !=
                                    null
                                ? const Color(
                              0xFF0F172A,
                            )
                                : const Color(
                              0xFF64748B,
                            ),
                          ),
                        ),
                        if (_hasExtractedInfo &&
                            _scanError == null)
                          const Text(
                            'PDF scanned successfully',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              Color(0xFF16A34A),
                            ),
                          )
                        else if (_scanError != null)
                          Text(
                            _scanError!,
                            style:
                            const TextStyle(
                              fontSize: 12,
                              color:
                              Color(0xFFDC2626),
                            ),
                          )
                        else if (_selectedPdfFileName !=
                              null)
                            Text(
                              _scanStageText(),
                              style:
                              const TextStyle(
                                fontSize: 12,
                                color:
                                Color(0xFF1E3A8A),
                              ),
                            ),
                      ],
                    ),
                  ),
                  if (!_isVisaSubmissionBlocked)
                    _buildPdfActions(hasSelectedFile),
                ],
              ),
              if (_isScanning) ...[
                const SizedBox(
                  height: 16,
                ),
                _buildScanProgress(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfActions(
      bool hasSelectedFile,
      ) {
    if (_hasExtractedInfo) {
      return IconButton(
        icon: const Icon(
          Icons.close,
          color: Colors.grey,
        ),
        onPressed:
        _isSubmitting
            ? null
            : _clearSelectedPdf,
      );
    }

    if (hasSelectedFile) {
      return Row(
        children: [
          TextButton(
            onPressed:
            _isScanning ||
                _isSubmitting
                ? null
                : _scanAndExtractPDF,
            child: _isScanning
                ? const SizedBox(
              height: 16,
              width: 16,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Scan PDF',
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.grey,
            ),
            onPressed:
            _isScanning ||
                _isSubmitting
                ? null
                : _clearSelectedPdf,
          ),
        ],
      );
    }

    return TextButton(
      onPressed:
      _isSubmitting ||
          _isScanning ||
          _isVisaSubmissionBlocked
          ? null
          : _pickPDF,
      child:
      const Text('Choose PDF'),
    );
  }

  Widget _buildScanProgress() {
    final currentIndex =
    _scanStageIndex();

    const stages = [
      'Read',
      'Validate',
      'Extract',
      'Check',
      'Done',
    ];

    return Column(
      children: [
        Row(
          children: List.generate(
            stages.length,
                (index) {
              final completed =
                  currentIndex >= index;

              return Expanded(
                child: AnimatedContainer(
                  duration:
                  const Duration(
                    milliseconds: 250,
                  ),
                  margin:
                  EdgeInsets.only(
                    right:
                    index ==
                        stages.length - 1
                        ? 0
                        : 4,
                  ),
                  height: 4,
                  decoration:
                  BoxDecoration(
                    color: completed
                        ? const Color(
                      0xFF1E3A8A,
                    )
                        : const Color(
                      0xFFE2E8F0,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration:
                const Duration(
                  milliseconds: 200,
                ),
                child: Text(
                  _scanStageText(),
                  key: ValueKey(
                    _scanStage,
                  ),
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtractedSection() {
    return Column(
      children: [
        const SizedBox(
          height: 24,
        ),
        const Divider(
          thickness: 1,
        ),
        const SizedBox(
          height: 16,
        ),
        Row(
          children: [
            const Icon(
              Icons.document_scanner,
              size: 18,
              color:
              Color(0xFF1E3A8A),
            ),
            const SizedBox(
              width: 8,
            ),
            const Text(
              'Extracted Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.bold,
                color:
                Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        Container(
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(
              12,
            ),
            border:
            Border.all(
              color:
              const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              _buildExtractedInfoRow(
                'Reference ID',
                _referenceId,
              ),
              _buildExtractedInfoRow(
                'Transaction ID',
                _transactionId,
              ),
              _buildExtractedInfoRow(
                'Full Name',
                _fullName,
              ),
              _buildExtractedInfoRow(
                'Passport No.',
                _passportNumber,
              ),
              _buildExtractedInfoRow(
                'Nationality',
                _nationality,
              ),
              _buildExtractedInfoRow(
                'Purpose',
                _purposeOfVisit,
              ),
              _buildExtractedInfoRow(
                'Arrival',
                _arrivalDate,
              ),
              _buildExtractedInfoRow(
                'Departure',
                _departureDate,
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        Container(
          padding:
          const EdgeInsets.all(
            12,
          ),
          decoration:
          BoxDecoration(
            color:
            const Color(0xFFF0FDF4),
            borderRadius:
            BorderRadius.circular(
              8,
            ),
            border:
            Border.all(
              color:
              const Color(0xFFBBF7D0),
            ),
          ),
          child: const Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color:
                Color(0xFF15803D),
              ),
              SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  'The PDF will be matched using Reference ID and Transaction ID, then verified using passport and travel dates.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        const SizedBox(
          height: 8,
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              const Color(0xFF1E3A8A),
              disabledBackgroundColor:
              const Color(0xFFCBD5E1),
              padding:
              const EdgeInsets.symmetric(
                vertical: 16,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
            ),
            onPressed:
            _isSubmitting ||
                _isScanning ||
                _isVisaSubmissionBlocked
                ? null
                : _submitVisa,
            child: _isSubmitting
                ? const SizedBox(
              height: 20,
              width: 20,
              child:
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Submit for Admin Approval',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisaTypeOption(
      String value,
      String label,
      IconData icon,
      ) {
    final isSelected =
        _visaType == value;

    final disabled =
        _isVisaSubmissionBlocked ||
            _isSubmitting ||
            _isScanning;

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
        setState(() {
          _visaType = value;
        });
      },
      child: AnimatedOpacity(
        duration:
        const Duration(
          milliseconds: 150,
        ),
        opacity: disabled
            ? 0.55
            : 1,
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            vertical: 14,
          ),
          decoration:
          BoxDecoration(
            color: isSelected
                ? const Color(
              0xFF1E3A8A,
            )
                : Colors.white,
            borderRadius:
            BorderRadius.circular(
              8,
            ),
            border:
            Border.all(
              color: isSelected
                  ? const Color(
                0xFF1E3A8A,
              )
                  : const Color(
                0xFFE2E8F0,
              ),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : const Color(
                  0xFF64748B,
                ),
                size: 18,
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 14,
                  color: isSelected
                      ? Colors.white
                      : const Color(
                    0xFF0F172A,
                  ),
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white70
                      : const Color(
                    0xFF94A3B8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedInfoRow(
      String label,
      String value,
      ) {
    final hasValue =
        value.trim().isNotEmpty;

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style:
              const TextStyle(
                fontSize: 13,
                color:
                Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue
                  ? value
                  : 'Not detected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasValue
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: hasValue
                    ? const Color(
                  0xFF0F172A,
                )
                    : const Color(
                  0xFFDC2626,
                ),
              ),
            ),
          ),
          Icon(
            hasValue
                ? Icons.check_circle
                : Icons.error_outline,
            size: 14,
            color: hasValue
                ? const Color(
              0xFF16A34A,
            )
                : const Color(
              0xFFDC2626,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      SubmissionStatus status,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          4,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight:
          FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }

  Widget _buildSubmissionsSection() {
    return Column(
      children: [
        const SizedBox(
          height: 32,
        ),
        const Divider(
          thickness: 1,
        ),
        const SizedBox(
          height: 16,
        ),
        Row(
          children: [
            const Icon(
              Icons.history,
              size: 18,
              color:
              Color(0xFF1E3A8A),
            ),
            const SizedBox(
              width: 8,
            ),
            const Text(
              'Your Submissions',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.bold,
                color:
                Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(0xFFEFF6FF),
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Text(
                '${_submissions.length}',
                style:
                const TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        ..._submissions.map(
          _buildSubmissionCard,
        ),
      ],
    );
  }

  Widget _buildSubmissionCard(
      VisaSubmission submission,
      ) {
    final canCancel =
        submission.status ==
            SubmissionStatus.pending;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusChip(
                submission.status,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.referenceId,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 14,
                        color:
                        Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Submitted: ${_formatDate(submission.submittedAt)}',
                      style:
                      const TextStyle(
                        fontSize: 11,
                        color:
                        Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(0xFFF1F5F9),
                  borderRadius:
                  BorderRadius.circular(
                    4,
                  ),
                ),
                child: Text(
                  submission.visaType,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  '${submission.purposeOfVisit} · '
                      '${submission.arrivalDate} → '
                      '${submission.departureDate}',
                  style:
                  const TextStyle(
                    fontSize: 12,
                    color:
                    Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          if (submission.pdfFileName !=
              null) ...[
            const SizedBox(
              height: 8,
            ),
            GestureDetector(
              onTap: () => _viewPDF(
                submission.pdfUrl,
                submission.pdfFileName,
              ),
              child: Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration:
                BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(
                    6,
                  ),
                  border:
                  Border.all(
                    color:
                    const Color(0xFF1E3A8A),
                  ),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 14,
                      color:
                      Color(0xFF1E3A8A),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Flexible(
                      child: Text(
                        submission.pdfFileName!,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 12,
                          color:
                          Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    const Icon(
                      Icons.visibility,
                      size: 14,
                      color:
                      Color(0xFF1E3A8A),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(
              height: 12,
            ),
            SizedBox(
              width:
              double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                _isCancelling
                    ? null
                    : () =>
                    _cancelPendingVisa(
                      submission,
                    ),
                icon: _isCancelling
                    ? const SizedBox(
                  height: 15,
                  width: 15,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.cancel_outlined,
                  size: 17,
                ),
                label: Text(
                  _isCancelling
                      ? 'Cancelling...'
                      : 'Cancel Application',
                ),
                style:
                OutlinedButton.styleFrom(
                  foregroundColor:
                  const Color(
                    0xFFDC2626,
                  ),
                  side:
                  const BorderSide(
                    color:
                    Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _viewPDF(
      String? pdfUrl,
      String? fileName,
      ) async {
    if (pdfUrl == null ||
        pdfUrl.trim().isEmpty) {
      _showSnackBar(
        'No PDF attached.',
        isError: true,
      );
      return;
    }

    try {
      String displayUrl =
          pdfUrl;

      if (!pdfUrl.startsWith('http')) {
        const bucket =
            'visa-documents';

        final cleanPath =
        pdfUrl.replaceFirst(
          '$bucket/',
          '',
        );

        displayUrl =
        await _supabase.storage
            .from(bucket)
            .createSignedUrl(
          cleanPath,
          3600,
        );
      }

      final uri =
      Uri.tryParse(
        displayUrl,
      );

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' &&
              uri.scheme != 'https') ||
          uri.host.isEmpty) {
        _showSnackBar(
          'Invalid PDF URL.',
          isError: true,
        );
        return;
      }

      if (kIsWeb) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode:
            LaunchMode.externalApplication,
          );
        } else {
          _showSnackBar(
            'Cannot open PDF.',
            isError: true,
          );
        }

        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisaPdfViewerScreen(
            pdfUri: uri,
            fileName: fileName,
          ),
        ),
      );
    } catch (_) {
      _showSnackBar(
        'Error opening PDF.',
        isError: true,
      );
    }
  }
}
