import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/models/profile_model.dart';
import 'package:my_find/AI VISA/services/pdf_scanner_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================
// 状态枚举
// ============================================================
enum SubmissionStatus {
  pending,
  underReview,
  approved,
  rejected,
}

extension SubmissionStatusExtension on SubmissionStatus {
  String get displayName {
    switch (this) {
      case SubmissionStatus.pending:
        return '⏳ Pending';
      case SubmissionStatus.underReview:
        return '🔍 Under Review';
      case SubmissionStatus.approved:
        return '✅ Approved';
      case SubmissionStatus.rejected:
        return '❌ Rejected';
    }
  }

  Color get color {
    switch (this) {
      case SubmissionStatus.pending:
        return const Color(0xFFD97706);
      case SubmissionStatus.underReview:
        return const Color(0xFF2563EB);
      case SubmissionStatus.approved:
        return const Color(0xFF16A34A);
      case SubmissionStatus.rejected:
        return const Color(0xFFDC2626);
    }
  }

  IconData get icon {
    switch (this) {
      case SubmissionStatus.pending:
        return Icons.hourglass_top;
      case SubmissionStatus.underReview:
        return Icons.search;
      case SubmissionStatus.approved:
        return Icons.check_circle;
      case SubmissionStatus.rejected:
        return Icons.cancel;
    }
  }
}

// ============================================================
// 数据模型
// ============================================================
class VisaSubmission {
  final String id;
  final String referenceId;
  final String fullName;
  final String passportNumber;
  final String nationality;
  final String purposeOfVisit;
  final String arrivalDate;
  final String departureDate;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final String? pdfUrl;
  final String? pdfFileName;
  final String? adminNote;

  VisaSubmission({
    required this.id,
    required this.referenceId,
    required this.fullName,
    required this.passportNumber,
    required this.nationality,
    required this.purposeOfVisit,
    required this.arrivalDate,
    required this.departureDate,
    required this.submittedAt,
    required this.status,
    this.pdfUrl,
    this.pdfFileName,
    this.adminNote,
  });

  factory VisaSubmission.fromJson(Map<String, dynamic> json) {
    return VisaSubmission(
      id: json['id'] ?? '',
      referenceId: json['reference_id'] ??
          'TCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8).toUpperCase()}',
      fullName: json['full_name'] ?? '',
      passportNumber: json['passport_number'] ?? '',
      nationality: json['nationality'] ?? '',
      purposeOfVisit: json['purpose_of_visit'] ?? '',
      arrivalDate: json['arrival_date'] ?? '',
      departureDate: json['departure_date'] ?? '',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : DateTime.now(),
      status: _parseStatus(json['status']),
      pdfUrl: json['pdf_url'],
      pdfFileName: json['pdf_file_name'],
      adminNote: json['admin_note'],
    );
  }

  static SubmissionStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return SubmissionStatus.pending;
      case 'under_review':
        return SubmissionStatus.underReview;
      case 'approved':
        return SubmissionStatus.approved;
      case 'rejected':
        return SubmissionStatus.rejected;
      default:
        return SubmissionStatus.pending;
    }
  }
}

// ============================================================
// 主页面
// ============================================================
class VisaSubmitScreenM500 extends StatefulWidget {
  final ProfileModel profile;

  const VisaSubmitScreenM500({
    super.key,
    required this.profile,
  });

  @override
  State<VisaSubmitScreenM500> createState() => _VisaSubmitScreenM500State();
}

class _VisaSubmitScreenM500State extends State<VisaSubmitScreenM500> {
  final _supabase = Supabase.instance.client;

  // ===== 提取的信息 =====
  String _fullName = '';
  String _passportNumber = '';
  String _nationality = '';
  String _purposeOfVisit = '';
  String _arrivalDate = '';
  String _departureDate = '';

  // ===== 状态 =====
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isExtracting = false;
  List<VisaSubmission> _submissions = [];

  // ===== PDF 相关 =====
  File? _selectedPdfFile;
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfFileName;
  bool _isUploadingPdf = false;
  bool _hasUploadedPdf = false;
  bool _hasExtractedInfo = false;
  String _uploadedPdfUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  // ============================================================
  // 加载已提交列表
  // ============================================================
  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('visa_submissions')
          .select()
          .eq('profile_id', widget.profile.id)
          .order('submitted_at', ascending: false);

