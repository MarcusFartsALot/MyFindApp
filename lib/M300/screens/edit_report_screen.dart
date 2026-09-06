import '../models/report_validation.dart';
import '../widgets/evidence_tile.dart';
import '../services/incident_location_access.dart';
import '../models/incident_address.dart';
import '../widgets/local_evidence_preview.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../models/incident_report_model.dart';
import '../services/community_report_service.dart';
import '../widgets/edge_swipe_back.dart';
import '../widgets/incident_location_picker.dart';

class EditReportScreen extends StatefulWidget {
  final IncidentReportModel report;
  final CommunityReportService service;
  final bool readOnly;

  const EditReportScreen({
    super.key,
    required this.report,
    required this.service,
    this.readOnly = false,
  });

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _resolving = false;
  int _pinRevision = 0;
  String? _addressMessage;
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _postcode = TextEditingController();
  final _region = TextEditingController();
  final _country = TextEditingController();
  bool get _readOnly => widget.readOnly || !widget.report.canEdit;
  String get _fullAddress => IncidentAddress(
    line1: _address.text,
    line2: _line2.text,
    city: _city.text,
    postcode: _postcode.text,
    state: _region.text,
    country: _country.text,
  ).formatted;

  // Locked Read-Only Controllers
  late final TextEditingController _reporterName;
  late final TextEditingController _reporterPhone;
  late final TextEditingController _reporterEmail;
  late final TextEditingController _category;
  late final TextEditingController _incidentDateTime;

  // Editable Controllers
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  late List<String> _existingMediaPaths;
  List<PlatformFile> _newFiles = [];
  bool _saving = false;

  // Map Controller and State
  GoogleMapController? _mapController;
  late LatLng _selectedLatLng;
  bool _locating = false;
  bool _locationFromDevice = false;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();

    // Populate Read-Only Fields
    _reporterName = TextEditingController(text: widget.report.fullName);
    _reporterPhone = TextEditingController(text: widget.report.phoneNumber);
    _reporterEmail = TextEditingController(text: widget.report.email);
    _category = TextEditingController(text: widget.report.category);

    final dateStr =
        '${widget.report.incidentDate.day}/${widget.report.incidentDate.month}/${widget.report.incidentDate.year}';
    final timeStr = widget.report.incidentTime;
    _incidentDateTime = TextEditingController(text: '$dateStr at $timeStr');

    // Populate Editable Fields
    _description = TextEditingController(text: widget.report.description);
    _location = TextEditingController(text: widget.report.location);
    final savedAddress = IncidentAddress.fromFormatted(widget.report.address);
    _address = TextEditingController(
      text: _readOnly ? widget.report.address : savedAddress.line1,
    );
    _line2.text = savedAddress.line2;
    _city.text = savedAddress.city;
    _postcode.text = savedAddress.postcode;
    _region.text = savedAddress.state;
    _country.text = savedAddress.country;

    final double initialLat = widget.report.latitude ?? 3.1390;
    final double initialLng = widget.report.longitude ?? 101.6869;

    _selectedLatLng = LatLng(initialLat, initialLng);
    _latitude = TextEditingController(
      text: widget.report.latitude?.toStringAsFixed(6) ?? '',
    );
    _longitude = TextEditingController(
      text: widget.report.longitude?.toStringAsFixed(6) ?? '',
    );

