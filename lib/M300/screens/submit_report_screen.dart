import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../M400/models/profile_model.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../services/community_report_service.dart';

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
  final _description = TextEditingController();
  final _otherCategory = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

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
  bool _locating = true;
  bool _submitting = false;

  final MapController _mapController = MapController();

  // Default fallback map position (Kuala Lumpur)
  LatLng _selectedLatLng = const LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phoneNumber ?? '');
    _email = TextEditingController(text: widget.profile.email);
    _detectLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    for (final controller in [
      _name,
      _phone,
      _email,
      _location,
      _address,
      _description,
      _otherCategory,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Location Detection with Device Settings Prompt
  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await _showLocationPromptDialog(
            title: 'Location Services Disabled',
            content:
                'Device location is turned off. Would you like to open settings to enable it for quick pinning?',
            onConfirm: () async => await Geolocator.openLocationSettings(),
          );
        }
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _useFallbackLocation();
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await _showLocationPromptDialog(
            title: 'Location Permission Denied',
            content:
                'Location permissions are permanently denied. Please enable them in app settings or manually pin your location.',
            onConfirm: () async => await Geolocator.openAppSettings(),
          );
        }
        _useFallbackLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      _updatePinnedLocation(LatLng(position.latitude, position.longitude));
    } catch (_) {
      _useFallbackLocation();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _useFallbackLocation() {
    _updatePinnedLocation(_selectedLatLng);
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _showLocationPromptDialog({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(content, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Use Manual Pin',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await onConfirm();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _updatePinnedLocation(LatLng target) {
    setState(() {
      _selectedLatLng = target;
      _lat = target.latitude;
      _lng = target.longitude;
      _latitude.text = target.latitude.toStringAsFixed(6);
      _longitude.text = target.longitude.toStringAsFixed(6);
    });

    _mapController.move(target, 15.0);
  }

  Future<void> _openMapLocationPicker() async {
    LatLng tempPicked = _selectedLatLng;

    final LatLng? pickedResult = await showDialog<LatLng>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setMapState) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: const Text(
                    'Tap Anywhere to Pin Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                  actions: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(dialogCtx).pop(tempPicked),
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF1E3A8A),
                      ),
                      label: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: tempPicked,
                        initialZoom: 16.0,
                        onTap: (tapPosition, point) {
                          setMapState(() {
                            tempPicked = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                          userAgentPackageName: 'com.findmy.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: tempPicked,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFDC2626),
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: Color(0xFF1E3A8A),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tap map to update pin position',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${tempPicked.latitude.toStringAsFixed(6)} | Lng: ${tempPicked.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedResult != null) {
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

    if (result == null) return;

    final List<PlatformFile> validFiles = [];
    final List<String> duplicateFileNames = [];
    final List<String> oversizedFileNames = [];

    // Names of files already added to the form
    final existingNames = _files.map((f) => f.name.toLowerCase()).toSet();

    for (final file in result.files) {
      // 1. Check file size threshold (10MB)
      if ((file.path == null && file.bytes == null) ||
          file.size >= CommunityReportService.maxFileBytes) {
        oversizedFileNames.add(file.name);
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
    if (oversizedFileNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped file(s) exceeding 10MB: ${oversizedFileNames.join(", ")}',
          ),
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

  void _syncCoordinates() {
    _lat = double.tryParse(_latitude.text.trim());
    _lng = double.tryParse(_longitude.text.trim());
    if (_lat != null && (_lat! < -90 || _lat! > 90)) _lat = null;
    if (_lng != null && (_lng! < -180 || _lng! > 180)) _lng = null;
  }

  /// Identifies if any previous step is missing mandatory fields
  int? _getInvalidStep() {
    // Step 0: Reporter Details
    if (_phone.text.trim().length < 5) return 0;

    // Step 1: Incident Details
    if (_location.text.trim().length < 2 ||
        _address.text.trim().length < 5 ||
        _description.text.trim().length < 10) {
      return 1;
    }
    if (_category == 'Other' && _otherCategory.text.trim().length < 2) {
      return 1;
    }

    // Step 2: Evidence Files
    if (_files.isEmpty) return 2;

    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final invalidStep = _getInvalidStep();
    if (invalidStep != null) {
      setState(() => _currentStep = invalidStep);
      _formKey.currentState?.validate();

      String alertMessage = 'Please complete all required fields.';
      if (invalidStep == 0) {
        alertMessage = 'Please check your contact details in Step 1.';
      } else if (invalidStep == 1) {
        alertMessage = 'Please complete all missing details in Step 2.';
      } else if (invalidStep == 2 && _files.isEmpty) {
        alertMessage = 'At least one photo or video evidence is required.';
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
    _syncCoordinates();

    setState(() => _submitting = true);
    try {
      final paths = await widget.service.uploadEvidence(_files);

      final finalCategory = _category == 'Other'
          ? _otherCategory.text.trim()
          : _category;

      // 1. Submit incident report
      final report = await widget.service.submit(
        creatorProfileId: widget.profile.id,
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: _email.text.trim(),
        category: finalCategory,
        urgencyLevel: _urgencyLevel,
        location: _location.text.trim(),
        address: _address.text.trim(),
        incidentDate: _incidentDate,
        incidentTime: _timeForDb(_incidentTime),
        description: _description.text.trim(),
        latitude: _lat,
        longitude: _lng,
        mediaPaths: paths,
      );

      // 2. Add in-app feedback notification entry
      await widget.service.createNotification(
        email: _email.text.trim(),
        title: 'Report Submitted Successfully',
        body:
            'Your incident report (Ticket ID: ${report.ticketId}) has been received and registered in our system.',
      );

      if (!mounted) return;

      // Enhanced Success Dialog UI
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Animated Success Icon Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 40,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Title & Subtitle
                  const Text(
                    'Report Submitted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your incident report has been registered successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Ticket Reference Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TICKET REFERENCE NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              report.ticketId,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Color(0xFF1E3A8A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: report.ticketId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Ticket ID copied to clipboard!',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF0F172A),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Helper Note
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Keep this reference number to track your report.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 5. Full-Width Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _timeForDb(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

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

  Widget _buildEvidenceUploadButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'ATTACH EVIDENCE (PHOTOS & VIDEOS)*',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickMediaFiles(
                  type: FileType.custom,
                  extensions: ['jpg', 'jpeg', 'png'],
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        color: Color(0xFF1E3A8A),
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add Photos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'JPG, PNG (<10MB)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickMediaFiles(
                  type: FileType.custom,
                  extensions: ['mp4', 'mov', 'avi', 'mkv', 'webm'],
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.video_call_rounded,
                        color: Color(0xFF15803D),
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add Video',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'MP4, MOV (<10MB)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachedMediaPreview() {
    if (_files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'ATTACHED EVIDENCE (${_files.length})',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _files.length,
          itemBuilder: (context, index) {
            final file = _files[index];
            final ext = file.extension?.toLowerCase() ?? '';
            final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isVideo
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    color: isVideo
                        ? const Color(0xFF15803D)
                        : const Color(0xFF1E3A8A),
                    size: 18,
                  ),
                ),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _files = [..._files]..removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
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
        child: Stepper(
          physics: const BouncingScrollPhysics(),
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
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
              content: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _name,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Full Name*',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        suffixIcon: const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number*',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().length < 5
                          ? 'Enter valid phone number'
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _email,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email Address*',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        suffixIcon: const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
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
                        decoration: InputDecoration(
                          labelText: 'Specify Incident Category*',
                          hintText: 'e.g., Illegal business operations',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) =>
                            _category == 'Other' &&
                                (v == null || v.trim().length < 2)
                            ? 'Please specify category'
                            : null,
                      ),
                    ),

                  _buildSelectionBox(
                    'Urgency Level*',
                    _urgencyLevels,
                    _urgencyLevel,
                    (val) => setState(() => _urgencyLevel = val),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _location,
                      decoration: InputDecoration(
                        labelText: 'Location / Landmark*',
                        hintText: 'e.g., Central Market Plaza',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Required (min 2 chars)'
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Full Address*',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().length < 5
                          ? 'Required (min 5 chars)'
                          : null,
                    ),
                  ),
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
                  TextFormField(
                    controller: _description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'What Happened*',
                      hintText:
                          'Describe the violation or incident in detail...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) =>
                        value != null && value.trim().length >= 10
                        ? null
                        : 'Please provide at least 10 characters',
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.pin_drop_rounded,
                                    color: Color(0xFF1E3A8A),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'MAP LOCATION PIN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _openMapLocationPicker,
                                child: const Text(
                                  'Expand Map',
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
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _selectedLatLng,
                                initialZoom: 15.0,
                                onTap: (tapPosition, point) =>
                                    _updatePinnedLocation(point),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                  userAgentPackageName: 'com.findmy.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLatLng,
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.topCenter,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFDC2626),
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF8FAFC),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tap map anywhere to adjust pin manually.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _latitude,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Latitude',
                                        isDense: true,
                                        filled: true,
                                        fillColor: Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _longitude,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Longitude',
                                        isDense: true,
                                        filled: true,
                                        fillColor: Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      onPressed: _submitting ? null : _submit,
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
    );
  }
}
