import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/ai_service.dart';
import '../services/database_service.dart';

enum AppProcessState { fillingForm, stripeProcessing, stripeSuccess, aiProcessing, completed }

class VisaApplicationScreen extends StatefulWidget {
  const VisaApplicationScreen({Key? key}) : super(key: key);

  @override
  State<VisaApplicationScreen> createState() => _VisaApplicationScreenState();
}

class _VisaApplicationScreenState extends State<VisaApplicationScreen> {
  int _currentStep = 0;
  AppProcessState _processState = AppProcessState.fillingForm;
  double _successRate = 0.0;
  String _aiReasoning = "";

  String? _pickedFileName;
  String _uploadedFileUrl = "";
  bool _isUploadingDoc = false;

  // 1. Applicant Info Controllers
  final _nameCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _passIssueCtrl = TextEditingController();
  final _passExpiryCtrl = TextEditingController();
  final _passCountryCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _residenceCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _maritalCtrl = TextEditingController();
  final _eduCtrl = TextEditingController();
  final _occupCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();
  final _emergRelCtrl = TextEditingController();

  // 2. Employment Info Controllers
  final _empStatusCtrl = TextEditingController();
  final _compNameCtrl = TextEditingController();
  final _compAddrCtrl = TextEditingController();
  final _compPhoneCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _yearsEmpCtrl = TextEditingController();
  final _monthlyIncCtrl = TextEditingController();
  final _annualIncCtrl = TextEditingController();
  final _empLetterUrlCtrl = TextEditingController();
  final _leaveLetterUrlCtrl = TextEditingController();

  // 3. Financial Info Controllers
  final _bankNameCtrl = TextEditingController();
  final _accBalCtrl = TextEditingController();
  final _mthlyExpCtrl = TextEditingController();
  bool _hasCreditCard = false;
  bool _sponsorRequired = false;
  final _sponsorNameCtrl = TextEditingController();
  final _sponsorRelCtrl = TextEditingController();
  final _sponsorPhoneCtrl = TextEditingController();
  final _sponsorEmailCtrl = TextEditingController();
  final _bankStmtUrlCtrl = TextEditingController();

  // 4. Travel Info Controllers
  final _purposeCtrl = TextEditingController();
  final _arrDateCtrl = TextEditingController();
  final _depDateCtrl = TextEditingController();
  final _visaExpCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _hotelNameCtrl = TextEditingController();
  final _hotelAddrCtrl = TextEditingController();
  final _accomTypeCtrl = TextEditingController();
  final _airlineCtrl = TextEditingController();
  final _flightNoCtrl = TextEditingController();
  bool _returnTicket = false;
  final _retTicketUrlCtrl = TextEditingController();
  bool _travelIns = false;
  final _travelInsUrlCtrl = TextEditingController();

  // 5. Travel History Controllers
  final _histCountryCtrl = TextEditingController();
  final _histArrCtrl = TextEditingController();
  final _histDepCtrl = TextEditingController();
  final _histPurpCtrl = TextEditingController();
  bool _prevVisit = false;
  bool _prevOverstay = false;
  bool _prevDeport = false;
  bool _immigViol = false;

  // 6. Payment Controllers
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvcCtrl = TextEditingController();

  final _aiService = AiService();
  final _dbService = DatabaseService();