    _existingMediaPaths = List.from(widget.report.mediaPaths);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    for (final controller in [
      _reporterName,
      _reporterPhone,
      _reporterEmail,
      _category,
      _incidentDateTime,
      _description,
      _location,
      _address,
      _latitude,
      _longitude,
      _line2,
      _city,
      _postcode,
      _region,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Rechecks location access before resolving the current device position.
  Future<void> _detectLocation() async {
    if (_locating || _readOnly || _saving) return;
    setState(() => _locating = true);

    try {
      if (!await _requestLocationAccess()) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get the device location. Please pin the map manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _requestLocationAccess() async {
    final allowed = await IncidentLocationAccess.request(context);
    if (mounted) setState(() => _locationPermissionGranted = allowed);
    return allowed;
  }

  Future<void> _updatePinnedLocation(
    LatLng target, {
    bool fromDevice = false,
  }) async {
    if (_readOnly || _saving) return;
    final revision = ++_pinRevision;
    setState(() {
      _resolving = true;
      _selectedLatLng = target;
      _latitude.text = target.latitude.toStringAsFixed(6);
      _longitude.text = target.longitude.toStringAsFixed(6);
      _locationFromDevice = fromDevice;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(target.latitude, target.longitude)
          .timeout(const Duration(seconds: 12));
      if (!mounted || revision != _pinRevision) return;
      if (places.isEmpty) throw StateError('No address');
      final address = IncidentAddress.fromPlacemark(places.first);
      _address.text = address.line1;
      _line2.text = address.line2;
      _city.text = address.city;
      _postcode.text = address.postcode;
      _region.text = address.state;
      _country.text = address.country;
      _addressMessage =
          'Address updated from your pin. Review it before saving. Your landmark is unchanged.';
    } catch (_) {
      if (!mounted || revision != _pinRevision) return;
      _addressMessage =
          'Address lookup failed. Update the saved address manually to match the new pin.';
    } finally {
      if (mounted && revision == _pinRevision) {
        setState(() => _resolving = false);
      }
    }
  }

  Future<void> _openMapLocationPicker() async {
    if (_saving || _locating || _readOnly) return;
    final pickedResult = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncidentLocationPickerPage(
          initialLocation: _selectedLatLng,
          hasInitialPin:
              _latitude.text.isNotEmpty && _longitude.text.isNotEmpty,
          myLocationEnabled: _locationPermissionGranted,
        ),
      ),
    );

    if (mounted && pickedResult != null) {
      _updatePinnedLocation(pickedResult);
    }
  }

  /// Adds new files with strict duplicate checks against staged & existing evidence
  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      withData: kIsWeb,
    );
    if (result == null || !mounted) return;

    final List<PlatformFile> validFiles = [];
    final List<String> duplicateFileNames = [];

    // Extract raw filenames from already saved paths
    final existingNames = _existingMediaPaths
        .map((path) => path.split('/').last.toLowerCase())
        .toSet();

    // Extract filenames from currently staged new files
    final newlyAddedNames = _newFiles
        .map((file) => file.name.toLowerCase())
        .toSet();

    for (final file in result.files) {
      // 1. File size check
      if (ReportValidation.evidence(file) != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name}: ${ReportValidation.evidence(file)}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
        continue;
      }

      final fileNameLower = file.name.toLowerCase();

      // 2. Duplicate check
      if (existingNames.contains(fileNameLower) ||
          newlyAddedNames.contains(fileNameLower)) {
        duplicateFileNames.add(file.name);
      } else {
        validFiles.add(file);
        newlyAddedNames.add(fileNameLower);
      }
    }

    // 3. Show warning dialog if duplicates were detected
    if (duplicateFileNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
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

    // 4. Add valid files
    if (validFiles.isNotEmpty) {
      setState(() {
        _newFiles = [..._newFiles, ...validFiles];
      });
    }
  }

  void _removeExistingMedia(int index) {
    setState(() => _existingMediaPaths.removeAt(index));
  }

  void _removeNewFile(int index) {
    setState(() => _newFiles.removeAt(index));
  }

  /// Evidence Preview modal dialog
  void _previewMedia(String path) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LocalEvidencePreview.saved(storagePath: path),
    ),
  );

  Future<void> _save() async {
    if (_saving ||
        _resolving ||
        _locating ||
        _readOnly ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_existingMediaPaths.isEmpty && _newFiles.isEmpty ||
        !ReportValidation.validPin(
          double.tryParse(_latitude.text),
          double.tryParse(_longitude.text),
        ) ||
        _newFiles.any((f) => ReportValidation.evidence(f) != null) ||
        _fullAddress.characters.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirm an incident pin, keep at least one evidence file, and limit the combined address to 500 characters.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final latest = await widget.service.getReportByTicket(
        widget.report.ticketId,
      );
      if (latest == null ||
          latest['creator_profile_id'] != widget.report.creatorProfileId ||
          latest['status'] != 'Pending Review') {
        throw AppException(
          'This ticket is no longer available for editing. Return to Track Ticket to view its latest status.',
        );
      }
      final added = await widget.service.uploadEvidence(_newFiles);
      await widget.service.updatePending(
        reportId: widget.report.id,
        description: _description.text.trim(),
        location: _location.text.trim(),
        address: _fullAddress,
        latitude: double.tryParse(_latitude.text),
        longitude: double.tryParse(_longitude.text),
        mediaPaths: [..._existingMediaPaths, ...added],
      );

      await widget.service.createNotification(
        userId: widget.report.creatorProfileId,
        title: 'Incident Report Updated',
        message:
            'Your changes to ticket ${widget.report.ticketId} were saved successfully.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report updated successfully.'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
        Navigator.pop(context);
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    IconData? prefixIcon,
    bool isLocked = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              color: isLocked
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF1E3A8A),
              size: 20,
            )
          : null,
      suffixIcon: isLocked
          ? const Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8))
          : null,
      filled: true,
      fillColor: isLocked ? const Color(0xFFEFF3F8) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isLocked ? const Color(0xFFD7DEE8) : const Color(0xFF94A3B8),
          width: isLocked ? 1 : 1.15,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isLocked ? const Color(0xFFE2E8F0) : const Color(0xFF1E3A8A),
          width: isLocked ? 1.0 : 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool locked = false,
    int? limit,
    int min = 0,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      readOnly: locked || _readOnly,
      enabled:
          !_saving &&
          (!_resolving ||
              locked ||
              controller == _description ||
              controller == _location),
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      maxLength: locked || _readOnly ? null : limit,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: _inputDecoration(label, isLocked: locked || _readOnly),
      buildCounter: controller == _description && !_readOnly
          ? (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => Text(
              '${1000 - currentLength} characters remaining',
              style: TextStyle(
                fontSize: 12,
                color: currentLength >= 900
                    ? Colors.orange.shade800
                    : const Color(0xFF64748B),
              ),
            )
          : null,
      validator: (value) {
        if (_readOnly || locked) return null;
        if (controller == _postcode) {
          return ReportValidation.postcode(value ?? '', _country.text);
        }
        return ReportValidation.text(value, min: min, max: limit ?? 1000);
      },
    ),
  );

  Widget _reporterFields() => Column(
    children: [
      _field(_reporterName, 'Full name', locked: true),
      _field(_reporterPhone, 'Phone number', locked: true),
      _field(_reporterEmail, 'Email address', locked: true),
    ],
  );

  Widget _incidentFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(_category, 'Incident category', locked: true),
      _field(_incidentDateTime, 'Incident date and time', locked: true),
      Text(
        'Urgency: ${widget.report.urgencyLevel}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 14),
      _field(_description, 'What happened*', min: 10, limit: 1000, lines: 4),
    ],
  );

  Widget _locationAndEvidence() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Incident location',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!_readOnly)
                    TextButton(
                      onPressed: _locating ? null : _openMapLocationPicker,
                      child: const Text('Change pin'),
                    ),
                ],
              ),
            ),
            if (_latitude.text.isNotEmpty && _longitude.text.isNotEmpty)
              SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLatLng,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: {
                    Marker(
                      markerId: const MarkerId('saved-report'),
                      position: _selectedLatLng,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  },
                  onTap: _readOnly || _locating
                      ? null
                      : (point) => _updatePinnedLocation(point),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No saved incident pin.'),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _locating
                          ? 'Finding your location…'
                          : _locationFromDevice
                          ? 'GPS pin selected. Check the incident position.'
                          : 'Saved incident location',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (!_readOnly)
                    TextButton(
                      onPressed: _locating ? null : _detectLocation,
                      child: const Text('Use GPS'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (_resolving) const LinearProgressIndicator(),
      if (_addressMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _addressMessage!,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      _field(_location, 'Place / landmark*', min: 2, limit: 150),
      if (_readOnly)
        _field(_address, 'Incident address', locked: true, lines: 3)
      else ...[
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Review your saved address below. You can edit these fields without changing the incident pin.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        _field(_address, 'Address line 1*', min: 5, limit: 250, lines: 2),
        _field(_line2, 'Address line 2 (optional)', limit: 100),
        _field(_postcode, 'Postcode', limit: 12),
        _field(_city, 'City / town*', min: 2, limit: 80),
        _field(_region, 'State / region', limit: 100),
        _field(_country, 'Country*', min: 2, limit: 80),
      ],
      const Text(
        'Attached evidence',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ..._existingMediaPaths.asMap().entries.map(
        (entry) => EvidenceTile(
          name: entry.value.split('/').last,
          onPreview: () => _previewMedia(entry.value),
          onRemove: _readOnly ? null : () => _removeExistingMedia(entry.key),
        ),
      ),
      ..._newFiles.asMap().entries.map(
        (entry) => EvidenceTile(
          name: entry.value.name,
          detail: '${(entry.value.size / (1024 * 1024)).toStringAsFixed(2)} MB',
          onPreview: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LocalEvidencePreview(file: entry.value),
            ),
          ),
          onRemove: () => _removeNewFile(entry.key),
        ),
      ),
      if (!_readOnly) ...[
        const SizedBox(height: 12),
        EvidenceAddButton(onAdd: _addFiles),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving || _resolving || _locating ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.all(16),
          ),
          child: Text(_saving ? 'Saving changes…' : 'Save changes'),
        ),
      ],
    ],
  );

  void _changeStep(int step) {
    if (_saving) return;
    if (step > _step &&
        _step == 1 &&
        ReportValidation.text(_description.text, min: 10, max: 1000) != null) {
      _formKey.currentState?.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  @override
  Widget build(BuildContext context) => EdgeSwipeBack(
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _readOnly ? 'Ticket details' : 'Edit incident report',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _readOnly
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SelectableText(
                  widget.report.ticketId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.report.status} · Read only',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                _reporterFields(),
                _incidentFields(),
                _locationAndEvidence(),
              ],
            )
          : Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: _saving,
                child: Stepper(
                  currentStep: _step,
                  onStepTapped: _changeStep,
                  onStepContinue: () => _changeStep((_step + 1).clamp(0, 2)),
                  onStepCancel: () => _changeStep((_step - 1).clamp(0, 2)),
                  controlsBuilder: (context, details) => _step == 2
                      ? const SizedBox.shrink()
                      : Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: details.onStepContinue,
                              child: const Text('Continue'),
                            ),
                            if (_step > 0)
                              OutlinedButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Back'),
                              ),
                          ],
                        ),
                  steps: [
                    Step(
                      title: const Text('Reporter Contact Details'),
                      isActive: _step >= 0,
                      content: Column(
                        children: [
                          Text(
                            '${widget.report.ticketId} · Pending Review',
                            style: const TextStyle(color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 16),
                          _reporterFields(),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Incident Details'),
                      isActive: _step >= 1,
                      content: _incidentFields(),
                    ),
                    Step(
                      title: const Text('Location Pin & Evidence'),
                      isActive: _step >= 2,
                      content: _locationAndEvidence(),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
