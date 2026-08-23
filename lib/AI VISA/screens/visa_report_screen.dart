import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VisaReportScreen extends StatefulWidget {
  final String applicationId;

  const VisaReportScreen({Key? key, required this.applicationId}) : super(key: key);

  @override
  State<VisaReportScreen> createState() => _VisaReportScreenState();
}

class _VisaReportScreenState extends State<VisaReportScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _applicationData;

  @override
  void initState() {
    super.initState();
    _fetchComprehensiveReport();
  }

  Future<void> _fetchComprehensiveReport() async {
    try {
      final response = await _supabase
          .from('visa_applications')
          .select('''
            *,
            risk_predictions(*),
            applicant_information(*),
            employment_information(*),
            financial_information(*),
            travel_information(*),
            supporting_documents(*), 
            payment_transactions(*)
          ''')
          .eq('id', widget.applicationId)
          .single();

      if (mounted) {
        setState(() {
          _applicationData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error loading comprehensive report data.", isError: true);
      }
    }
  }

  Map<String, dynamic>? _extractMap(dynamic source) {
    if (source is List && source.isNotEmpty) {
      return Map<String, dynamic>.from(source.first as Map);
    } else if (source is Map) {
      return Map<String, dynamic>.from(source);
    }
    return null;
  }

  /// FORMATTER: Scans for numbers like "1)" or "2." and injects clean double line breaks before them.
  String _formatAiReasoning(String? rawReason) {
    if (rawReason == null || rawReason.trim().isEmpty) return 'N/A';

    String formatted = rawReason.replaceAllMapped(
        RegExp(r'\s+(\d+[\)\.])\s*'),
            (Match m) => '\n\n${m[1]} '
    );

    return formatted.trim();
  }

  Future<void> _downloadFullPdfReport() async {
    if (_applicationData == null) return;

    try {
      final app = _applicationData!;
      final appId = app['id'] ?? 'N/A';
      final submittedAt = app['submitted_at'] != null ? app['submitted_at'].toString().split('T')[0] : 'N/A';

      final applicant = _extractMap(app['applicant_information']);
      final employment = _extractMap(app['employment_information']);
      final financial = _extractMap(app['financial_information']);
      final travel = _extractMap(app['travel_information']);
      final prediction = _extractMap(app['risk_predictions']);
      final payment = _extractMap(app['payment_transactions']);
      final documents = _extractMap(app['supporting_documents']);

      final double riskScore = double.tryParse(prediction?['risk_score']?.toString() ?? '0') ?? 0.0;
      final double successRate = 100.0 - riskScore;

      // Apply the precise formatter
      final formattedReason = _formatAiReasoning(prediction?['prediction_reason']);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("MALAYSIA IMMIGRATION SERVICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text("OFFICIAL VISA PRE-SCREENING ASSESSMENT REPORT", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Metadata
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Reference ID: #${appId.substring(0, 8).toUpperCase()}"),
                    pw.Text("Date: $submittedAt"),
                  ]
              ),
              pw.Text("Transaction ID: ${payment?['stripe_transaction_id'] ?? 'N/A'}"),
              pw.SizedBox(height: 24),

              // 1. AI Assessment Result
              _buildPdfSectionTitle("1. AI RISK ASSESSMENT RESULT"),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Visa Success Probability: ${successRate.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Risk Level: ${prediction?['risk_level'] ?? 'N/A'}"),
                    pw.Text("System Recommendation: ${prediction?['recommendation'] ?? 'N/A'}"),
                    pw.SizedBox(height: 12),
                    pw.Text("Assessment Reasoning:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      formattedReason,
                      style: const pw.TextStyle(color: PdfColors.grey800, lineSpacing: 1.5),
                      textAlign: pw.TextAlign.left,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. Applicant Information
              _buildPdfSectionTitle("2. APPLICANT INFORMATION"),
              _buildPdfRow("Full Name:", applicant?['full_name']),
              _buildPdfRow("Passport No:", applicant?['passport_number']),
              _buildPdfRow("Passport Expiry:", applicant?['passport_expiry_date']),
              _buildPdfRow("Nationality:", applicant?['nationality']),
              _buildPdfRow("Date of Birth:", applicant?['date_of_birth']),
              _buildPdfRow("Gender:", applicant?['gender']),
              _buildPdfRow("Phone:", applicant?['phone']),
              _buildPdfRow("Email:", applicant?['email']),
              pw.SizedBox(height: 16),

              // 3. Employment Information
              _buildPdfSectionTitle("3. EMPLOYMENT INFORMATION"),
              _buildPdfRow("Status:", employment?['employment_status']),
              _buildPdfRow("Company:", employment?['company_name']),
              _buildPdfRow("Job Title:", employment?['job_title']),
              _buildPdfRow("Monthly Income (MYR):", employment?['monthly_income']?.toString()),
              pw.SizedBox(height: 16),

              // 4. Financial Information
              _buildPdfSectionTitle("4. FINANCIAL INFORMATION"),
              _buildPdfRow("Bank Name:", financial?['bank_name']),
              _buildPdfRow("Account Balance (MYR):", financial?['account_balance']?.toString()),
              pw.SizedBox(height: 16),

              // 5. Travel Information
              _buildPdfSectionTitle("5. TRAVEL LOGISTICS"),
              _buildPdfRow("Purpose of Visit:", travel?['purpose_of_visit']),
              _buildPdfRow("Intended Destination:", travel?['intended_destination']),
              _buildPdfRow("Arrival Date:", travel?['arrival_date']),
              _buildPdfRow("Accommodation / Hotel:", travel?['hotel_name']),
              pw.SizedBox(height: 16),

              // 6. Supporting Documents
              _buildPdfSectionTitle("6. SUPPORTING DOCUMENTS"),
              _buildPdfRow("Document Attached:", documents != null && documents['file_url'] != null ? 'Yes (Uploaded)' : 'No Document Provided'),
              if (documents != null && documents['document_type'] != null)
                _buildPdfRow("Document Type:", documents['document_type']),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Visa_Assessment_Report_${appId.substring(0, 8)}.pdf',
      );

      _showSnackBar("Your PDF visa report has been downloaded successfully!");
    } catch (e) {
      _showSnackBar("Error generating PDF report. Please try again later.", isError: true);
    }
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
    );
  }

  pw.Widget _buildPdfRow(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 150, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text(value?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('ASSESSMENT REPORT', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _applicationData == null
          ? const Center(child: Text("Error loading report details.", style: TextStyle(color: Color(0xFF0F172A))))
          : _buildReportSummary(),
    );
  }

  Widget _buildReportSummary() {
    final prediction = _extractMap(_applicationData!['risk_predictions']);
    final double riskScore = double.tryParse(prediction?['risk_score']?.toString() ?? '0') ?? 0.0;
    final double successRate = 100.0 - riskScore;

    final bool isApproved = prediction?['recommendation'] == 'Approve';
    final bool isReview = prediction?['recommendation'] == 'Manual Review';

    final Color statusColor = isApproved ? const Color(0xFF15803D) : (isReview ? const Color(0xFFD97706) : const Color(0xFFDC2626));
    final IconData statusIcon = isApproved ? Icons.verified : (isReview ? Icons.warning_rounded : Icons.cancel);

    // Apply the formatter to the UI Reasoning block
    final formattedReasonUI = _formatAiReasoning(prediction?['prediction_reason']);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(statusIcon, size: 64, color: statusColor),
          const SizedBox(height: 16),
          const Text(
            "AI SUCCESS EVALUATION RATE",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            "${successRate.toStringAsFixed(1)}%",
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Status: ${prediction?['recommendation']?.toString().toUpperCase() ?? 'N/A'}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.memory, size: 18, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 8),
                    Text("AI Assessment Reasoning", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  formattedReasonUI,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            "Download the official PDF below for a complete breakdown of all submitted parameters.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _downloadFullPdfReport,
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: const Text(
                "DOWNLOAD COMPREHENSIVE PDF",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}