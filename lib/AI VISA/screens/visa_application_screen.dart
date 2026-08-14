import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoadingData = true;

  // 1. Applicant Info
  final _nameCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _passIssueCtrl = TextEditingController();
  final _passExpiryCtrl = TextEditingController();
  final _passCountryCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _residenceCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _eduCtrl = TextEditingController();
  final _occupCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();
  final _emergRelCtrl = TextEditingController();

  // Selection Boxes Variables
  String? _selectedGender;
  String? _selectedMaritalStatus;

  // 2. Employment Info
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

  // 3. Financial Info
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

  // 4. Travel Info
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

  // 5. Travel History
  final _histCountryCtrl = TextEditingController();
  final _histArrCtrl = TextEditingController();
  final _histDepCtrl = TextEditingController();
  final _histPurpCtrl = TextEditingController();
  bool _prevVisit = false;
  bool _prevOverstay = false;
  bool _prevDeport = false;
  bool _immigViol = false;

  // 6. Payment
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvcCtrl = TextEditingController();

  final _aiService = AiService();
  final _dbService = DatabaseService();
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadPreFilledData();
  }

  /// Automatically fetch and pre-fill fields based on registered profile and tourist details
  Future<void> _loadPreFilledData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }

      // 1. Fetch from Profiles Table
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (profileData != null) {
        _nameCtrl.text = profileData['full_name'] ?? '';
        _emailCtrl.text = profileData['email'] ?? '';
        _phoneCtrl.text = profileData['phone_number'] ?? '';
        _nationalityCtrl.text = profileData['nationality'] ?? '';

        // 2. Fetch from Tourists Table using the matching profile_id
        final touristData = await _supabase
            .from('tourists')
            .select()
            .eq('profile_id', profileData['id'])
            .maybeSingle();

        if (touristData != null) {
          _passportCtrl.text = touristData['passport_number'] ?? '';
          _passCountryCtrl.text = touristData['passport_issuing_country'] ?? '';
          _residenceCtrl.text = touristData['country_of_residence'] ?? '';

          if (touristData['passport_issue_date'] != null) {
            _passIssueCtrl.text = touristData['passport_issue_date'].toString();
          }
          if (touristData['passport_expiry_date'] != null) {
            _passExpiryCtrl.text = touristData['passport_expiry_date'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading pre-filled data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _passportCtrl.dispose(); _passIssueCtrl.dispose(); _passExpiryCtrl.dispose();
    _passCountryCtrl.dispose(); _nationalityCtrl.dispose(); _residenceCtrl.dispose();
    _dobCtrl.dispose(); _eduCtrl.dispose(); _occupCtrl.dispose();
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

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(controller),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3A8A), size: 20),
        ),
      ),
    );
  }

  Widget _buildSelectionBox(String title, List<String> options, String? currentValue, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: options.map((option) {
              final isSelected = currentValue == option;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: const Color(0xFF1E3A8A),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    onChanged(option);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyInputWithSlider(String label, TextEditingController controller, double maxVal) {
    double currentVal = double.tryParse(controller.text) ?? 0.0;
    if (currentVal > maxVal) currentVal = maxVal;
    if (currentVal < 0) currentVal = 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, prefixText: 'USD '),
            onChanged: (val) => setState(() {}),
          ),
          Slider(
            value: currentVal,
            min: 0,
            max: maxVal,
            activeColor: const Color(0xFF1E3A8A),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) {
              setState(() {
                controller.text = val.toInt().toString();
              });
            },
          ),
        ],
      ),
    );
  }

  bool _validateLogicalDates() {
    // Passport Issue vs Expiry
    DateTime? issue = DateTime.tryParse(_passIssueCtrl.text);
    DateTime? expiry = DateTime.tryParse(_passExpiryCtrl.text);
    if (issue != null && expiry != null && issue.isAfter(expiry)) {
      _showSnackBar("Passport Issue Date cannot be after Expiry Date (Step 1).", isError: true);
      return false;
    }

    // Travel Arrival vs Departure
    DateTime? arr = DateTime.tryParse(_arrDateCtrl.text);
    DateTime? dep = DateTime.tryParse(_depDateCtrl.text);
    if (arr != null && dep != null && arr.isAfter(dep)) {
      _showSnackBar("Arrival Date cannot be after Departure Date (Step 4).", isError: true);
      return false;
    }

    // History Arrival vs Departure
    DateTime? hArr = DateTime.tryParse(_histArrCtrl.text);
    DateTime? hDep = DateTime.tryParse(_histDepCtrl.text);
    if (hArr != null && hDep != null && hArr.isAfter(hDep)) {
      _showSnackBar("Past Arrival Date cannot be after Past Departure Date (Step 5).", isError: true);
      return false;
    }

    return true;
  }

  List<String> _getMissingMandatoryFields() {
    List<String> missing = [];
    if (_nameCtrl.text.trim().isEmpty) missing.add("Full Name (Step 1)");
    if (_passportCtrl.text.trim().isEmpty) missing.add("Passport Number (Step 1)");
    if (_nationalityCtrl.text.trim().isEmpty) missing.add("Nationality (Step 1)");
    if (_empStatusCtrl.text.trim().isEmpty) missing.add("Employment Status (Step 2)");
    return missing;
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
    final missingFormFields = _getMissingMandatoryFields();
    if (missingFormFields.isNotEmpty) {
      _showSnackBar("Missing required fields: ${missingFormFields.join(', ')}", isError: true);
      return false;
    }

    if (!_validateLogicalDates()) return false;

    final cleanedCardNumber = _cardNumberCtrl.text.replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^\d{16}$').hasMatch(cleanedCardNumber)) {
      _showSnackBar("Card Number must be exactly 16 digits.", isError: true);
      return false;
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim())) {
      _showSnackBar("Invalid Expiry Date format. Use MM/YY (e.g. 12/28).", isError: true);
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
      final Map<String, dynamic> fullApplicationData = {
        "applicant_information": {
          "full_name": _nameCtrl.text.trim(),
          "passport_number": _passportCtrl.text.trim(),
          "passport_issue_date": _passIssueCtrl.text.trim(),
          "passport_expiry_date": _passExpiryCtrl.text.trim(),
          "passport_country": _passCountryCtrl.text.trim(),
          "nationality": _nationalityCtrl.text.trim(),
          "country_of_residence": _residenceCtrl.text.trim(),
          "gender": _selectedGender ?? '',
          "date_of_birth": _dobCtrl.text.trim(),
          "marital_status": _selectedMaritalStatus ?? '',
          "education_level": _eduCtrl.text.trim(),
          "occupation": _occupCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
          "emergency_contact_name": _emergNameCtrl.text.trim(),
          "emergency_contact_phone": _emergPhoneCtrl.text.trim(),
          "emergency_relationship": _emergRelCtrl.text.trim(),
        },
        "employment_information": {
          "employment_status": _empStatusCtrl.text.trim(),
          "company_name": _compNameCtrl.text.trim(),
          "company_address": _compAddrCtrl.text.trim(),
          "company_phone": _compPhoneCtrl.text.trim(),
          "job_title": _jobTitleCtrl.text.trim(),
          "years_employed": _yearsEmpCtrl.text.trim(),
          "monthly_income_usd": _monthlyIncCtrl.text.trim(),
          "annual_income_usd": _annualIncCtrl.text.trim(),
        },
        "financial_information": {
          "bank_name": _bankNameCtrl.text.trim(),
          "account_balance_usd": _accBalCtrl.text.trim(),
          "monthly_expenses_usd": _mthlyExpCtrl.text.trim(),
          "has_credit_card": _hasCreditCard,
          "sponsor_required": _sponsorRequired,
          "sponsor_name": _sponsorNameCtrl.text.trim(),
          "sponsor_relationship": _sponsorRelCtrl.text.trim(),
          "sponsor_phone": _sponsorPhoneCtrl.text.trim(),
          "sponsor_email": _sponsorEmailCtrl.text.trim(),
        },
        "travel_logistics": {
          "purpose_of_visit": _purposeCtrl.text.trim(),
          "arrival_date": _arrDateCtrl.text.trim(),
          "departure_date": _depDateCtrl.text.trim(),
          "visa_expiry_date": _visaExpCtrl.text.trim(),
          "intended_destination": _destCtrl.text.trim(),
          "hotel_name": _hotelNameCtrl.text.trim(),
          "hotel_address": _hotelAddrCtrl.text.trim(),
          "accommodation_type": _accomTypeCtrl.text.trim(),
          "airline": _airlineCtrl.text.trim(),
          "flight_number": _flightNoCtrl.text.trim(),
          "return_ticket_secured": _returnTicket,
          "travel_insurance_purchased": _travelIns,
        },
        "travel_history": {
          "last_country_visited": _histCountryCtrl.text.trim(),
          "past_arrival_date": _histArrCtrl.text.trim(),
          "past_departure_date": _histDepCtrl.text.trim(),
          "past_visit_purpose": _histPurpCtrl.text.trim(),
          "previous_malaysia_visit": _prevVisit,
          "previous_overstay_record": _prevOverstay,
          "previous_deportation": _prevDeport,
          "immigration_violation": _immigViol,
        },
        "document_attached": _pickedFileName != null,
      };

      final aiResult = await _aiService.evaluateApplication(
        fullApplicationData: fullApplicationData,
      );

      await _dbService.submitVisaApplication(
        fullName: _nameCtrl.text, passportNo: _passportCtrl.text, passportIssueDate: _passIssueCtrl.text,
        passportExpiryDate: _passExpiryCtrl.text, passportCountry: _passCountryCtrl.text, nationality: _nationalityCtrl.text,
        countryOfResidence: _residenceCtrl.text, gender: _selectedGender ?? '', dob: _dobCtrl.text,
        maritalStatus: _selectedMaritalStatus ?? '', educationLevel: _eduCtrl.text, occupation: _occupCtrl.text,
        email: _emailCtrl.text, phone: _phoneCtrl.text, emergencyName: _emergNameCtrl.text,
        emergencyPhone: _emergPhoneCtrl.text, emergencyRel: _emergRelCtrl.text,

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
        _successRate = (100.0 - riskScore).clamp(0.0, 100.0);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Visa Pre-Screening', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoadingData) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
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
          onPressed: () => Navigator.of(context).pop(true),
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
      onStepTapped: (step) {
        setState(() => _currentStep = step);
      },
      onStepContinue: () {
        if (_currentStep < 6) {
          setState(() => _currentStep += 1);
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep -= 1);
        }
      },
      controlsBuilder: (context, details) {
        if (_currentStep == 6) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () {
                    if (_validateLogicalDates()) {
                      details.onStepContinue!();
                    }
                  },
                  child: const Text('Continue', style: TextStyle(color: Colors.white)),
                ),
              ),
              if (_currentStep != 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ),
              ]
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Applicant Details'),
          isActive: _currentStep >= 0,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name*'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _passportCtrl, decoration: const InputDecoration(labelText: 'Passport Number*'))),
            _buildDateField('Passport Issue Date', _passIssueCtrl),
            _buildDateField('Passport Expiry Date', _passExpiryCtrl),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _passCountryCtrl, decoration: const InputDecoration(labelText: 'Passport Issuing Country'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _nationalityCtrl, decoration: const InputDecoration(labelText: 'Nationality*'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _residenceCtrl, decoration: const InputDecoration(labelText: 'Country of Residence'))),
            _buildSelectionBox('Gender', ['Male', 'Female', 'Other'], _selectedGender, (val) => setState(() => _selectedGender = val)),
            _buildDateField('Date of Birth', _dobCtrl),
            _buildSelectionBox('Marital Status', ['Single', 'Couple', 'Married'], _selectedMaritalStatus, (val) => setState(() => _selectedMaritalStatus = val)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _eduCtrl, decoration: const InputDecoration(labelText: 'Education Level'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _occupCtrl, decoration: const InputDecoration(labelText: 'Occupation'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Phone'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergRelCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Relationship'))),
          ]),
        ),
        Step(
          title: const Text('Employment Info'),
          isActive: _currentStep >= 1,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _empStatusCtrl, decoration: const InputDecoration(labelText: 'Employment Status*'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compNameCtrl, decoration: const InputDecoration(labelText: 'Company Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compAddrCtrl, decoration: const InputDecoration(labelText: 'Company Address'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compPhoneCtrl, decoration: const InputDecoration(labelText: 'Company Phone'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _jobTitleCtrl, decoration: const InputDecoration(labelText: 'Job Title'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _yearsEmpCtrl, decoration: const InputDecoration(labelText: 'Years Employed'), keyboardType: TextInputType.number)),
            _buildMoneyInputWithSlider('Monthly Income', _monthlyIncCtrl, 10000000.0),
            _buildMoneyInputWithSlider('Annual Income', _annualIncCtrl, 100000000.0),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _empLetterUrlCtrl, decoration: const InputDecoration(labelText: 'Employer Letter URL'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _leaveLetterUrlCtrl, decoration: const InputDecoration(labelText: 'Leave Approval Letter URL'))),
          ]),
        ),
        Step(
          title: const Text('Financial Information'),
          isActive: _currentStep >= 2,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Primary Bank Name'))),
            _buildMoneyInputWithSlider('Account Balance', _accBalCtrl, 100000000.0),
            _buildMoneyInputWithSlider('Monthly Expenses', _mthlyExpCtrl, 10000000.0),
            SwitchListTile(title: const Text('Possess a Credit Card?', style: TextStyle(fontSize: 14)), value: _hasCreditCard, onChanged: (v) => setState(() => _hasCreditCard = v)),
            SwitchListTile(title: const Text('Sponsor Required?', style: TextStyle(fontSize: 14)), value: _sponsorRequired, onChanged: (v) => setState(() => _sponsorRequired = v)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _sponsorNameCtrl, decoration: const InputDecoration(labelText: 'Sponsor Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _sponsorRelCtrl, decoration: const InputDecoration(labelText: 'Sponsor Relationship'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _sponsorPhoneCtrl, decoration: const InputDecoration(labelText: 'Sponsor Phone'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _sponsorEmailCtrl, decoration: const InputDecoration(labelText: 'Sponsor Email'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _bankStmtUrlCtrl, decoration: const InputDecoration(labelText: 'Bank Statement URL'))),
          ]),
        ),
        Step(
          title: const Text('Travel Logistics'),
          isActive: _currentStep >= 3,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _purposeCtrl, decoration: const InputDecoration(labelText: 'Purpose of Visit'))),
            _buildDateField('Arrival Date', _arrDateCtrl),
            _buildDateField('Departure Date', _depDateCtrl),
            _buildDateField('Visa Expiry Date', _visaExpCtrl),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _destCtrl, decoration: const InputDecoration(labelText: 'Intended Destination'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _hotelNameCtrl, decoration: const InputDecoration(labelText: 'Hotel Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _hotelAddrCtrl, decoration: const InputDecoration(labelText: 'Hotel Address'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _accomTypeCtrl, decoration: const InputDecoration(labelText: 'Accommodation Type'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _airlineCtrl, decoration: const InputDecoration(labelText: 'Airline'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _flightNoCtrl, decoration: const InputDecoration(labelText: 'Flight Number'))),
            SwitchListTile(title: const Text('Return Ticket Secured?', style: TextStyle(fontSize: 14)), value: _returnTicket, onChanged: (v) => setState(() => _returnTicket = v)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _retTicketUrlCtrl, decoration: const InputDecoration(labelText: 'Return Ticket URL'))),
            SwitchListTile(title: const Text('Travel Insurance Purchased?', style: TextStyle(fontSize: 14)), value: _travelIns, onChanged: (v) => setState(() => _travelIns = v)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _travelInsUrlCtrl, decoration: const InputDecoration(labelText: 'Travel Insurance URL'))),
          ]),
        ),
        Step(
          title: const Text('Travel History'),
          isActive: _currentStep >= 4,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _histCountryCtrl, decoration: const InputDecoration(labelText: 'Last Country Visited'))),
            _buildDateField('Past Arrival Date', _histArrCtrl),
            _buildDateField('Past Departure Date', _histDepCtrl),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _histPurpCtrl, decoration: const InputDecoration(labelText: 'Past Visit Purpose'))),
            SwitchListTile(title: const Text('Previous Visit to Malaysia?', style: TextStyle(fontSize: 14)), value: _prevVisit, onChanged: (v) => setState(() => _prevVisit = v)),
            SwitchListTile(title: const Text('Previous Overstay Record?', style: TextStyle(fontSize: 14)), value: _prevOverstay, onChanged: (v) => setState(() => _prevOverstay = v)),
            SwitchListTile(title: const Text('Previous Deportation?', style: TextStyle(fontSize: 14)), value: _prevDeport, onChanged: (v) => setState(() => _prevDeport = v)),
            SwitchListTile(title: const Text('Any Immigration Violations?', style: TextStyle(fontSize: 14)), value: _immigViol, onChanged: (v) => setState(() => _immigViol = v)),
          ]),
        ),
        Step(
          title: const Text('Supporting Documents'),
          isActive: _currentStep >= 5,
          content: Column(children: [
            OutlinedButton.icon(
              onPressed: _handleDocumentUpload,
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedFileName ?? 'Attach Optional Document (PNG/PDF)'),
            ),
          ]),
        ),
        Step(
          title: const Text('Stripe Gateway Fee'),
          isActive: _currentStep >= 6,
          content: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Text("Mandatory Processing Fee: MYR 150.00", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            ),
            const SizedBox(height: 12),
            TextField(controller: _cardNumberCtrl, decoration: const InputDecoration(labelText: 'Card Number (16 Digits)'), keyboardType: TextInputType.number),
            Row(children: [
              Expanded(child: TextField(controller: _cardExpiryCtrl, decoration: const InputDecoration(labelText: 'MM/YY'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _cardCvcCtrl, decoration: const InputDecoration(labelText: 'CVC (3 Digits)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _processPaymentAndSubmit,
                child: const Text('Authorize Payment & Run AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}