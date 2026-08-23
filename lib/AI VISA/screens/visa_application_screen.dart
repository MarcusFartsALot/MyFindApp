import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW: Required for local caching

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
  final _occupCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();
  final _emergRelCtrl = TextEditingController();

  // Selection Boxes & Dropdown Variables
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _selectedEduLevel;
  String? _selectedEmpStatus;
  String? _selectedState;
  String? _selectedKlZone;
  String? _selectedAccomType;

  // Dropdown Data Lists
  final List<String> _educationLevels = [
    'Primary School',
    'Secondary School',
    'Higher Education'
  ];

  final List<String> _employmentStatuses = [
    'Full-Time Employee',
    'Part-Time Employee',
    'Contract Employee',
    'Self-Employed'
  ];

  final List<String> _malaysiaStates = [
    'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan', 'Pahang',
    'Penang', 'Perak', 'Perlis', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu',
    'Kuala Lumpur', 'Labuan', 'Putrajaya'
  ];

  final List<String> _klZones = [
    'Kepong', 'Batu', 'Wangsa Maju', 'Segambut', 'Setiawangsa', 'Titiwangsa',
    'Bukit Bintang', 'Lembah Pantai', 'Seputeh', 'Cheras', 'Bandar Tun Razak'
  ];

  final List<String> _accomTypes = [
    'Hotel/Motel/Rest House',
    'Residence of Friends/Relatives',
    'Others'
  ];

  // 2. Employment Info
  final _compNameCtrl = TextEditingController();
  final _compAddrCtrl = TextEditingController();
  final _compPhoneCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _yearsEmpCtrl = TextEditingController();
  final _monthlyIncCtrl = TextEditingController();
  final _annualIncCtrl = TextEditingController();

  // 3. Financial Info
  final _bankNameCtrl = TextEditingController();
  final _accBalCtrl = TextEditingController();
  final _mthlyExpCtrl = TextEditingController();

  // 4. Travel Info
  final _purposeCtrl = TextEditingController();
  final _arrDateCtrl = TextEditingController();
  final _depDateCtrl = TextEditingController();
  final _visaExpCtrl = TextEditingController();
  final _hotelNameCtrl = TextEditingController();
  final _hotelAddrCtrl = TextEditingController();
  final _airlineCtrl = TextEditingController();
  final _flightNoCtrl = TextEditingController();

  // 5. Payment
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

  /// Automatically fetches previously saved local drafts, then overrides identity details with database values.
  Future<void> _loadPreFilledData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }

      // --- 1. LOAD LOCAL CACHE DRAFTS FIRST ---
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'visa_draft_${user.id}';

      _dobCtrl.text = prefs.getString('${cacheKey}_dob') ?? '';
      _occupCtrl.text = prefs.getString('${cacheKey}_occup') ?? '';
      _emergNameCtrl.text = prefs.getString('${cacheKey}_emergName') ?? '';
      _emergPhoneCtrl.text = prefs.getString('${cacheKey}_emergPhone') ?? '';
      _emergRelCtrl.text = prefs.getString('${cacheKey}_emergRel') ?? '';
      _compNameCtrl.text = prefs.getString('${cacheKey}_compName') ?? '';
      _compAddrCtrl.text = prefs.getString('${cacheKey}_compAddr') ?? '';
      _compPhoneCtrl.text = prefs.getString('${cacheKey}_compPhone') ?? '';
      _jobTitleCtrl.text = prefs.getString('${cacheKey}_jobTitle') ?? '';
      _yearsEmpCtrl.text = prefs.getString('${cacheKey}_yearsEmp') ?? '';
      _monthlyIncCtrl.text = prefs.getString('${cacheKey}_monthlyInc') ?? '';
      _annualIncCtrl.text = prefs.getString('${cacheKey}_annualInc') ?? '';
      _bankNameCtrl.text = prefs.getString('${cacheKey}_bankName') ?? '';
      _accBalCtrl.text = prefs.getString('${cacheKey}_accBal') ?? '';
      _mthlyExpCtrl.text = prefs.getString('${cacheKey}_mthlyExp') ?? '';
      _purposeCtrl.text = prefs.getString('${cacheKey}_purpose') ?? '';
      _arrDateCtrl.text = prefs.getString('${cacheKey}_arrDate') ?? '';
      _depDateCtrl.text = prefs.getString('${cacheKey}_depDate') ?? '';
      _visaExpCtrl.text = prefs.getString('${cacheKey}_visaExp') ?? '';
      _hotelNameCtrl.text = prefs.getString('${cacheKey}_hotelName') ?? '';
      _hotelAddrCtrl.text = prefs.getString('${cacheKey}_hotelAddr') ?? '';
      _airlineCtrl.text = prefs.getString('${cacheKey}_airline') ?? '';
      _flightNoCtrl.text = prefs.getString('${cacheKey}_flightNo') ?? '';

      final cachedGender = prefs.getString('${cacheKey}_gender');
      if (cachedGender != null && ['Male', 'Female', 'Other'].contains(cachedGender)) _selectedGender = cachedGender;

      final cachedMarital = prefs.getString('${cacheKey}_marital');
      if (cachedMarital != null && ['Single', 'Couple', 'Married'].contains(cachedMarital)) _selectedMaritalStatus = cachedMarital;

      final cachedEdu = prefs.getString('${cacheKey}_edu');
      if (cachedEdu != null && _educationLevels.contains(cachedEdu)) _selectedEduLevel = cachedEdu;

      final cachedEmpStat = prefs.getString('${cacheKey}_empStatus');
      if (cachedEmpStat != null && _employmentStatuses.contains(cachedEmpStat)) _selectedEmpStatus = cachedEmpStat;

      final cachedState = prefs.getString('${cacheKey}_state');
      if (cachedState != null && _malaysiaStates.contains(cachedState)) _selectedState = cachedState;

      final cachedKlZone = prefs.getString('${cacheKey}_klZone');
      if (cachedKlZone != null && _klZones.contains(cachedKlZone)) _selectedKlZone = cachedKlZone;

      final cachedAccom = prefs.getString('${cacheKey}_accomType');
      if (cachedAccom != null && _accomTypes.contains(cachedAccom)) _selectedAccomType = cachedAccom;
      // -----------------------------------------


      // --- 2. FETCH AND OVERWRITE IDENTITY DATA FROM DB ---
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

  /// Saves the current text field and dropdown states directly to device cache
  Future<void> _saveDraftDataToCache() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'visa_draft_${user.id}';

      await prefs.setString('${cacheKey}_dob', _dobCtrl.text);
      await prefs.setString('${cacheKey}_occup', _occupCtrl.text);
      await prefs.setString('${cacheKey}_emergName', _emergNameCtrl.text);
      await prefs.setString('${cacheKey}_emergPhone', _emergPhoneCtrl.text);
      await prefs.setString('${cacheKey}_emergRel', _emergRelCtrl.text);
      await prefs.setString('${cacheKey}_compName', _compNameCtrl.text);
      await prefs.setString('${cacheKey}_compAddr', _compAddrCtrl.text);
      await prefs.setString('${cacheKey}_compPhone', _compPhoneCtrl.text);
      await prefs.setString('${cacheKey}_jobTitle', _jobTitleCtrl.text);
      await prefs.setString('${cacheKey}_yearsEmp', _yearsEmpCtrl.text);
      await prefs.setString('${cacheKey}_monthlyInc', _monthlyIncCtrl.text);
      await prefs.setString('${cacheKey}_annualInc', _annualIncCtrl.text);
      await prefs.setString('${cacheKey}_bankName', _bankNameCtrl.text);
      await prefs.setString('${cacheKey}_accBal', _accBalCtrl.text);
      await prefs.setString('${cacheKey}_mthlyExp', _mthlyExpCtrl.text);
      await prefs.setString('${cacheKey}_purpose', _purposeCtrl.text);
      await prefs.setString('${cacheKey}_arrDate', _arrDateCtrl.text);
      await prefs.setString('${cacheKey}_depDate', _depDateCtrl.text);
      await prefs.setString('${cacheKey}_visaExp', _visaExpCtrl.text);
      await prefs.setString('${cacheKey}_hotelName', _hotelNameCtrl.text);
      await prefs.setString('${cacheKey}_hotelAddr', _hotelAddrCtrl.text);
      await prefs.setString('${cacheKey}_airline', _airlineCtrl.text);
      await prefs.setString('${cacheKey}_flightNo', _flightNoCtrl.text);

      await prefs.setString('${cacheKey}_gender', _selectedGender ?? '');
      await prefs.setString('${cacheKey}_marital', _selectedMaritalStatus ?? '');
      await prefs.setString('${cacheKey}_edu', _selectedEduLevel ?? '');
      await prefs.setString('${cacheKey}_empStatus', _selectedEmpStatus ?? '');
      await prefs.setString('${cacheKey}_state', _selectedState ?? '');
      await prefs.setString('${cacheKey}_klZone', _selectedKlZone ?? '');
      await prefs.setString('${cacheKey}_accomType', _selectedAccomType ?? '');
    } catch (e) {
      debugPrint("Failed saving cache: $e");
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _passportCtrl.dispose(); _passIssueCtrl.dispose(); _passExpiryCtrl.dispose();
    _passCountryCtrl.dispose(); _nationalityCtrl.dispose(); _residenceCtrl.dispose();
    _dobCtrl.dispose(); _occupCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _emergNameCtrl.dispose(); _emergPhoneCtrl.dispose(); _emergRelCtrl.dispose();
    _compNameCtrl.dispose(); _compAddrCtrl.dispose(); _compPhoneCtrl.dispose();
    _jobTitleCtrl.dispose(); _yearsEmpCtrl.dispose(); _monthlyIncCtrl.dispose(); _annualIncCtrl.dispose();
    _bankNameCtrl.dispose(); _accBalCtrl.dispose(); _mthlyExpCtrl.dispose();
    _purposeCtrl.dispose(); _arrDateCtrl.dispose(); _depDateCtrl.dispose(); _visaExpCtrl.dispose();
    _hotelNameCtrl.dispose(); _hotelAddrCtrl.dispose();
    _airlineCtrl.dispose(); _flightNoCtrl.dispose();
    _cardNumberCtrl.dispose(); _cardExpiryCtrl.dispose(); _cardCvcCtrl.dispose();
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

  Widget _buildDropdownField(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
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
            decoration: InputDecoration(labelText: label, prefixText: 'MYR '),
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

    return true;
  }

  List<String> _getMissingMandatoryFields() {
    List<String> missing = [];
    if (_nameCtrl.text.trim().isEmpty) missing.add("Full Name (Step 1)");
    if (_passportCtrl.text.trim().isEmpty) missing.add("Passport Number (Step 1)");
    if (_nationalityCtrl.text.trim().isEmpty) missing.add("Nationality (Step 1)");
    if (_selectedEmpStatus == null) missing.add("Employment Status (Step 2)");
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

    // Save final inputs to cache right before submission
    _saveDraftDataToCache();

    setState(() => _processState = AppProcessState.stripeProcessing);
    await Future.delayed(const Duration(seconds: 2));

    final String txnId = "txn_${DateTime.now().millisecondsSinceEpoch}";

    setState(() => _processState = AppProcessState.stripeSuccess);
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() => _processState = AppProcessState.aiProcessing);

    try {
      final String intendedDestination = _selectedState == 'Kuala Lumpur' && _selectedKlZone != null
          ? 'Kuala Lumpur - $_selectedKlZone'
          : _selectedState ?? '';

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
          "education_level": _selectedEduLevel ?? '',
          "occupation": _occupCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
          "emergency_contact_name": _emergNameCtrl.text.trim(),
          "emergency_contact_phone": _emergPhoneCtrl.text.trim(),
          "emergency_relationship": _emergRelCtrl.text.trim(),
        },
        "employment_information": {
          "employment_status": _selectedEmpStatus ?? '',
          "company_name": _compNameCtrl.text.trim(),
          "company_address": _compAddrCtrl.text.trim(),
          "company_phone": _compPhoneCtrl.text.trim(),
          "job_title": _jobTitleCtrl.text.trim(),
          "years_employed": _yearsEmpCtrl.text.trim(),
          "monthly_income_myr": _monthlyIncCtrl.text.trim(),
          "annual_income_myr": _annualIncCtrl.text.trim(),
        },
        "financial_information": {
          "bank_name": _bankNameCtrl.text.trim(),
          "account_balance_myr": _accBalCtrl.text.trim(),
          "monthly_expenses_myr": _mthlyExpCtrl.text.trim(),
        },
        "travel_logistics": {
          "purpose_of_visit": _purposeCtrl.text.trim(),
          "arrival_date": _arrDateCtrl.text.trim(),
          "departure_date": _depDateCtrl.text.trim(),
          "visa_expiry_date": _visaExpCtrl.text.trim(),
          "intended_destination": intendedDestination,
          "hotel_name": _hotelNameCtrl.text.trim(),
          "hotel_address": _hotelAddrCtrl.text.trim(),
          "accommodation_type": _selectedAccomType ?? '',
          "airline": _airlineCtrl.text.trim(),
          "flight_number": _flightNoCtrl.text.trim(),
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
        maritalStatus: _selectedMaritalStatus ?? '', educationLevel: _selectedEduLevel ?? '', occupation: _occupCtrl.text,
        email: _emailCtrl.text, phone: _phoneCtrl.text, emergencyName: _emergNameCtrl.text,
        emergencyPhone: _emergPhoneCtrl.text, emergencyRel: _emergRelCtrl.text,

        employmentStatus: _selectedEmpStatus ?? '', companyName: _compNameCtrl.text, companyAddress: _compAddrCtrl.text,
        companyPhone: _compPhoneCtrl.text, jobTitle: _jobTitleCtrl.text, yearsEmployed: _yearsEmpCtrl.text,
        monthlyIncome: _monthlyIncCtrl.text, annualIncome: _annualIncCtrl.text,


        bankName: _bankNameCtrl.text, accountBalance: _accBalCtrl.text, monthlyExpense: _mthlyExpCtrl.text,


        purpose: _purposeCtrl.text, arrivalDate: _arrDateCtrl.text, departureDate: _depDateCtrl.text,
        visaExpiryDate: _visaExpCtrl.text, destination: intendedDestination, hotelName: _hotelNameCtrl.text,
        hotelAddress: _hotelAddrCtrl.text, accomType: _selectedAccomType ?? '', airline: _airlineCtrl.text,
        flightNo: _flightNoCtrl.text,

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
        title: const Text('Visa Application Form', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            _saveDraftDataToCache(); // Cache inputs upon leaving
            Navigator.of(context).pop(false);
          },
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
    if (_processState == AppProcessState.stripeProcessing) return _buildStatusView("Payment Processing", Icons.lock_outline, isSpinner: true);
    if (_processState == AppProcessState.stripeSuccess) return _buildStatusView("Payment Successful (MYR 150.00)", Icons.check_circle_rounded, isSuccess: true);
    if (_processState == AppProcessState.aiProcessing) return const _AiProgressView();
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
              const Text("VISA APPLICATION SUCCESSFUL RATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
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
          child: const Text("Return to Applications History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
        _saveDraftDataToCache(); // Cache inputs upon step progression
        if (_currentStep < 5) {
          setState(() => _currentStep += 1);
        }
      },
      onStepCancel: () {
        _saveDraftDataToCache(); // Cache inputs upon step regression
        if (_currentStep > 0) {
          setState(() => _currentStep -= 1);
        }
      },
      controlsBuilder: (context, details) {
        if (_currentStep == 5) return const SizedBox.shrink();
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
          title: const Text('Tourist Details'),
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
            _buildDropdownField('Education Level', _educationLevels, _selectedEduLevel, (val) => setState(() => _selectedEduLevel = val)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _occupCtrl, decoration: const InputDecoration(labelText: 'Occupation'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Phone'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _emergRelCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Relationship'))),
          ]),
        ),
        Step(
          title: const Text('Employment Information'),
          isActive: _currentStep >= 1,
          content: Column(children: [
            _buildDropdownField('Employment Status*', _employmentStatuses, _selectedEmpStatus, (val) => setState(() => _selectedEmpStatus = val)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compNameCtrl, decoration: const InputDecoration(labelText: 'Company Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compAddrCtrl, decoration: const InputDecoration(labelText: 'Company Address'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _compPhoneCtrl, decoration: const InputDecoration(labelText: 'Company Phone'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _jobTitleCtrl, decoration: const InputDecoration(labelText: 'Job Title'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _yearsEmpCtrl, decoration: const InputDecoration(labelText: 'Years Employed'), keyboardType: TextInputType.number)),
            _buildMoneyInputWithSlider('Monthly Income', _monthlyIncCtrl, 10000000.0),
            _buildMoneyInputWithSlider('Annual Income', _annualIncCtrl, 100000000.0),
          ]),
        ),
        Step(
          title: const Text('Financial Information'),
          isActive: _currentStep >= 2,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Primary Bank Name'))),
            _buildMoneyInputWithSlider('Account Balance', _accBalCtrl, 100000000.0),
            _buildMoneyInputWithSlider('Monthly Expenses', _mthlyExpCtrl, 10000000.0),
          ]),
        ),
        Step(
          title: const Text('Travel Information'),
          isActive: _currentStep >= 3,
          content: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _purposeCtrl, decoration: const InputDecoration(labelText: 'Purpose of Visit'))),
            _buildDateField('Arrival Date', _arrDateCtrl),
            _buildDateField('Departure Date', _depDateCtrl),
            _buildDateField('Visa Expiry Date', _visaExpCtrl),

            _buildDropdownField('Intended Destination (States)', _malaysiaStates, _selectedState, (val) {
              setState(() {
                _selectedState = val;
                _selectedKlZone = null;
              });
            }),

            if (_selectedState == 'Kuala Lumpur')
              _buildDropdownField('Kuala Lumpur Zone', _klZones, _selectedKlZone, (val) => setState(() => _selectedKlZone = val)),

            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _hotelNameCtrl, decoration: const InputDecoration(labelText: 'Hotel Name'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _hotelAddrCtrl, decoration: const InputDecoration(labelText: 'Hotel Address'))),
            _buildDropdownField('Accommodation Type', _accomTypes, _selectedAccomType, (val) => setState(() => _selectedAccomType = val)),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _airlineCtrl, decoration: const InputDecoration(labelText: 'Airline'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: _flightNoCtrl, decoration: const InputDecoration(labelText: 'Flight Number'))),
          ]),
        ),
        Step(
          title: const Text('Supporting Documents'),
          isActive: _currentStep >= 4,
          content: Column(children: [
            OutlinedButton.icon(
              onPressed: _handleDocumentUpload,
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedFileName ?? 'Attach Optional Document (PNG/PDF)'),
            ),
          ]),
        ),
        Step(
          title: const Text('Proceed For Payment'),
          isActive: _currentStep >= 5,
          content: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Text("AI Calculation Fee: MYR 150.00", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
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
                child: const Text('Submit Visa Form to AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _AiProgressView extends StatefulWidget {
  const _AiProgressView({Key? key}) : super(key: key);

  @override
  State<_AiProgressView> createState() => _AiProgressViewState();
}

class _AiProgressViewState extends State<_AiProgressView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors: [
                Colors.red.withOpacity(0.1),
                Colors.orange.withOpacity(0.1),
                Colors.yellow.withOpacity(0.1),
                Colors.green.withOpacity(0.1),
                Colors.blue.withOpacity(0.1),
                Colors.purple.withOpacity(0.1),
                Colors.red.withOpacity(0.1),
              ],
              transform: GradientRotation(_controller.value * 2 * 3.1415926535),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => SweepGradient(
                    colors: const [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                    transform: GradientRotation(_controller.value * 2 * 3.1415926535),
                  ).createShader(bounds),
                  child: const Icon(Icons.memory_rounded, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('AI Calculating Risk Probability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 0.98),
                    duration: const Duration(seconds: 8),
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('${(value * 100).toInt()}% Completed', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}