      if (mounted) {
        setState(() {
          _submissions = List<Map<String, dynamic>>.from(response)
              .map((e) => VisaSubmission.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // PDF 操作
  // ============================================================
  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return;

      final file = result.files.single;

      if (file.size > 10 * 1024 * 1024) {
        _showSnackBar('File size exceeds 10MB limit.', isError: true);
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
        _hasUploadedPdf = false;
        _hasExtractedInfo = false;
        _uploadedPdfUrl = '';
        _fullName = '';
        _passportNumber = '';
        _nationality = '';
        _purposeOfVisit = '';
        _arrivalDate = '';
        _departureDate = '';
      });

      _showSnackBar('✅ PDF selected: ${file.name}', isError: false);
    } catch (e) {
      _showSnackBar('Error selecting PDF: $e', isError: true);
    }
  }

  Future<void> _uploadAndExtractPDF() async {
    if (_selectedPdfFile == null && _selectedPdfBytes == null) {
      _showSnackBar('Please select a PDF first.', isError: true);
      return;
    }

    setState(() {
      _isUploadingPdf = true;
      _isExtracting = true;
    });

    try {
      final profileId = widget.profile.id;

      // 1. 获取 PDF 字节
      final pdfBytes = kIsWeb
          ? _selectedPdfBytes!
          : await _selectedPdfFile!.readAsBytes();

      // 2. 上传到 Storage
      final fileName =
          'visa_submissions/$profileId/${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await _supabase.storage
            .from('visa-documents')
            .uploadBinary(fileName, pdfBytes);
      } else {
        await _supabase.storage
            .from('visa-documents')
            .upload(fileName, _selectedPdfFile!);
      }

      final pdfUrl = _supabase.storage
          .from('visa-documents')
          .getPublicUrl(fileName);

      // 3. 用 PdfScannerService 提取信息
      final extractedInfo = await PdfScannerService.scanPdf(pdfBytes);

      setState(() {
        _isUploadingPdf = false;
        _hasUploadedPdf = true;
        _hasExtractedInfo = true;
        _fullName = extractedInfo['fullName'] ?? '';
        _passportNumber = extractedInfo['passportNumber'] ?? '';
        _nationality = extractedInfo['nationality'] ?? '';
        _purposeOfVisit = extractedInfo['purposeOfVisit'] ?? '';
        _arrivalDate = extractedInfo['arrivalDate'] ?? '';
        _departureDate = extractedInfo['departureDate'] ?? '';
        _uploadedPdfUrl = pdfUrl;
      });

      _showSnackBar('✅ PDF uploaded and information extracted!', isError: false);
    } catch (e) {
      setState(() {
        _isUploadingPdf = false;
        _isExtracting = false;
      });
      _showSnackBar('Error processing PDF: $e', isError: true);
    }
  }

