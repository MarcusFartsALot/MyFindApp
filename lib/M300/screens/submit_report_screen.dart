import '../models/report_validation.dart';
import '../models/report_submission_failure.dart';
import '../widgets/evidence_tile.dart';
import '../services/incident_location_access.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../M400/models/profile_model.dart';
import '../services/community_report_service.dart';
import '../models/incident_address.dart';
import '../widgets/local_evidence_preview.dart';
import '../widgets/report_success_dialog.dart';
import '../widgets/edge_swipe_back.dart';
import '../widgets/incident_location_picker.dart';

class SubmitReportScreen extends StatefulWidget {
  final ProfileModel profile;
  final CommunityReportService service;
  final VoidCallback? onLogout;

  const SubmitReportScreen({
    super.key,
    required this.profile,
    required this.service,
    this.onLogout,
  });

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _location = TextEditingController();
  final _address = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _postcode = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();

  String get _formattedAddress => IncidentAddress(
    line1: _address.text,
    line2: _address2.text,
    city: _city.text,
    postcode: _postcode.text,
    state: _state.text,
    country: _country.text,
  ).formatted;
  final _description = TextEditingController();
  final _otherCategory = TextEditingController();

  final _categories = const [
    'Unauthorized employment',
    'Visa violation',
    'Other',
  ];
  String _category = 'Unauthorized employment';

  // Urgency Level selection options
  final _urgencyLevels = const ['Low', 'Normal', 'High', 'Emergency'];
  String _urgencyLevel = 'Normal';

  DateTime _incidentDate = DateTime.now();
  TimeOfDay _incidentTime = TimeOfDay.now();
  List<PlatformFile> _files = [];

  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _resolvingAddress = false;
  int _locationRevision = 0;
  String? _locationMessage;
  bool _hasLocationPin = false;
  bool _locationFromDevice = false;
  bool _locationPermissionGranted = false;
  bool _submitting = false;

  GoogleMapController? _mapController;