  @override
  void dispose() {
    _nameCtrl.dispose(); _passportCtrl.dispose(); _passIssueCtrl.dispose(); _passExpiryCtrl.dispose();
    _passCountryCtrl.dispose(); _nationalityCtrl.dispose(); _residenceCtrl.dispose(); _genderCtrl.dispose();
    _dobCtrl.dispose(); _maritalCtrl.dispose(); _eduCtrl.dispose(); _occupCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _emergNameCtrl.dispose(); _emergPhoneCtrl.dispose(); _emergRelCtrl.dispose();
    _empStatusCtrl.dispose(); _compNameCtrl.dispose(); _compAddrCtrl.dispose(); _compPhoneCtrl.dispose();
    _jobTitleCtrl.dispose(); _yearsEmpCtrl.dispose(); _monthlyIncCtrl.dispose(); _annualIncCtrl.dispose();
    _empLetterUrlCtrl.dispose(); _leaveLetterUrlCtrl.dispose(); _bankNameCtrl.dispose(); _accBalCtrl.dispose();
    _mthlyExpCtrl.dispose(); _sponsorNameCtrl.dispose(); _sponsorRelCtrl.dispose(); _sponsorPhoneCtrl.dispose();
    _sponsorEmailCtrl.dispose(); _bankStmtUrlCtrl.dispose(); _purposeCtrl.dispose(); _arrDateCtrl.dispose();
    _depDateCtrl.dispose(); _visaExpCtrl.dispose(); _destCtrl.dispose(); _hotelNameCtrl.dispose();
    _hotelAddrCtrl.dispose(); _accomTypeCtrl.dispose(); _airlineCtrl.dispose(); _flightNoCtrl.dispose();
    _retTicketUrlCtrl.dispose(); _travelInsUrlCtrl.dispose(); _histCountryCtrl.dispose(); _histArrCtrl.dispose();
    _histDepCtrl.dispose(); _histPurpCtrl.dispose(); _cardNumberCtrl.dispose(); _cardExpiryCtrl.dispose(); _cardCvcCtrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    if (step == 0 && (_nameCtrl.text.isEmpty || _passportCtrl.text.isEmpty || _nationalityCtrl.text.isEmpty)) {
      _showSnackBar("Please fill in mandatory Applicant fields.", isError: true); return false;
    }
    if (step == 1 && _empStatusCtrl.text.isEmpty) {
      _showSnackBar("Employment Status is required.", isError: true); return false;
    }
    return true;
  }

