import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/database_service.dart';

enum AppProcessState { fillingForm, stripeProcessing, stripeSuccess, aiProcessing, completed }

class VisaApplicationScreen extends StatefulWidget {
  const VisaApplicationScreen({Key? key}) : super(key: key);

  @override
  State<VisaApplicationScreen> createState() => _VisaApplicationScreenState();
}

class _VisaApplicationScreenState extends State<VisaApplicationScreen> with WidgetsBindingObserver {
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

  // Payment Selection Variable
  String? _selectedCardType;

  // Dropdown Data Lists
  final List<String> _educationLevels = [
    'Primary School',
    'Secondary School',
    'Higher Education',
    'Others'
  ];

  final List<String> _employmentStatuses = [
    'Full-Time Employee',
    'Part-Time Employee',
    'Contract Employee',
    'Self-Employed',
    'Others'
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
    WidgetsBinding.instance.addObserver(this);
    _loadPreFilledData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _saveDraftDataToCache();
    }
  }

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

  Map<String, dynamic>? _extractMap(dynamic source) {
    if (source is List && source.isNotEmpty) {
      return Map<String, dynamic>.from(source.first as Map);
    } else if (source is Map) {
      return Map<String, dynamic>.from(source);
    }
    return null;
  }

  Future<void> _loadPreFilledData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'visa_draft_${user.id}';
      final draftString = prefs.getString(cacheKey);

      if (draftString != null) {
        try {
          final Map<String, dynamic> draftData = jsonDecode(draftString);
          _dobCtrl.text = draftData['dob'] ?? '';
          _occupCtrl.text = draftData['occup'] ?? '';
          _emergNameCtrl.text = draftData['emergName'] ?? '';
          _emergPhoneCtrl.text = draftData['emergPhone'] ?? '';
          _emergRelCtrl.text = draftData['emergRel'] ?? '';
          _compNameCtrl.text = draftData['compName'] ?? '';
          _compAddrCtrl.text = draftData['compAddr'] ?? '';
          _compPhoneCtrl.text = draftData['compPhone'] ?? '';
          _jobTitleCtrl.text = draftData['jobTitle'] ?? '';
          _yearsEmpCtrl.text = draftData['yearsEmp'] ?? '';
          _monthlyIncCtrl.text = draftData['monthlyInc'] ?? '';
          _annualIncCtrl.text = draftData['annualInc'] ?? '';
          _bankNameCtrl.text = draftData['bankName'] ?? '';
          _accBalCtrl.text = draftData['accBal'] ?? '';
          _mthlyExpCtrl.text = draftData['mthlyExp'] ?? '';
          _purposeCtrl.text = draftData['purpose'] ?? '';
          _arrDateCtrl.text = draftData['arrDate'] ?? '';
          _depDateCtrl.text = draftData['depDate'] ?? '';
          _visaExpCtrl.text = draftData['visaExp'] ?? '';
          _hotelNameCtrl.text = draftData['hotelName'] ?? '';
          _hotelAddrCtrl.text = draftData['hotelAddr'] ?? '';
          _airlineCtrl.text = draftData['airline'] ?? '';
          _flightNoCtrl.text = draftData['flightNo'] ?? '';

          final cachedGender = draftData['gender'];
          if (cachedGender != null && ['Male', 'Female'].contains(cachedGender)) _selectedGender = cachedGender;

          final cachedMarital = draftData['marital'];
          if (cachedMarital != null && ['Single', 'Couple', 'Married'].contains(cachedMarital)) _selectedMaritalStatus = cachedMarital;

          final cachedEdu = draftData['edu'];
          if (cachedEdu != null && _educationLevels.contains(cachedEdu)) _selectedEduLevel = cachedEdu;

          final cachedEmpStat = draftData['empStatus'];
          if (cachedEmpStat != null && _employmentStatuses.contains(cachedEmpStat)) _selectedEmpStatus = cachedEmpStat;

          final cachedState = draftData['state'];
          if (cachedState != null && _malaysiaStates.contains(cachedState)) _selectedState = cachedState;

          final cachedKlZone = draftData['klZone'];
          if (cachedKlZone != null && _klZones.contains(cachedKlZone)) _selectedKlZone = cachedKlZone;

          final cachedAccom = draftData['accomType'];
          if (cachedAccom != null && _accomTypes.contains(cachedAccom)) _selectedAccomType = cachedAccom;
        } catch (e) {
          debugPrint("Failed to parse cache: $e");
        }
      }

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (profileData != null) {
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = profileData['full_name'] ?? '';
        if (_emailCtrl.text.isEmpty) _emailCtrl.text = profileData['email'] ?? '';
        if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = profileData['phone_number'] ?? '';
        if (_nationalityCtrl.text.isEmpty) _nationalityCtrl.text = profileData['nationality'] ?? '';

        final touristData = await _supabase
            .from('tourists')
            .select()
            .eq('profile_id', profileData['id'])
            .maybeSingle();

        if (touristData != null) {
          if (_passportCtrl.text.isEmpty) _passportCtrl.text = touristData['passport_number'] ?? '';
          if (_passCountryCtrl.text.isEmpty) _passCountryCtrl.text = touristData['passport_issuing_country'] ?? '';
          if (_residenceCtrl.text.isEmpty) _residenceCtrl.text = touristData['country_of_residence'] ?? '';

          if (_passIssueCtrl.text.isEmpty && touristData['passport_issue_date'] != null) {
            _passIssueCtrl.text = touristData['passport_issue_date'].toString();
          }
          if (_passExpiryCtrl.text.isEmpty && touristData['passport_expiry_date'] != null) {
            _passExpiryCtrl.text = touristData['passport_expiry_date'].toString();
          }
        }

        final lastApp = await _supabase
            .from('visa_applications')
            .select('''
              id,
              applicant_information(*),
              employment_information(*),
              financial_information(*),
              travel_information(*)
            ''')
            .eq('user_id', profileData['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastApp != null) {
          final applicant = _extractMap(lastApp['applicant_information']);
          final employment = _extractMap(lastApp['employment_information']);
          final financial = _extractMap(lastApp['financial_information']);
          final travel = _extractMap(lastApp['travel_information']);

          if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = applicant?['phone'] ?? '';
          if (_emailCtrl.text.isEmpty) _emailCtrl.text = applicant?['email'] ?? '';
          if (_nameCtrl.text.isEmpty) _nameCtrl.text = applicant?['full_name'] ?? '';
          if (_passportCtrl.text.isEmpty) _passportCtrl.text = applicant?['passport_number'] ?? '';
          if (_passIssueCtrl.text.isEmpty) _passIssueCtrl.text = applicant?['passport_issue_date']?.toString() ?? '';
          if (_passExpiryCtrl.text.isEmpty) _passExpiryCtrl.text = applicant?['passport_expiry_date']?.toString() ?? '';
          if (_passCountryCtrl.text.isEmpty) _passCountryCtrl.text = applicant?['passport_country'] ?? '';
          if (_nationalityCtrl.text.isEmpty) _nationalityCtrl.text = applicant?['nationality'] ?? '';
          if (_residenceCtrl.text.isEmpty) _residenceCtrl.text = applicant?['country_of_residence'] ?? '';

          if (_dobCtrl.text.isEmpty) _dobCtrl.text = applicant?['date_of_birth'] ?? '';
          if (_occupCtrl.text.isEmpty) _occupCtrl.text = applicant?['occupation'] ?? '';
          if (_emergNameCtrl.text.isEmpty) _emergNameCtrl.text = applicant?['emergency_contact_name'] ?? '';
          if (_emergPhoneCtrl.text.isEmpty) _emergPhoneCtrl.text = applicant?['emergency_contact_phone'] ?? '';
          if (_emergRelCtrl.text.isEmpty) _emergRelCtrl.text = applicant?['emergency_relationship'] ?? '';

          final fetchedGender = applicant?['gender'];
          if (_selectedGender == null && fetchedGender != null && ['Male', 'Female'].contains(fetchedGender)) _selectedGender = fetchedGender;

          final fetchedMarital = applicant?['marital_status'];
          if (_selectedMaritalStatus == null && fetchedMarital != null && ['Single', 'Couple', 'Married'].contains(fetchedMarital)) _selectedMaritalStatus = fetchedMarital;

          final fetchedEdu = applicant?['education_level'];
          if (_selectedEduLevel == null && fetchedEdu != null && _educationLevels.contains(fetchedEdu)) _selectedEduLevel = fetchedEdu;

          if (_compNameCtrl.text.isEmpty) _compNameCtrl.text = employment?['company_name'] ?? '';
          if (_compAddrCtrl.text.isEmpty) _compAddrCtrl.text = employment?['company_address'] ?? '';
          if (_compPhoneCtrl.text.isEmpty) _compPhoneCtrl.text = employment?['company_phone'] ?? '';
          if (_jobTitleCtrl.text.isEmpty) _jobTitleCtrl.text = employment?['job_title'] ?? '';
          if (_yearsEmpCtrl.text.isEmpty) _yearsEmpCtrl.text = employment?['years_employed']?.toString() ?? '';
          if (_monthlyIncCtrl.text.isEmpty) _monthlyIncCtrl.text = employment?['monthly_income']?.toString() ?? '';
          if (_annualIncCtrl.text.isEmpty) _annualIncCtrl.text = employment?['annual_income']?.toString() ?? '';

          final fetchedEmpStat = employment?['employment_status'];
          if (_selectedEmpStatus == null && fetchedEmpStat != null && _employmentStatuses.contains(fetchedEmpStat)) _selectedEmpStatus = fetchedEmpStat;

          if (_bankNameCtrl.text.isEmpty) _bankNameCtrl.text = financial?['bank_name'] ?? '';
          if (_accBalCtrl.text.isEmpty) _accBalCtrl.text = financial?['account_balance']?.toString() ?? '';
          if (_mthlyExpCtrl.text.isEmpty) _mthlyExpCtrl.text = financial?['monthly_expense']?.toString() ?? '';

          if (_purposeCtrl.text.isEmpty) _purposeCtrl.text = travel?['purpose_of_visit'] ?? '';
          if (_hotelNameCtrl.text.isEmpty) _hotelNameCtrl.text = travel?['hotel_name'] ?? '';
          if (_hotelAddrCtrl.text.isEmpty) _hotelAddrCtrl.text = travel?['hotel_address'] ?? '';
          if (_airlineCtrl.text.isEmpty) _airlineCtrl.text = travel?['airline'] ?? '';
          if (_flightNoCtrl.text.isEmpty) _flightNoCtrl.text = travel?['flight_number'] ?? '';

          final fetchedAccom = travel?['accommodation_type'];
          if (_selectedAccomType == null && fetchedAccom != null && _accomTypes.contains(fetchedAccom)) _selectedAccomType = fetchedAccom;

          if (_selectedState == null && travel?['intended_destination'] != null) {
            String dest = travel!['intended_destination'];
            if (dest.startsWith('Kuala Lumpur - ')) {
              _selectedState = 'Kuala Lumpur';
              String zone = dest.replaceAll('Kuala Lumpur - ', '');
              if (_klZones.contains(zone)) _selectedKlZone = zone;
            } else if (_malaysiaStates.contains(dest)) {
              _selectedState = dest;
            }
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

  Future<void> _saveDraftDataToCache() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'visa_draft_${user.id}';

      final Map<String, dynamic> draftData = {
        'dob': _dobCtrl.text,
        'occup': _occupCtrl.text,
        'emergName': _emergNameCtrl.text,
        'emergPhone': _emergPhoneCtrl.text,
        'emergRel': _emergRelCtrl.text,
        'compName': _compNameCtrl.text,
        'compAddr': _compAddrCtrl.text,
        'compPhone': _compPhoneCtrl.text,
        'jobTitle': _jobTitleCtrl.text,
        'yearsEmp': _yearsEmpCtrl.text,
        'monthlyInc': _monthlyIncCtrl.text,
        'annualInc': _annualIncCtrl.text,
        'bankName': _bankNameCtrl.text,
        'accBal': _accBalCtrl.text,
        'mthlyExp': _mthlyExpCtrl.text,
        'purpose': _purposeCtrl.text,
        'arrDate': _arrDateCtrl.text,
        'depDate': _depDateCtrl.text,
        'visaExp': _visaExpCtrl.text,
        'hotelName': _hotelNameCtrl.text,
        'hotelAddr': _hotelAddrCtrl.text,
        'airline': _airlineCtrl.text,
        'flightNo': _flightNoCtrl.text,
        'gender': _selectedGender ?? '',
        'marital': _selectedMaritalStatus ?? '',
        'edu': _selectedEduLevel ?? '',
        'empStatus': _selectedEmpStatus ?? '',
        'state': _selectedState ?? '',
        'klZone': _selectedKlZone ?? '',
        'accomType': _selectedAccomType ?? '',
      };

      await prefs.setString(cacheKey, jsonEncode(draftData));
    } catch (e) {
      debugPrint("Failed saving cache: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Widget _buildLockedField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () {
          _showStatusDialog(
            title: "Information Locked",
            message: "This mandatory field is securely linked to your registered profile and cannot be manually altered.",
            isInfo: true,
          );
        },
        style: const TextStyle(color: Color(0xFF64748B)),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          suffixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
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

  Widget _buildCardTypeSelector(String title, Color brandColor) {
    final isSelected = _selectedCardType == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCardType = title;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.08) : const Color(0xFFF8FAFC),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_rounded,
              color: isSelected ? brandColor : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? brandColor : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateLogicalDates() {
    DateTime? passIssue = DateTime.tryParse(_passIssueCtrl.text);
    DateTime? passExpiry = DateTime.tryParse(_passExpiryCtrl.text);
    if (passIssue != null && passExpiry != null && !passExpiry.isAfter(passIssue)) {
      _showStatusDialog(
        title: "Invalid Passport Dates",
        message: "Passport Expiry Date must be strictly after the Passport Issue Date.",
        isError: true,
      );
      return false;
    }

    DateTime? arr = DateTime.tryParse(_arrDateCtrl.text);
    DateTime? dep = DateTime.tryParse(_depDateCtrl.text);
    if (arr != null && dep != null && !dep.isAfter(arr)) {
      _showStatusDialog(
        title: "Invalid Travel Dates",
        message: "Departure Date must be strictly after the Arrival Date.",
        isError: true,
      );
      return false;
    }

    DateTime? visaExp = DateTime.tryParse(_visaExpCtrl.text);
    if (dep != null && visaExp != null && !visaExp.isAfter(dep)) {
      _showStatusDialog(
        title: "Invalid Visa Dates",
        message: "Visa Expiry Date must be strictly after the Departure Date.",
        isError: true,
      );
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
      _showStatusDialog(
        title: "Upload Failed",
        message: "An error occurred while opening the file picker: $e",
        isError: true,
      );
    } finally {
      setState(() => _isUploadingDoc = false);
    }
  }

  bool _validatePaymentInputs() {
    final missingFormFields = _getMissingMandatoryFields();
    if (missingFormFields.isNotEmpty) {
      _showStatusDialog(
        title: "Missing Information",
        message: "Please fill in the following required fields:\n${missingFormFields.join(', ')}",
        isError: true,
      );
      return false;
    }

    if (!_validateLogicalDates()) return false;

    if (_selectedCardType == null) {
      _showStatusDialog(
        title: "Payment Error",
        message: "Please select Visa or Mastercard, or enter a valid card number starting with 4, 5, or 2.",
        isError: true,
      );
      return false;
    }

    final cleanedCardNumber = _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), '');

    if (cleanedCardNumber.isNotEmpty) {
      if (_selectedCardType == 'Visa' && !cleanedCardNumber.startsWith('4')) {
        _showStatusDialog(
          title: "Card Type Mismatch",
          message: "You selected Visa, but your card number does not start with 4. Please correct your card type or number.",
          isError: true,
        );
        return false;
      }
      if (_selectedCardType == 'Mastercard' && !(cleanedCardNumber.startsWith('5') || cleanedCardNumber.startsWith('2'))) {
        _showStatusDialog(
          title: "Card Type Mismatch",
          message: "You selected Mastercard, but your card number does not start with 5 or 2. Please correct your card type or number.",
          isError: true,
        );
        return false;
      }
    }

    if (!RegExp(r'^\d{16}$').hasMatch(cleanedCardNumber)) {
      _showStatusDialog(
        title: "Payment Error",
        message: "Card Number must be exactly 16 digits.",
        isError: true,
      );
      return false;
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim())) {
      _showStatusDialog(
        title: "Payment Error",
        message: "Invalid Expiry Date format. Please use MM/YY (e.g., 12/28).",
        isError: true,
      );
      return false;
    }
    if (!RegExp(r'^\d{3}$').hasMatch(_cardCvcCtrl.text.trim())) {
      _showStatusDialog(
        title: "Payment Error",
        message: "CVC must be exactly 3 digits.",
        isError: true,
      );
      return false;
    }
    return true;
  }

  Future<void> _processPaymentAndSubmit() async {
    if (!_validatePaymentInputs()) return;

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('visa_draft_${_supabase.auth.currentUser?.id}');

      setState(() {
        _successRate = (100.0 - riskScore).clamp(0.0, 100.0);
        _aiReasoning = aiResult['prediction_reason'] ?? "Assessment finalized successfully.";
        _processState = AppProcessState.completed;
      });
    } catch (e) {
      setState(() => _processState = AppProcessState.fillingForm);
      _showStatusDialog(
        title: "AI Calculation Error",
        message: "An error occurred during AI processing: $e",
        isError: true,
      );
    }
  }

  // FORMATTER: Scans for numbers ("1)", "1.") or Ordinals ("Firstly,") and injects clean double line breaks.
  Widget _buildReasoningBlocks(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    String formattedText = text.replaceAllMapped(
        RegExp(r'\s+(?=(?:\d+[\)\.])|(?:Firstly|Secondly|Thirdly|Fourthly|Finally|Furthermore|Moreover|In addition)[,:]?)', caseSensitive: false),
            (Match m) => '\n\n'
    );

    List<String> blocks = formattedText.split('\n\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            block,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
          ),
        );
      }).toList(),
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
            _saveDraftDataToCache();
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
    if (_processState == AppProcessState.stripeSuccess) return _buildStatusView("Payment Successful with MYR 150.00", Icons.check_circle_rounded, isSuccess: true);
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
              const SizedBox(height: 16),
              _buildReasoningBlocks(_aiReasoning),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Disclaimer: This AI calculation strictly predicts your visa successful rate. It does NOT mean that your visa is already approved by the government. Your application must still be reviewed by administrator.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                ),
              ),
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
        _saveDraftDataToCache();
        if (_currentStep < 5) {
          setState(() => _currentStep += 1);
        }
      },
      onStepCancel: () {
        _saveDraftDataToCache();
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
            _buildLockedField('Full Name*', _nameCtrl),
            _buildLockedField('Passport Number*', _passportCtrl),
            _buildLockedField('Passport Issue Date', _passIssueCtrl),
            _buildLockedField('Passport Expiry Date', _passExpiryCtrl),
            _buildLockedField('Passport Issuing Country', _passCountryCtrl),
            _buildLockedField('Nationality*', _nationalityCtrl),
            _buildLockedField('Country of Residence', _residenceCtrl),
            _buildSelectionBox('Gender', ['Male', 'Female'], _selectedGender, (val) => setState(() => _selectedGender = val)),
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
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Credit Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildCardTypeSelector('Visa', const Color(0xFF1A1F71))),
                const SizedBox(width: 12),
                Expanded(child: _buildCardTypeSelector('Mastercard', const Color(0xFFEB001B))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardNumberCtrl,
              decoration: InputDecoration(
                labelText: 'Card Number (16 Digits)',
                prefixIcon: Icon(
                  Icons.credit_card_rounded,
                  color: _selectedCardType == 'Visa' ? const Color(0xFF1A1F71) : (_selectedCardType == 'Mastercard' ? const Color(0xFFEB001B) : const Color(0xFF94A3B8)),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final clean = value.replaceAll(RegExp(r'\D'), '');
                if (clean.isNotEmpty) {
                  if (clean.startsWith('4')) {
                    if (_selectedCardType != 'Visa') setState(() => _selectedCardType = 'Visa');
                  } else if (clean.startsWith('5') || clean.startsWith('2')) {
                    if (_selectedCardType != 'Mastercard') setState(() => _selectedCardType = 'Mastercard');
                  } else {
                    if (_selectedCardType != null) setState(() => _selectedCardType = null);
                  }
                } else {
                  if (_selectedCardType != null) setState(() => _selectedCardType = null);
                }
              },
            ),
            const SizedBox(height: 12),
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
                const Text('AI Calculating Visa Successful Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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