  // Default fallback map position (Kuala Lumpur)
  LatLng _selectedLatLng = const LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phoneNumber ?? '');
    _email = TextEditingController(text: widget.profile.email);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detectLocation();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    for (final controller in [
      _name,
      _phone,
      _email,
      _location,
      _address,
      _address2,
      _city,
      _postcode,
      _state,
      _country,
      _description,
      _otherCategory,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Location Detection with Device Settings Prompt
  Future<void> _detectLocation() async {
    if (mounted) setState(() => _locating = true);
    try {
      final allowed = await IncidentLocationAccess.request(context);
      if (!mounted) return;
      if (!allowed) {
        _enableManualLocation();
        return;
      }
      setState(() => _locationPermissionGranted = true);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      await _updatePinnedLocation(
        LatLng(position.latitude, position.longitude),
        fromDevice: true,
      );
    } catch (_) {
      _enableManualLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get a GPS position. Check device location or choose the incident pin manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _enableManualLocation() {
    if (!mounted) return;
    setState(() {
      _locationPermissionGranted = false;
      _locating = false;
    });
  }

  Future<void> _updatePinnedLocation(
    LatLng target, {
    bool fromDevice = false,
  }) async {
    final revision = ++_locationRevision;
    setState(() {
      _selectedLatLng = target;
      _lat = target.latitude;
      _lng = target.longitude;
      _hasLocationPin = true;
      _locationFromDevice = fromDevice;
      _resolvingAddress = true;
      _locationMessage = null;
      _address.clear();
      for (final field in [_address2, _city, _postcode, _state, _country]) {
        field.clear();
      }
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(target.latitude, target.longitude)
          .timeout(const Duration(seconds: 12));
      if (!mounted || revision != _locationRevision) return;
      if (places.isEmpty) throw StateError('No address found');
      final address = IncidentAddress.fromPlacemark(places.first);
      _address.text = address.line1;
      _address2.text = address.line2;
      _city.text = address.city;
      _postcode.text = address.postcode;
      _state.text = address.state;
      _country.text = address.country;
      _locationMessage =
          'Address suggested from your pin. Review it and correct it if needed.';
    } catch (_) {
      if (!mounted || revision != _locationRevision) return;
      _locationMessage =
          'Your pin is saved, but its address could not be found. Enter the place and address below.';
    } finally {
      if (mounted && revision == _locationRevision) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  Future<void> _openMapLocationPicker() async {
    if (_submitting || _locating) return;
    final pickedResult = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncidentLocationPickerPage(
          initialLocation: _selectedLatLng,
          hasInitialPin: _hasLocationPin,
          myLocationEnabled: _locationPermissionGranted,
        ),
      ),
    );

    if (mounted && pickedResult != null) {
      _updatePinnedLocation(pickedResult);
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
    if (value != null) setState(() => _incidentDate = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _incidentTime,
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
    if (value != null) setState(() => _incidentTime = value);
  }

  /// Pick Media Files with Duplicate Checking and 10MB Limit Enforcement
  Future<void> _pickMediaFiles({
    required FileType type,
    required List<String> extensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      allowedExtensions: extensions.isEmpty ? null : extensions,
      withData: kIsWeb,
    );

    if (result == null || !mounted) return;

    final List<PlatformFile> validFiles = [];
    final List<String> duplicateFileNames = [];
    final List<String> invalidFiles = [];

    // Names of files already added to the form
    final existingNames = _files.map((f) => f.name.toLowerCase()).toSet();

    for (final file in result.files) {
      // 1. Check file size threshold (10MB)
      if (ReportValidation.evidence(file) != null) {
        invalidFiles.add('${file.name}: ${ReportValidation.evidence(file)}');
        continue;
      }

      final fileNameLower = file.name.toLowerCase();

      // 2. Prevent Duplicate Attachments in this Report
      if (existingNames.contains(fileNameLower)) {
        duplicateFileNames.add(file.name);
      } else {
        validFiles.add(file);
        existingNames.add(fileNameLower);
      }
    }

    // Show warning for oversized files
    if (invalidFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped invalid file(s): ${invalidFiles.join(", ")}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }

    // Show warning prompt for duplicate files
    if (duplicateFileNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Skipped duplicate file(s): ${duplicateFileNames.join(", ")}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (validFiles.isNotEmpty) {
      setState(() => _files = [..._files, ...validFiles]);
    }
  }

  /// Identifies if any previous step is missing mandatory fields
  int? _getInvalidStep() {
    // Step 0: Reporter Details
    if (_contactError() != null) return 0;

    // Step 1: Incident Details
    if (!_categories.contains(_category) ||
        !_urgencyLevels.contains(_urgencyLevel)) {
      return 1;
    }
    if (ReportValidation.text(_description.text, min: 10, max: 1000) != null ||
        _dateError() != null) {
      return 1;
    }
    if (_category == 'Other' &&
        (_otherCategory.text.trim().length < 2 ||
            _otherCategory.text.characters.length > 100)) {
      return 1;
    }

    // Step 2: A user must choose either the device location or a manual pin.
    if (!_hasLocationPin || !ReportValidation.validPin(_lat, _lng)) return 2;
    if (_resolvingAddress ||
        _location.text.trim().length < 2 ||
        _location.text.characters.length > 150 ||
        _address.text.trim().length < 5 ||
        _formattedAddress.characters.length > 500 ||
        ReportValidation.text(_city.text, min: 2, max: 80) != null ||
        ReportValidation.text(_country.text, min: 2, max: 80) != null ||
        ReportValidation.text(_address.text, min: 5, max: 250) != null ||
        ReportValidation.text(_address2.text, max: 100) != null ||
        ReportValidation.text(_state.text, max: 100) != null ||
        _postcodeError() != null) {
      return 2;
    }

    // Step 2: Evidence Files
    if (_files.isEmpty ||
        _files.any((f) => ReportValidation.evidence(f) != null)) {
      return 2;
    }

    return null;
  }

  String? _contactError() {
    if (_name.text.trim().isEmpty) {
      return 'Update your name in your profile before reporting.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      return 'Update your email in your profile before reporting.';
    }
    return ReportValidation.phone(_phone.text);
  }

  String? _postcodeError() =>
      ReportValidation.postcode(_postcode.text, _country.text);

  Widget _addressField(
    TextEditingController controller,
    String label, {
    String? hint,
    required int limit,
    bool requiredField = false,
    bool postcode = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_submitting && (controller == _location || !_resolvingAddress),
      maxLength: limit,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: _fieldDecoration(
        label: label,
        hint: hint,
        icon: controller == _location
            ? Icons.place_outlined
            : Icons.home_outlined,
      ),
      validator: (value) {
        if (_currentStep != 2) return null;
        if (postcode) return _postcodeError();
        return ReportValidation.text(
          value,
          min: requiredField ? (controller == _address ? 5 : 2) : 0,
          max: limit,
        );
      },
    ),
  );

  String? _dateError() {
    final incident = DateTime(
      _incidentDate.year,
      _incidentDate.month,
      _incidentDate.day,
      _incidentTime.hour,
      _incidentTime.minute,
    );
    return incident.isAfter(DateTime.now())
        ? 'Incident date and time cannot be in the future.'
        : null;
  }

  void _goToStep(int step) {
    if (_submitting) return;
    if (step > _currentStep) {
      final invalid = _getInvalidStep();
      if (invalid != null && invalid < step) {
        setState(() => _currentStep = invalid);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _formKey.currentState?.validate();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                invalid == 0
                    ? _contactError()!
                    : _dateError() ??
                          'Complete the required incident details before continuing.',
              ),
            ),
          );
        });
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = step);
  }

  Future<void> _submit() async {
    if (_submitting || _resolvingAddress || _locating) return;
    FocusScope.of(context).unfocus();

    final invalidStep = _getInvalidStep();
    if (invalidStep != null) {
      setState(() => _currentStep = invalidStep);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });

      String alertMessage = 'Please complete all required fields.';
      if (invalidStep == 0) {
        alertMessage = 'Please check your contact details in Step 1.';
      } else if (invalidStep == 1) {
        alertMessage = 'Please complete all missing details in Step 2.';
      } else if (invalidStep == 2 && !_hasLocationPin) {
        alertMessage =
            'Pin the incident location on the map before submitting.';
      } else if (invalidStep == 2 && _files.isEmpty) {
        alertMessage = 'At least one photo or video evidence is required.';
      } else if (invalidStep == 2) {
        alertMessage = _formattedAddress.characters.length > 500
            ? 'Shorten the combined address to 500 characters or fewer.'
            : _postcodeError() ??
                  'Review the landmark, street, city and country for your selected pin.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alertMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    var reportRequestStarted = false;
    try {
      final paths = await widget.service.uploadEvidence(_files);

      final finalCategory = _category == 'Other'
          ? _otherCategory.text.trim()
          : _category;

      // 1. Submit incident report
      reportRequestStarted = true;
      final report = await widget.service.submit(
        creatorProfileId: widget.profile.id,
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: _email.text.trim(),
        category: finalCategory,
        urgencyLevel: _urgencyLevel,
        location: _location.text.trim(),
        address: _formattedAddress,
        incidentDate: _incidentDate,
        incidentTime: _timeForDb(_incidentTime),
        description: _description.text.trim(),
        latitude: _lat,
        longitude: _lng,
        mediaPaths: paths,
      );

      // 2. Add in-app feedback notification entry
      await widget.service.createNotification(
        userId: widget.profile.id,
        title: 'Incident Report Submitted',
        message:
            'Ticket ${report.ticketId} was submitted and is now pending review.',
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ReportSuccessDialog(
          ticketId: report.ticketId,
          onDone: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        final feedback = ReportSubmissionFailure.from(
          error,
          reportRequestStarted: reportRequestStarted,
        );
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF243C91),
              size: 36,
            ),
            title: Text(feedback.title),
            content: Text(feedback.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back to report'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _timeForDb(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
      suffixIcon: readOnly
          ? const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            )
          : null,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
      ),
    );
  }

  Widget _buildSelectionBox(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = currentValue == option;

              Color chipSelectedColor = const Color(0xFF1E3A8A);
              if (title.contains('Urgency')) {
                if (option == 'Emergency') {
                  chipSelectedColor = const Color(0xFFDC2626);
                } else if (option == 'High') {
                  chipSelectedColor = const Color(0xFFEA580C);
                } else if (option == 'Low') {
                  chipSelectedColor = const Color(0xFF059669);
                }
              }

              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: chipSelectedColor,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) onChanged(option);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceUploadButtons() => EvidenceAddButton(
    onAdd: () => _pickMediaFiles(
      type: FileType.custom,
      extensions: const ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    ),
  );

  Widget _buildAttachedMediaPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 14),
      Text(
        'Attached evidence (${_files.length})',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      ..._files.asMap().entries.map(
        (entry) => EvidenceTile(
          name: entry.value.name,
          detail: '${(entry.value.size / (1024 * 1024)).toStringAsFixed(2)} MB',
          onPreview: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LocalEvidencePreview(file: entry.value),
            ),
          ),
          onRemove: () =>
              setState(() => _files = [..._files]..removeAt(entry.key)),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Submit Incident Report',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (widget.onLogout != null)
              IconButton(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, color: Color(0xFF0F172A)),
                tooltip: 'Log Out',
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: _submitting,
            child: Stepper(
              physics: const BouncingScrollPhysics(),
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepTapped: _goToStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  _goToStep(_currentStep + 1);
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  _goToStep(_currentStep - 1);
                }
              },
              controlsBuilder: (context, details) {
                if (_currentStep == 2) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: details.onStepContinue,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_currentStep != 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // STEP 1: Reporter Contact Details
                Step(
                  title: const Text(
                    'Reporter Contact Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  isActive: _currentStep >= 0,
                  content: Padding(
                    // A populated read-only field floats its label above the
                    // outline. Keep it clear of the Stepper content boundary.
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextFormField(
                            controller: _name,
                            readOnly: true,
                            validator: (v) =>
                                _currentStep == 0 &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Add your name in your profile first.'
                                : null,
                            decoration: _fieldDecoration(
                              label: 'Full Name*',
                              icon: Icons.person_outline_rounded,
                              readOnly: true,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextFormField(
                            controller: _phone,
                            maxLength: 24,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDecoration(
                              label: 'Phone Number*',
                              hint: 'e.g. 012 345 6789',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (value) => _currentStep == 0
                                ? ReportValidation.phone(value ?? '')
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextFormField(
                            controller: _email,
                            readOnly: true,
                            validator: (v) =>
                                _currentStep == 0 &&
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(v ?? '')
                                ? 'Update your email in your profile first.'
                                : null,
                            decoration: _fieldDecoration(
                              label: 'Email Address*',
                              icon: Icons.email_outlined,
                              readOnly: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // STEP 2: Incident Details
                Step(
                  title: const Text(
                    'Incident Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  isActive: _currentStep >= 1,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectionBox(
                        'Incident Category*',
                        _categories,
                        _category,
                        (val) => setState(() => _category = val),
                      ),

                      if (_category == 'Other')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextFormField(
                            controller: _otherCategory,
                            maxLength: 100,
                            decoration: _fieldDecoration(
                              label: 'Specify Incident Category*',
                              hint: 'e.g. Illegal business operations',
                              icon: Icons.category_outlined,
                            ),
                            validator: (v) =>
                                _currentStep == 1 && _category == 'Other'
                                ? ReportValidation.text(v, min: 2, max: 100)
                                : null,
                          ),
                        ),

                      _buildSelectionBox(
                        'Urgency Level*',
                        _urgencyLevels,
                        _urgencyLevel,
                        (val) => setState(() => _urgencyLevel = val),
                      ),

                      const Text(
                        'When did it happen?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFF1E3A8A),
                                size: 18,
                              ),
                              label: Text(
                                '${_incidentDate.day}/${_incidentDate.month}/${_incidentDate.year}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(
                                Icons.schedule_rounded,
                                color: Color(0xFF1E3A8A),
                                size: 18,
                              ),
                              label: Text(
                                _incidentTime.format(context),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_dateError() != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _dateError()!,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                        ),
                      TextFormField(
                        controller: _description,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 1000,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => Text(
                              '${1000 - currentLength} characters remaining',
                              semanticsLabel:
                                  '${1000 - currentLength} characters remaining out of 1000',
                              style: TextStyle(
                                fontSize: 12,
                                color: currentLength >= 900
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                        decoration: _fieldDecoration(
                          label: 'What Happened*',
                          hint:
                              'Describe what you observed and any useful details. Minimum 10 characters.',
                          icon: Icons.notes_rounded,
                        ),
                        validator: (value) => _currentStep != 1
                            ? null
                            : ReportValidation.text(value, min: 10, max: 1000),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Next: check the incident pin, enter a landmark and review the suggested address.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // STEP 3: Map Pin & Evidence
                Step(
                  title: const Text(
                    'Location Pin & Evidence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  isActive: _currentStep >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.pin_drop_rounded,
                                          color: Color(0xFF1E3A8A),
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'INCIDENT LOCATION',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _locating
                                        ? null
                                        : _openMapLocationPicker,
                                    child: const Text(
                                      'Change pin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 200,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(0),
                                ),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _selectedLatLng,
                                    zoom: 15,
                                  ),
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                  },
                                  onTap: _submitting || _locating
                                      ? null
                                      : (point) => _updatePinnedLocation(point),
                                  markers: _hasLocationPin
                                      ? {
                                          Marker(
                                            markerId: const MarkerId(
                                              'incident-preview-pin',
                                            ),
                                            position: _selectedLatLng,
                                          ),
                                        }
                                      : const <Marker>{},
                                  compassEnabled: false,
                                  zoomControlsEnabled: false,
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  mapToolbarEnabled: false,
                                  buildingsEnabled: true,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: const Color(0xFFF8FAFC),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasLocationPin
                                        ? (_locationFromDevice
                                              ? Icons.my_location_rounded
                                              : Icons.location_on_rounded)
                                        : Icons.info_outline_rounded,
                                    size: 18,
                                    color: _hasLocationPin
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _locating
                                          ? 'Finding your current location…'
                                          : _hasLocationPin
                                          ? (_locationFromDevice
                                                ? 'Pinned to your current device location.'
                                                : 'Manual location pin selected.')
                                          : 'Tap the map to place the incident pin.',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _locating
                                        ? null
                                        : _detectLocation,
                                    child: const Text('Use GPS'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_resolvingAddress) const LinearProgressIndicator(),
                      Text(
                        _locationMessage ??
                            'Search or tap the map to choose where the incident happened. GPS is optional.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _addressField(
                        _location,
                        'Place / landmark*',
                        hint: 'e.g. ICC Pudu, Level 1, near the main entrance',
                        limit: 150,
                        requiredField: true,
                      ),
                      _addressField(
                        _address,
                        'Address line 1*',
                        hint: 'Building number and street',
                        limit: 250,
                        requiredField: true,
                      ),
                      _addressField(
                        _address2,
                        'Address line 2 (optional)',
                        hint: 'Unit, floor or neighbourhood',
                        limit: 100,
                      ),
                      _addressField(
                        _postcode,
                        'Postcode',
                        hint: 'e.g. 55100',
                        limit: 12,
                        postcode: true,
                      ),
                      _addressField(
                        _city,
                        'City / town*',
                        limit: 80,
                        requiredField: true,
                      ),
                      _addressField(
                        _state,
                        'State / region (optional)',
                        limit: 100,
                      ),
                      _addressField(
                        _country,
                        'Country*',
                        limit: 80,
                        requiredField: true,
                      ),
                      const Text(
                        'Review the address before submitting. These fields are combined into one address for your ticket.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Evidence Upload
                      _buildEvidenceUploadButtons(),

                      // Media Preview
                      _buildAttachedMediaPreview(),

                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _submitting || _locating || _resolvingAddress
                              ? null
                              : _submit,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                          label: Text(
                            _submitting
                                ? 'Submitting Report...'
                                : 'Submit Incident Report',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