  void _viewPDF(String? pdfUrl, String? fileName) async {
    if (pdfUrl == null) {
      _showSnackBar('No PDF attached.', isError: true);
      return;
    }

    try {
      // 如果是存储路径，生成签名 URL
      String displayUrl = pdfUrl;
      if (!pdfUrl.startsWith('http')) {
        final bucket = 'visa-documents';
        final cleanPath = pdfUrl.replaceFirst('$bucket/', '');
        displayUrl = await _supabase.storage
            .from(bucket)
            .createSignedUrl(cleanPath, 3600);
      }

      final uri = Uri.parse(displayUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Cannot open PDF.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening PDF: $e', isError: true);
    }
  }

  // ============================================================
  // 提交签证
  // ============================================================
  Future<void> _submitVisa() async {
    if (!_hasUploadedPdf) {
      _showSnackBar('Please upload a PDF first.', isError: true);
      return;
    }

    if (!_hasExtractedInfo) {
      _showSnackBar('Please wait for information extraction.', isError: true);
      return;
    }

    if (_fullName.isEmpty || _passportNumber.isEmpty) {
      _showSnackBar(
        'Could not extract complete information from PDF. Please try another file.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final profileId = widget.profile.id;

      final referenceId =
          'TCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8).toUpperCase()}';

      await _supabase.from('visa_submissions').insert({
        'profile_id': profileId,
        'reference_id': referenceId,
        'full_name': _fullName,
        'passport_number': _passportNumber,
        'nationality': _nationality,
        'purpose_of_visit': _purposeOfVisit,
        'arrival_date': _arrivalDate,
        'departure_date': _departureDate,
        'pdf_url': _uploadedPdfUrl,
        'pdf_file_name': _selectedPdfFileName,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      // 插入通知
      try {
        await _supabase.from('notifications').insert({
          'user_id': profileId,
          'title': 'Visa Submitted',
          'message': 'Your visa application ($referenceId) has been submitted for admin approval.',
          'type': 'Activity',
        });
      } catch (e) {
        // 忽略通知错误
      }

      // 刷新列表
      await _loadSubmissions();

      setState(() {
        _isSubmitting = false;
        _selectedPdfFile = null;
        _selectedPdfBytes = null;
        _selectedPdfFileName = null;
        _hasUploadedPdf = false;
        _hasExtractedInfo = false;
        _fullName = '';
        _passportNumber = '';
        _nationality = '';
        _purposeOfVisit = '';
        _arrivalDate = '';
        _departureDate = '';
        _uploadedPdfUrl = '';
      });

      _showSnackBar(
        '✅ Visa submitted! Reference: $referenceId',
        isError: false,
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Error submitting visa: $e', isError: true);
    }
  }

  // ============================================================
  // UI 辅助
  // ============================================================
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} $hour:$minute';
  }

  // ============================================================
  // 构建
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Visa Submission',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (_submissions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_submissions.length} submitted',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ===== 上传区域 =====
          const Text(
            'Upload Visa Document',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a PDF document. Information will be automatically extracted.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _hasUploadedPdf
                    ? const Color(0xFF16A34A)
                    : (_selectedPdfFile != null || _selectedPdfBytes != null
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFFE2E8F0)),
                width: _hasUploadedPdf ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _hasUploadedPdf
                  ? const Color(0xFFF0FDF4)
                  : (_selectedPdfFile != null || _selectedPdfBytes != null
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF8FAFC)),
            ),
            child: Row(
              children: [
                Icon(
                  _hasUploadedPdf
                      ? Icons.check_circle
                      : (_selectedPdfFile != null || _selectedPdfBytes != null
                      ? Icons.upload_file
                      : Icons.picture_as_pdf),
                  color: _hasUploadedPdf
                      ? const Color(0xFF16A34A)
                      : (_selectedPdfFile != null || _selectedPdfBytes != null
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF94A3B8)),
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasUploadedPdf
                            ? 'Uploaded: $_selectedPdfFileName'
                            : (_selectedPdfFileName ?? 'No file selected'),
                        style: TextStyle(
                          fontWeight: _hasUploadedPdf || _selectedPdfFileName != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _hasUploadedPdf || _selectedPdfFileName != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (_hasUploadedPdf)
                        const Text(
                          '✅ PDF uploaded and scanned',
                          style: TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                        )
                      else if (_selectedPdfFileName != null && !_isUploadingPdf)
                        const Text(
                          'Ready to upload & scan',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                        ),
                    ],
                  ),
                ),
                if (_hasUploadedPdf)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedPdfFile = null;
                        _selectedPdfBytes = null;
                        _selectedPdfFileName = null;
                        _hasUploadedPdf = false;
                        _hasExtractedInfo = false;
                        _uploadedPdfUrl = '';
                        _fullName = '';
                        _passportNumber = '';
                        _nationality = '';
                        _purposeOfVisit = '';
                        _arrivalDate = '';
                        _departureDate = '';
                      });
                    },
                  )
                else if (_selectedPdfFileName != null)
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isUploadingPdf ? null : _uploadAndExtractPDF,
                        child: _isUploadingPdf
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Upload & Scan'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _selectedPdfFile = null;
                            _selectedPdfBytes = null;
                            _selectedPdfFileName = null;
                            _hasExtractedInfo = false;
                            _fullName = '';
                            _passportNumber = '';
                            _nationality = '';
                            _purposeOfVisit = '';
                            _arrivalDate = '';
                            _departureDate = '';
                          });
                        },
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: _pickPDF,
                    child: const Text('Choose PDF'),
                  ),
              ],
            ),
          ),

          // ===== 提取的信息 =====
          if (_hasUploadedPdf) ...[
            const SizedBox(height: 24),
            const Divider(thickness: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.document_scanner, size: 18, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Text(
                  'Extracted Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                if (_isExtracting)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildExtractedInfoRow('Full Name', _fullName),
                  _buildExtractedInfoRow('Passport No.', _passportNumber),
                  _buildExtractedInfoRow('Nationality', _nationality),
                  _buildExtractedInfoRow('Purpose', _purposeOfVisit),
                  _buildExtractedInfoRow('Arrival', _arrivalDate),
                  _buildExtractedInfoRow('Departure', _departureDate),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting || !_hasExtractedInfo ? null : _submitVisa,
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Submit for Admin Approval',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],

          // ===== 已提交列表 =====
          if (_submissions.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(thickness: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.history, size: 18, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Text(
                  'Your Submissions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_submissions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._submissions.map((submission) => _buildSubmissionCard(submission)),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 提取信息行
  // ============================================================
  Widget _buildExtractedInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '...' : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.w600,
                color: value.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (value.isNotEmpty)
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
        ],
      ),
    );
  }

  // ============================================================
  // 状态标签
  // ============================================================
  Widget _buildStatusChip(SubmissionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 提交卡片
  // ============================================================
  Widget _buildSubmissionCard(VisaSubmission submission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: submission.status.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: submission.status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  submission.status.icon,
                  color: submission.status.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.referenceId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Submitted: ${_formatDate(submission.submittedAt)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(submission.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Purpose: ${submission.purposeOfVisit}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            'Arrival: ${submission.arrivalDate} · Departure: ${submission.departureDate}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (submission.adminNote != null && submission.adminNote!.isNotEmpty)
            Text(
              '📝 ${submission.adminNote}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 8),
          if (submission.pdfFileName != null)
            GestureDetector(
              onTap: () => _viewPDF(submission.pdfUrl, submission.pdfFileName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Text(
                      submission.pdfFileName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A8A),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.visibility, size: 14, color: Color(0xFF1E3A8A)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}