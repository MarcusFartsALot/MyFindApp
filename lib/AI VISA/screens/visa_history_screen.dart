import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../M400/models/profile_model.dart';

class VisaHistoryScreen extends StatefulWidget {
  final ProfileModel profile;

  const VisaHistoryScreen({super.key, required this.profile});

  @override
  State<VisaHistoryScreen> createState() => _VisaHistoryScreenState();
}

class _VisaHistoryScreenState extends State<VisaHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _fetchVisaHistory();
  }

  Future<void> _fetchVisaHistory() async {
    setState(() => _isLoading = true);
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
          .eq('user_id', widget.profile.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _applications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatusDialog(
          title: "Query Error",
          message: "Unable to retrieve your visa history records at this moment. Please check your internet connection.",
          isError: true,
        );
      }
    }
  }

  /// Custom UI Modal Dialog for Success, Error, and Validation Feedback
  void _showStatusDialog({
    required String title,
    required String message,
    bool isError = false,
    bool isInfo = false,
    String buttonText = "OK",
    VoidCallback? onConfirm,
  }) {
    if (!mounted) return;

    final Color themeColor = isError
        ? const Color(0xFFDC2626)
        : (isInfo ? const Color(0xFF1E3A8A) : const Color(0xFF15803D));

    final IconData statusIcon = isError
        ? Icons.error_outline_rounded
        : (isInfo ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: themeColor, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (onConfirm != null) onConfirm();
                },
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats the AI reasoning by forcing line breaks before numbers like "1)", "2)", or "1.", "2."
  String _formatAiReasoning(String? rawReason) {
    if (rawReason == null || rawReason.trim().isEmpty) return 'N/A';
    String formatted = rawReason.replaceAllMapped(
        RegExp(r'\s+(\d+[\)\.])\s*'),
            (Match m) => '\n\n${m[1]} '
    );
    return formatted.trim();
  }

  Future<void> _downloadPdfReport(Map<String, dynamic> app) async {
    try {
      final String appId = app['id'] ?? 'N/A';
      final String submittedAt = app['submitted_at'] != null
          ? app['submitted_at'].toString().split('T')[0]
          : 'N/A';

      final applicant = _extractMap(app['applicant_information']);
      final employment = _extractMap(app['employment_information']);
      final financial = _extractMap(app['financial_information']);
      final travel = _extractMap(app['travel_information']);
      final prediction = _extractMap(app['risk_predictions']);
      final payment = _extractMap(app['payment_transactions']);
      final documents = _extractMap(app['supporting_documents']);

      final double riskScore = double.tryParse(prediction?['risk_score']?.toString() ?? '0') ?? 0.0;
      final double successRate = 100.0 - riskScore;

      final formattedReason = _formatAiReasoning(prediction?['prediction_reason']);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("MALAYSIA VISA APPLICATION SERVICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text("OFFICIAL VISA ASSESSMENT REPORT", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
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
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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

              // 2. Tourist Information
              _buildPdfSectionTitle("2. TOURIST INFORMATION"),
              _buildPdfRow("Full Name:", applicant?['full_name']),
              _buildPdfRow("Passport No:", applicant?['passport_number']),
              _buildPdfRow("Passport Issue Date:", applicant?['passport_issue_date']),
              _buildPdfRow("Passport Expiry Date:", applicant?['passport_expiry_date']),
              _buildPdfRow("Passport Issuing Country:", applicant?['passport_country']),
              _buildPdfRow("Nationality:", applicant?['nationality']),
              _buildPdfRow("Country of Residence:", applicant?['country_of_residence']),
              _buildPdfRow("Date of Birth:", applicant?['date_of_birth']),
              _buildPdfRow("Gender:", applicant?['gender']),
              _buildPdfRow("Marital Status:", applicant?['marital_status']),
              _buildPdfRow("Education Level:", applicant?['education_level']),
              _buildPdfRow("Occupation:", applicant?['occupation']),
              _buildPdfRow("Phone:", applicant?['phone']),
              _buildPdfRow("Email:", applicant?['email']),
              _buildPdfRow("Emergency Contact Name:", applicant?['emergency_contact_name']),
              _buildPdfRow("Emergency Contact Phone:", applicant?['emergency_contact_phone']),
              _buildPdfRow("Emergency Relationship:", applicant?['emergency_relationship']),
              pw.SizedBox(height: 16),

              // 3. Employment Information
              _buildPdfSectionTitle("3. EMPLOYMENT INFORMATION"),
              _buildPdfRow("Employment Status:", employment?['employment_status']),
              _buildPdfRow("Company Name:", employment?['company_name']),
              _buildPdfRow("Company Address:", employment?['company_address']),
              _buildPdfRow("Company Phone:", employment?['company_phone']),
              _buildPdfRow("Job Title:", employment?['job_title']),
              _buildPdfRow("Years Employed:", employment?['years_employed']?.toString()),
              _buildPdfRow("Monthly Income (MYR):", employment?['monthly_income']?.toString()),
              _buildPdfRow("Annual Income (MYR):", employment?['annual_income']?.toString()),
              pw.SizedBox(height: 16),

              // 4. Financial Information
              _buildPdfSectionTitle("4. FINANCIAL INFORMATION"),
              _buildPdfRow("Bank Name:", financial?['bank_name']),
              _buildPdfRow("Account Balance (MYR):", financial?['account_balance']?.toString()),
              _buildPdfRow("Monthly Expenses (MYR):", financial?['monthly_expense']?.toString()),
              pw.SizedBox(height: 16),

              // 5. Travel Information
              _buildPdfSectionTitle("5. TRAVEL INFORMATION"),
              _buildPdfRow("Purpose of Visit:", travel?['purpose_of_visit']),
              _buildPdfRow("Intended Destination:", travel?['intended_destination']),
              _buildPdfRow("Arrival Date:", travel?['arrival_date']),
              _buildPdfRow("Departure Date:", travel?['departure_date']),
              _buildPdfRow("Visa Expiry Date:", travel?['visa_expiry_date']),
              _buildPdfRow("Accommodation / Hotel:", travel?['hotel_name']),
              _buildPdfRow("Hotel Address:", travel?['hotel_address']),
              _buildPdfRow("Accommodation Type:", travel?['accommodation_type']),
              _buildPdfRow("Airline:", travel?['airline']),
              _buildPdfRow("Flight Number:", travel?['flight_number']),
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

      _showStatusDialog(
        title: "Report Downloaded Successfully",
        message: "Your official visa assessment PDF report has been generated.",
        isError: false,
      );
    } catch (e) {
      _showStatusDialog(
        title: "Download Failed",
        message: "An unexpected error occurred while generating the PDF report. Please try again.",
        isError: true,
      );
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
          pw.SizedBox(width: 170, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text(value?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Map<String, dynamic>? _extractMap(dynamic source) {
    if (source is List && source.isNotEmpty) {
      return Map<String, dynamic>.from(source.first as Map);
    } else if (source is Map) {
      return Map<String, dynamic>.from(source);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _applications.isEmpty
          ? _buildEmptyState()
          : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Application Records",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              "You haven't submitted any visa applications yet. Head over to Overview to start a new application.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _fetchVisaHistory,
      color: const Color(0xFF1E3A8A),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final app = _applications[index];
          final String appId = app['id'] ?? 'N/A';
          final String submittedAt = app['submitted_at'] != null
              ? app['submitted_at'].toString().split('T')[0]
              : 'N/A';

          final applicant = _extractMap(app['applicant_information']);
          final travel = _extractMap(app['travel_information']);
          final prediction = _extractMap(app['risk_predictions']);
          final payment = _extractMap(app['payment_transactions']);

          final String txnId = payment?['stripe_transaction_id'] ?? 'N/A';
          final double riskScore = double.tryParse(prediction?['risk_score']?.toString() ?? '0') ?? 0.0;
          final double successRate = 100.0 - riskScore;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              shape: const Border(),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: successRate >= 70
                    ? const Color(0xFFDCFCE7)
                    : (successRate >= 40 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                child: Icon(
                  successRate >= 70 ? Icons.check_rounded : (successRate >= 40 ? Icons.priority_high_rounded : Icons.close_rounded),
                  size: 18,
                  color: successRate >= 70 ? const Color(0xFF15803D) : (successRate >= 40 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                ),
              ),
              title: Text(
                'REF: #${appId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                'Submitted: $submittedAt',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${successRate.toStringAsFixed(0)}% Score',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF8FAFC),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      _infoRow('Tourist', applicant?['full_name'] ?? widget.profile.fullName),
                      _infoRow('Passport', applicant?['passport_number'] ?? 'N/A'),
                      _infoRow('Nationality', applicant?['nationality'] ?? 'N/A'),
                      _infoRow('Destination', travel?['intended_destination'] ?? 'N/A'),
                      _infoRow('Transaction ID', txnId),
                      _infoRow('AI Risk Level', prediction?['risk_level'] ?? 'N/A'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _downloadPdfReport(app),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFF1E3A8A)),
                          label: const Text('Download Official PDF', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}