  Future<void> _handleDocumentUpload() async {
    setState(() => _isUploadingDoc = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg']);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFileName = result.files.single.name;
          _uploadedFileUrl = "local_cache_${DateTime.now().millisecondsSinceEpoch}";
        });
      }
    } catch (e) {
      debugPrint("FilePicker Error: $e");
    } finally {
      setState(() => _isUploadingDoc = false);
    }
  }

  bool _validatePaymentInputs() {
    final cleanedCardNumber = _cardNumberCtrl.text.replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^\d{16}$').hasMatch(cleanedCardNumber)) {
      _showSnackBar("Card number must be exactly 16 digits.", isError: true);
      return false;
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim())) {
      _showSnackBar("Invalid expiry date format. Use MM/YY.", isError: true);
      return false;
    }
    if (!RegExp(r'^\d{3}$').hasMatch(_cardCvcCtrl.text.trim())) {
      _showSnackBar("CVC must be exactly 3 digits.", isError: true);
      return false;
    }
    return true;
  }

  Future<void> _processPaymentAndSubmit() async {
    if (!_validatePaymentInputs()) return;

    setState(() => _processState = AppProcessState.stripeProcessing);
    await Future.delayed(const Duration(seconds: 2));

    final String txnId = "txn_${DateTime.now().millisecondsSinceEpoch}";

    setState(() => _processState = AppProcessState.stripeSuccess);
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() => _processState = AppProcessState.aiProcessing);

    try {
      double baseCompleteness = _pickedFileName != null ? 100.0 : 85.0;
      final aiResult = await _aiService.evaluateApplication(
        completenessScore: baseCompleteness,
        nationality: _nationalityCtrl.text,
        purpose: _purposeCtrl.text,
        income: _monthlyIncCtrl.text,
      );

      await _dbService.submitVisaApplication(
        fullName: _nameCtrl.text, passportNo: _passportCtrl.text, passportIssueDate: _passIssueCtrl.text,
        passportExpiryDate: _passExpiryCtrl.text, passportCountry: _passCountryCtrl.text, nationality: _nationalityCtrl.text,
        countryOfResidence: _residenceCtrl.text, gender: _genderCtrl.text, dob: _dobCtrl.text, maritalStatus: _maritalCtrl.text,
        educationLevel: _eduCtrl.text, occupation: _occupCtrl.text, email: _emailCtrl.text, phone: _phoneCtrl.text,
        emergencyName: _emergNameCtrl.text, emergencyPhone: _emergPhoneCtrl.text, emergencyRel: _emergRelCtrl.text,

        employmentStatus: _empStatusCtrl.text, companyName: _compNameCtrl.text, companyAddress: _compAddrCtrl.text,
        companyPhone: _compPhoneCtrl.text, jobTitle: _jobTitleCtrl.text, yearsEmployed: _yearsEmpCtrl.text,
        monthlyIncome: _monthlyIncCtrl.text, annualIncome: _annualIncCtrl.text, employerLetterUrl: _empLetterUrlCtrl.text,
        leaveApprovalUrl: _leaveLetterUrlCtrl.text,

        bankName: _bankNameCtrl.text, accountBalance: _accBalCtrl.text, monthlyExpense: _mthlyExpCtrl.text,
        hasCreditCard: _hasCreditCard, sponsorRequired: _sponsorRequired, sponsorName: _sponsorNameCtrl.text,
        sponsorRel: _sponsorRelCtrl.text, sponsorPhone: _sponsorPhoneCtrl.text, sponsorEmail: _sponsorEmailCtrl.text,
        bankStatementUrl: _bankStmtUrlCtrl.text,

        purpose: _purposeCtrl.text, arrivalDate: _arrDateCtrl.text, departureDate: _depDateCtrl.text,
        visaExpiryDate: _visaExpCtrl.text, destination: _destCtrl.text, hotelName: _hotelNameCtrl.text,
        hotelAddress: _hotelAddrCtrl.text, accomType: _accomTypeCtrl.text, airline: _airlineCtrl.text,
        flightNo: _flightNoCtrl.text, returnTicket: _returnTicket, returnTicketUrl: _retTicketUrlCtrl.text,
        travelInsurance: _travelIns, travelInsuranceUrl: _travelInsUrlCtrl.text,

        histCountry: _histCountryCtrl.text, histArrival: _histArrCtrl.text, histDeparture: _histDepCtrl.text,
        histPurpose: _histPurpCtrl.text, prevVisit: _prevVisit, prevOverstay: _prevOverstay,
        prevDeportation: _prevDeport, immigViolation: _immigViol,

        docType: "Other", docUrl: _uploadedFileUrl,

        stripeTransactionId: txnId, paymentAmount: 150.00, aiResult: aiResult,
      );

      double riskScore = (aiResult['risk_score'] as num).toDouble();
      setState(() {
        _successRate = (100.0 - riskScore + (_pickedFileName != null ? 10.0 : 0.0)).clamp(0.0, 100.0);
        _aiReasoning = aiResult['prediction_reason'] ?? "Assessment finalized successfully.";
        _processState = AppProcessState.completed;
      });
    } catch (e) {
      setState(() => _processState = AppProcessState.fillingForm);
      _showSnackBar("AI calculation error: $e", isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Visa Pre-Screening', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Color(0xFF0F172A))),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildBodyContent()),
    );
  }

  Widget _buildBodyContent() {
    if (_processState == AppProcessState.stripeProcessing) return _buildStatusView("Verifying Gateway Credentials...", Icons.lock_outline, isSpinner: true);
    if (_processState == AppProcessState.stripeSuccess) return _buildStatusView("Payment Authorized (MYR 150.00)", Icons.check_circle_rounded, isSuccess: true);
    if (_processState == AppProcessState.aiProcessing) return _buildStatusView("Gemini AI Calculating Risk Probability...", Icons.memory, isSpinner: true);
    if (_processState == AppProcessState.completed) return _buildCompletedResult();
    return _buildStepperForm();
  }

  Widget _buildStatusView(String text, IconData icon, {bool isSpinner = false, bool isSuccess = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isSpinner) const CircularProgressIndicator(color: Color(0xFF1E3A8A)) else Icon(icon, color: isSuccess ? const Color(0xFF15803D) : const Color(0xFF1E3A8A), size: 64),
          const SizedBox(height: 24),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildCompletedResult() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 20),
        const Center(child: Icon(Icons.verified, size: 64, color: Color(0xFF15803D))),
        const SizedBox(height: 12),
        const Center(child: Text("Payment Successful & Risk Calculated", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D)))),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            children: [
              const Text("PASSPORT VALIDITY SCORE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
              const SizedBox(height: 8),
              Text("${_successRate.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 12),
              Text(_aiReasoning, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Return to Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildStepperForm() {
    return Stepper(
      physics: const BouncingScrollPhysics(),
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepTapped: (step) { if (step < _currentStep || _validateStep(_currentStep)) setState(() => _currentStep = step); },
      onStepContinue: () { if (_currentStep < 6 && _validateStep(_currentStep)) setState(() => _currentStep += 1); },
      onStepCancel: () { if (_currentStep > 0) setState(() => _currentStep -= 1); },
      controlsBuilder: (context, details) {
        if (_currentStep == 6) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)), onPressed: details.onStepContinue, child: const Text('Continue', style: TextStyle(color: Colors.white)))),
              if (_currentStep != 0) ...[const SizedBox(width: 12), Expanded(child: OutlinedButton(onPressed: details.onStepCancel, child: const Text('Back')))]
            ],
          ),
        );
      },
      steps: [
        // 1. Applicant Info
        Step(
          title: const Text('Applicant Details'),
          isActive: _currentStep >= 0,
          content: Column(children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name*')),
            TextField(controller: _passportCtrl, decoration: const InputDecoration(labelText: 'Passport Number*')),
            TextField(controller: _passIssueCtrl, decoration: const InputDecoration(labelText: 'Passport Issue Date (YYYY-MM-DD)')),
            TextField(controller: _passExpiryCtrl, decoration: const InputDecoration(labelText: 'Passport Expiry Date (YYYY-MM-DD)')),
            TextField(controller: _passCountryCtrl, decoration: const InputDecoration(labelText: 'Passport Issuing Country')),
            TextField(controller: _nationalityCtrl, decoration: const InputDecoration(labelText: 'Nationality*')),
            TextField(controller: _residenceCtrl, decoration: const InputDecoration(labelText: 'Country of Residence')),
            TextField(controller: _genderCtrl, decoration: const InputDecoration(labelText: 'Gender')),
            TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)')),
            TextField(controller: _maritalCtrl, decoration: const InputDecoration(labelText: 'Marital Status')),
            TextField(controller: _eduCtrl, decoration: const InputDecoration(labelText: 'Education Level')),
            TextField(controller: _occupCtrl, decoration: const InputDecoration(labelText: 'Occupation')),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
            TextField(controller: _emergNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
            TextField(controller: _emergPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Phone')),
            TextField(controller: _emergRelCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Relationship')),
          ]),
        ),
        // 2. Employment Info
        Step(
          title: const Text('Employment Info'),
          isActive: _currentStep >= 1,
          content: Column(children: [
            TextField(controller: _empStatusCtrl, decoration: const InputDecoration(labelText: 'Employment Status*')),
            TextField(controller: _compNameCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
            TextField(controller: _compAddrCtrl, decoration: const InputDecoration(labelText: 'Company Address')),
            TextField(controller: _compPhoneCtrl, decoration: const InputDecoration(labelText: 'Company Phone')),
            TextField(controller: _jobTitleCtrl, decoration: const InputDecoration(labelText: 'Job Title')),
            TextField(controller: _yearsEmpCtrl, decoration: const InputDecoration(labelText: 'Years Employed'), keyboardType: TextInputType.number),
            TextField(controller: _monthlyIncCtrl, decoration: const InputDecoration(labelText: 'Monthly Income (USD)'), keyboardType: TextInputType.number),
            TextField(controller: _annualIncCtrl, decoration: const InputDecoration(labelText: 'Annual Income (USD)'), keyboardType: TextInputType.number),
            TextField(controller: _empLetterUrlCtrl, decoration: const InputDecoration(labelText: 'Employer Letter URL')),
            TextField(controller: _leaveLetterUrlCtrl, decoration: const InputDecoration(labelText: 'Leave Approval Letter URL')),
          ]),
        ),
        // 3. Financial Info
        Step(
          title: const Text('Financial Information'),
          isActive: _currentStep >= 2,
          content: Column(children: [
            TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Primary Bank Name')),
            TextField(controller: _accBalCtrl, decoration: const InputDecoration(labelText: 'Account Balance (USD)'), keyboardType: TextInputType.number),
            TextField(controller: _mthlyExpCtrl, decoration: const InputDecoration(labelText: 'Monthly Expenses (USD)'), keyboardType: TextInputType.number),
            SwitchListTile(title: const Text('Possess a Credit Card?', style: TextStyle(fontSize: 14)), value: _hasCreditCard, onChanged: (v) => setState(() => _hasCreditCard = v)),
            SwitchListTile(title: const Text('Sponsor Required?', style: TextStyle(fontSize: 14)), value: _sponsorRequired, onChanged: (v) => setState(() => _sponsorRequired = v)),
            TextField(controller: _sponsorNameCtrl, decoration: const InputDecoration(labelText: 'Sponsor Name')),
            TextField(controller: _sponsorRelCtrl, decoration: const InputDecoration(labelText: 'Sponsor Relationship')),
            TextField(controller: _sponsorPhoneCtrl, decoration: const InputDecoration(labelText: 'Sponsor Phone')),
            TextField(controller: _sponsorEmailCtrl, decoration: const InputDecoration(labelText: 'Sponsor Email')),
            TextField(controller: _bankStmtUrlCtrl, decoration: const InputDecoration(labelText: 'Bank Statement URL')),
          ]),
        ),
        // 4. Travel Info
        Step(
          title: const Text('Travel Logistics'),
          isActive: _currentStep >= 3,
          content: Column(children: [
            TextField(controller: _purposeCtrl, decoration: const InputDecoration(labelText: 'Purpose of Visit')),
            TextField(controller: _arrDateCtrl, decoration: const InputDecoration(labelText: 'Arrival Date (YYYY-MM-DD)')),
            TextField(controller: _depDateCtrl, decoration: const InputDecoration(labelText: 'Departure Date (YYYY-MM-DD)')),
            TextField(controller: _visaExpCtrl, decoration: const InputDecoration(labelText: 'Visa Expiry Date (YYYY-MM-DD)')),
            TextField(controller: _destCtrl, decoration: const InputDecoration(labelText: 'Intended Destination')),
            TextField(controller: _hotelNameCtrl, decoration: const InputDecoration(labelText: 'Hotel Name')),
            TextField(controller: _hotelAddrCtrl, decoration: const InputDecoration(labelText: 'Hotel Address')),
            TextField(controller: _accomTypeCtrl, decoration: const InputDecoration(labelText: 'Accommodation Type')),
            TextField(controller: _airlineCtrl, decoration: const InputDecoration(labelText: 'Airline')),
            TextField(controller: _flightNoCtrl, decoration: const InputDecoration(labelText: 'Flight Number')),
            SwitchListTile(title: const Text('Return Ticket Secured?', style: TextStyle(fontSize: 14)), value: _returnTicket, onChanged: (v) => setState(() => _returnTicket = v)),
            TextField(controller: _retTicketUrlCtrl, decoration: const InputDecoration(labelText: 'Return Ticket URL')),
            SwitchListTile(title: const Text('Travel Insurance Purchased?', style: TextStyle(fontSize: 14)), value: _travelIns, onChanged: (v) => setState(() => _travelIns = v)),
            TextField(controller: _travelInsUrlCtrl, decoration: const InputDecoration(labelText: 'Travel Insurance URL')),
          ]),
        ),
        // 5. Travel History
        Step(
          title: const Text('Travel History'),
          isActive: _currentStep >= 4,
          content: Column(children: [
            TextField(controller: _histCountryCtrl, decoration: const InputDecoration(labelText: 'Last Country Visited')),
            TextField(controller: _histArrCtrl, decoration: const InputDecoration(labelText: 'Past Arrival Date (YYYY-MM-DD)')),
            TextField(controller: _histDepCtrl, decoration: const InputDecoration(labelText: 'Past Departure Date (YYYY-MM-DD)')),
            TextField(controller: _histPurpCtrl, decoration: const InputDecoration(labelText: 'Past Visit Purpose')),
            SwitchListTile(title: const Text('Previous Visit to Malaysia?', style: TextStyle(fontSize: 14)), value: _prevVisit, onChanged: (v) => setState(() => _prevVisit = v)),
            SwitchListTile(title: const Text('Previous Overstay Record?', style: TextStyle(fontSize: 14)), value: _prevOverstay, onChanged: (v) => setState(() => _prevOverstay = v)),
            SwitchListTile(title: const Text('Previous Deportation?', style: TextStyle(fontSize: 14)), value: _prevDeport, onChanged: (v) => setState(() => _prevDeport = v)),
            SwitchListTile(title: const Text('Any Immigration Violations?', style: TextStyle(fontSize: 14)), value: _immigViol, onChanged: (v) => setState(() => _immigViol = v)),
          ]),
        ),
        // 6. Documents
        Step(
          title: const Text('Supporting Documents'),
          isActive: _currentStep >= 5,
          content: Column(children: [
            OutlinedButton.icon(onPressed: _handleDocumentUpload, icon: const Icon(Icons.attach_file), label: Text(_pickedFileName ?? 'Attach Optional Document (PNG/PDF)')),
          ]),
        ),
        // 7. Payment
        Step(
          title: const Text('Stripe Gateway Fee'),
          isActive: _currentStep >= 6,
          content: Column(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: const Text("Mandatory Processing Fee: MYR 150.00", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
            const SizedBox(height: 12),
            TextField(controller: _cardNumberCtrl, decoration: const InputDecoration(labelText: 'Card Number (16 Digits)'), keyboardType: TextInputType.number),
            Row(children: [
              Expanded(child: TextField(controller: _cardExpiryCtrl, decoration: const InputDecoration(labelText: 'MM/YY'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _cardCvcCtrl, decoration: const InputDecoration(labelText: 'CVC (3 Digits)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _processPaymentAndSubmit, child: const Text('Authorize Payment & Run AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ),
      ],
    );
  }
}