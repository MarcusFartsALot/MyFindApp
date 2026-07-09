import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

class VisaApplicationScreen extends StatefulWidget {
  const VisaApplicationScreen({Key? key}) : super(key: key);

  @override
  State<VisaApplicationScreen> createState() => _VisaApplicationScreenState();
}

class _VisaApplicationScreenState extends State<VisaApplicationScreen> {
  int _currentStep = 0;
  bool _isSubmitted = false;
  bool _isAnalyzing = false;
  double _successRate = 0.0;
  String _aiReasoning = "";

  String? _pickedFileName;
  bool _isUploadingDoc = false;

  final _nameController = TextEditingController();
  final _passportController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _dobController = TextEditingController();

  final _employmentStatusController = TextEditingController();
  final _companyController = TextEditingController();
  final _incomeController = TextEditingController();

  final _purposeController = TextEditingController();
  final _destinationController = TextEditingController();
  final _arrivalDateController = TextEditingController();
  final _accountBalanceController = TextEditingController();

  final _aiService = AiService();
  final _dbService = DatabaseService();

  Future<void> _handleDocumentUpload() async {
    setState(() => _isUploadingDoc = true);
    try {
      // Ensure we are awaiting the platform call correctly
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("FilePicker Error: $e");
    } finally {
      setState(() => _isUploadingDoc = false);
    }
  }

  Future<void> _submitApplication() async {
    setState(() {
      _isSubmitted = true;
      _isAnalyzing = true;
    });

    try {
      double baseCompleteness = _pickedFileName != null ? 100.0 : 85.0;

      final aiResult = await _aiService.evaluateApplication(
        completenessScore: baseCompleteness,
        nationality: _nationalityController.text,
        purpose: _purposeController.text,
        income: _incomeController.text,
      );

      await _dbService.submitVisaApplication(
        fullName: _nameController.text,
        passportNo: _passportController.text,
        nationality: _nationalityController.text,
        employmentStatus: _employmentStatusController.text,
        companyName: _companyController.text,
        monthlyIncome: _incomeController.text,
        purpose: _purposeController.text,
        arrivalDate: _arrivalDateController.text,
        destination: _destinationController.text,
        aiResult: aiResult,
      );

      double riskScore = (aiResult['risk_score'] as num).toDouble();

      setState(() {
        double computedSuccess = 100.0 - riskScore;
        if (_pickedFileName != null) {
          computedSuccess = (computedSuccess + 10.0).clamp(0.0, 100.0);
        }

        _successRate = computedSuccess;
        _aiReasoning = aiResult['prediction_reason'] ?? "Assessment finalized.";
        _isAnalyzing = false;
      });

    } catch (e) {
      print("Error: $e");
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _downloadPdfReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text("VM2026 Visa Assessment Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Text("Applicant Name: ${_nameController.text}"),
              pw.Text("Passport Number: ${_passportController.text}"),
              pw.Text("Nationality: ${_nationalityController.text}"),
              pw.Text("Attached Document: ${_pickedFileName ?? 'None'}"),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text("AI Assessment Result", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text("Success Rate: ${_successRate.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 16, color: PdfColors.blue800)),
              pw.SizedBox(height: 10),
              pw.Text("Reasoning: $_aiReasoning"),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Visa_Assessment_Report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('VM2026 VISA APPLICATION', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isSubmitted ? _buildAssessmentResult() : _buildStepperForm(),
    );
  }

  Widget _buildAssessmentResult() {
    IconData iconData;
    Color statusColor;
    String statusText;

    if (_successRate >= 80) {
      iconData = CupertinoIcons.check_mark_circled_solid;
      statusColor = CupertinoColors.activeGreen;
      statusText = "High Success Rate";
    } else if (_successRate >= 50) {
      iconData = CupertinoIcons.exclamationmark_triangle_fill;
      statusColor = CupertinoColors.systemYellow;
      statusText = "Medium Success Rate";
    } else {
      iconData = CupertinoIcons.xmark_circle_fill;
      statusColor = CupertinoColors.destructiveRed;
      statusText = "Low Success Rate";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOutBack,
              child: _isAnalyzing
                  ? const SizedBox(
                key: ValueKey('loading'),
                height: 80,
                width: 80,
                child: CircularProgressIndicator(strokeWidth: 5, color: Colors.blue),
              )
                  : Column(
                key: const ValueKey('result_block'),
                children: [
                  Icon(iconData, color: statusColor, size: 100),
                  const SizedBox(height: 16),
                  Text(
                    "${_successRate.toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: -1),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!_isAnalyzing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  _aiReasoning,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                ),
              ),
              const SizedBox(height: 44),
              CupertinoButton(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(14),
                onPressed: _downloadPdfReport,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Download Report Summary", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStepperForm() {
    return Stepper(
      physics: const BouncingScrollPhysics(),
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepTapped: (step) => setState(() => _currentStep = step),
      onStepContinue: () {
        if (_currentStep < 3) {
          setState(() => _currentStep += 1);
        } else {
          _submitApplication();
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep -= 1);
        }
      },
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 3 ? 'Submit Application' : 'Continue', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              if (_currentStep != 0) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: CupertinoButton(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: details.onStepCancel,
                    child: const Text('Previous', style: TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ]
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold)),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name (as per Passport)')),
              TextField(controller: _passportController, decoration: const InputDecoration(labelText: 'Passport Number')),
              TextField(controller: _nationalityController, decoration: const InputDecoration(labelText: 'Nationality')),
              TextField(controller: _dobController, decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)')),
            ],
          ),
        ),
        Step(
          title: const Text('Employment & Verification', style: TextStyle(fontWeight: FontWeight.bold)),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          content: Column(
            children: [
              TextField(controller: _employmentStatusController, decoration: const InputDecoration(labelText: 'Employment Status')),
              TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company/Organization Name')),
              TextField(controller: _incomeController, decoration: const InputDecoration(labelText: 'Monthly Income (USD)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        Step(
          title: const Text('Travel Logistics', style: TextStyle(fontWeight: FontWeight.bold)),
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          content: Column(
            children: [
              TextField(controller: _purposeController, decoration: const InputDecoration(labelText: 'Purpose of Visit')),
              TextField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Intended Destination city')),
              TextField(controller: _arrivalDateController, decoration: const InputDecoration(labelText: 'Expected Arrival Date (YYYY-MM-DD)')),
              TextField(controller: _accountBalanceController, decoration: const InputDecoration(labelText: 'Liquid Funds Balance (USD)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        Step(
          title: const Text('Supporting Documentation', style: TextStyle(fontWeight: FontWeight.bold)),
          isActive: _currentStep >= 3,
          state: _currentStep == 3 ? StepState.editing : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload formal supplementary proofs (e.g., Bank Statements, Letter of Invitation) to maximize profile validity and optimization score.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isUploadingDoc ? null : _handleDocumentUpload,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.cloud_upload_fill, size: 40, color: Colors.blue[400]),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFileName ?? "Tap to choose file streams",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: _pickedFileName != null ? FontWeight.bold : FontWeight.normal,
                            color: _pickedFileName != null ? Colors.green[700] : Colors.black54
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text("Acceptable Formats: PDF, PNG only", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}