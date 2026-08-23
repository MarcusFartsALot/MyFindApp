import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../models/incident_report_model.dart';
import '../services/community_report_service.dart';

class EditReportScreen extends StatefulWidget {
  final IncidentReportModel report;
  final CommunityReportService service;

  const EditReportScreen({
    super.key,
    required this.report,
    required this.service,
  });

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();

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
    _address = TextEditingController(text: widget.report.address);

    final double initialLat = widget.report.latitude ?? 3.1390;
    final double initialLng = widget.report.longitude ?? 101.6869;

    _selectedLatLng = LatLng(initialLat, initialLng);
    _latitude = TextEditingController(text: initialLat.toStringAsFixed(6));
    _longitude = TextEditingController(text: initialLng.toStringAsFixed(6));

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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Resolves raw media storage keys to signed URLs for private/public access
  Future<String> _getMediaUrl(String rawPath) async {
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }
    try {
      const String bucketName = CommunityReportService.bucketName;

      String cleanPath = rawPath;
      if (cleanPath.startsWith('$bucketName/')) {
        cleanPath = cleanPath.substring(bucketName.length + 1);
      }

      // Generate Signed URL valid for 1 hour
      return await Supabase.instance.client.storage
          .from(bucketName)
          .createSignedUrl(cleanPath, 3600);
    } catch (_) {
      return Supabase.instance.client.storage
          .from(CommunityReportService.bucketName)
          .getPublicUrl(rawPath);
    }
  }

  Future<void> _detectLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are off. Enable GPS or pin the map manually.',
              ),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission was not granted. You can pin the map manually.',
              ),
            ),
          );
        }
        return;
      }

      _locationPermissionGranted = true;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _updatePinnedLocation(
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

  void _updatePinnedLocation(LatLng target, {bool fromDevice = false}) {
    setState(() {
      _selectedLatLng = target;
      _latitude.text = target.latitude.toStringAsFixed(6);
      _longitude.text = target.longitude.toStringAsFixed(6);
      _locationFromDevice = fromDevice;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
  }

  Future<void> _openMapLocationPicker() async {
    LatLng tempPicked = _selectedLatLng;
    final searchController = TextEditingController();
    final geocoding = Geocoding();
    GoogleMapController? expandedMapController;
    bool searching = false;
    bool dialogOpen = true;
    String? searchError;

    Future<void> searchLocation(StateSetter setMapState) async {
      final query = searchController.text.trim();
      if (query.isEmpty || searching || !dialogOpen) return;

      setMapState(() {
        searching = true;
        searchError = null;
      });

      try {
        // Native device geocoding keeps search free of billable Places calls.
        final matches = await geocoding.locationFromAddress(query);
        if (!dialogOpen) return;
        if (matches.isEmpty) {
          setMapState(() => searchError = 'No matching location found.');
          return;
        }

        final match = matches.first;
        tempPicked = LatLng(match.latitude, match.longitude);
        setMapState(() {});
        await expandedMapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: tempPicked, zoom: 16),
          ),
        );
      } on PlatformException catch (error) {
        if (!dialogOpen) return;
        setMapState(() {
          searchError = error.code == 'IO_ERROR'
              ? 'Location search is unavailable. You can still tap the map.'
              : 'Could not search for that location.';
        });
      } catch (_) {
        if (dialogOpen) {
          setMapState(
            () => searchError = 'Could not search for that location.',
          );
        }
      } finally {
        if (dialogOpen) setMapState(() => searching = false);
      }
    }

    final LatLng? pickedResult = await showDialog<LatLng>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setMapState) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: const Text(
                    'Choose Incident Location',
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
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: tempPicked,
                        zoom: 16,
                      ),
                      onMapCreated: (controller) {
                        expandedMapController = controller;
                      },
                      onTap: (point) {
                        FocusScope.of(context).unfocus();
                        setMapState(() {
                          tempPicked = point;
                          searchError = null;
                        });
                      },
                      markers: {
                        Marker(
                          markerId: const MarkerId('edit-incident-pin'),
                          position: tempPicked,
                        ),
                      },
                      compassEnabled: true,
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      myLocationEnabled: _locationPermissionGranted,
                      myLocationButtonEnabled: _locationPermissionGranted,
                      mapToolbarEnabled: false,
                      padding: const EdgeInsets.only(top: 86, bottom: 100),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => searchLocation(setMapState),
                          decoration: InputDecoration(
                            hintText: 'Search address or landmark',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF1E3A8A),
                            ),
                            suffixIcon: searching
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Search location',
                                    onPressed: () =>
                                        searchLocation(setMapState),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                  ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (searchError != null)
                      Positioned(
                        top: 82,
                        left: 18,
                        right: 18,
                        child: Material(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              searchError!,
                              style: const TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
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
                              const Text(
                                'Move the pin, then confirm this location.',
                                style: TextStyle(
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

    dialogOpen = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchController.dispose();
    });

    if (pickedResult != null) {
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
    if (result == null) return;

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
      if ((file.path == null && file.bytes == null) ||
          file.size >= CommunityReportService.maxFileBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" exceeds the 10 MB limit.'),
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
  void _previewMedia(String rawPath) {
    final ext = rawPath.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Media Preview',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 450),
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<String>(
                future: _getMediaUrl(rawPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Unable to load media URL.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final url = snapshot.data!;

                  if (isVideo) {
                    return _NetworkVideoPreview(
                      url: url,
                      fileName: rawPath.split('/').last,
                    );
                  }

                  return Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Unable to render image preview.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!widget.report.canEdit ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);

    try {
      final added = await widget.service.uploadEvidence(_newFiles);
      await widget.service.updatePending(
        reportId: widget.report.id,
        description: _description.text.trim(),
        location: _location.text.trim(),
        address: _address.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status and Ticket Summary Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    color: Color(0xFFB45309),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket ID: ${widget.report.ticketId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF78350F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'PENDING REVIEW · Editable State',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 1: VISIBLE LOCKED INFORMATION (READ ONLY)
            const Text(
              'LOCKED INFORMATION (VIEW ONLY)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _reporterName,
              readOnly: true,
              decoration: _inputDecoration(
                'Reporter Full Name',
                prefixIcon: Icons.person_outline,
                isLocked: true,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _reporterPhone,
                    readOnly: true,
                    decoration: _inputDecoration(
                      'Phone Number',
                      prefixIcon: Icons.phone_outlined,
                      isLocked: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _reporterEmail,
                    readOnly: true,
                    decoration: _inputDecoration(
                      'Email Address',
                      prefixIcon: Icons.email_outlined,
                      isLocked: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _category,
              readOnly: true,
              decoration: _inputDecoration(
                'Incident Category',
                prefixIcon: Icons.category_outlined,
                isLocked: true,
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _incidentDateTime,
              readOnly: true,
              decoration: _inputDecoration(
                'Incident Time & Date',
                prefixIcon: Icons.event_outlined,
                isLocked: true,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 24),

            // SECTION 2: EDITABLE INCIDENT DETAILS
            const Text(
              'EDITABLE INCIDENT DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: _inputDecoration(
                'What happened*',
                prefixIcon: Icons.description_outlined,
              ),
              validator: (value) => value != null && value.trim().length >= 10
                  ? null
                  : 'Please provide at least 10 characters',
            ),
            const SizedBox(height: 20),

            // Map Location Pin Picker (same Google Maps UI as submit report)
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
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLatLng,
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: _updatePinnedLocation,
                        markers: {
                          Marker(
                            markerId: const MarkerId(
                              'edit-incident-preview-pin',
                            ),
                            position: _selectedLatLng,
                          ),
                        },
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
                          _locationFromDevice
                              ? Icons.my_location_rounded
                              : Icons.location_on_rounded,
                          size: 18,
                          color: const Color(0xFF15803D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locating
                                ? 'Finding your current location…'
                                : _locationFromDevice
                                ? 'Pinned to your current device location.'
                                : 'Tap the map to adjust the saved incident pin.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
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

            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: _inputDecoration(
                'Location Name / Landmark*',
                prefixIcon: Icons.location_city_outlined,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: _inputDecoration(
                'Street Address*',
                prefixIcon: Icons.place_outlined,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // SECTION 3: ATTACHED EVIDENCE PREVIEW & UPLOAD
            const Text(
              'Attached Evidence',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the eye icon to preview attached files or delete to replace.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            if (_existingMediaPaths.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No initial evidence attached.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              )
            else
              Column(
                children: List.generate(_existingMediaPaths.length, (index) {
                  final rawPath = _existingMediaPaths[index];
                  final fileName = rawPath.split('/').last;
                  final extension = fileName.split('.').last.toLowerCase();
                  final isVideo = const {
                    'mp4',
                    'mov',
                    'avi',
                    'mkv',
                    'webm',
                  }.contains(extension);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        isVideo
                            ? Icons.video_library_outlined
                            : Icons.image_outlined,
                        color: isVideo
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1E3A8A),
                      ),
                      title: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: Color(0xFF0284C7),
                              size: 18,
                            ),
                            tooltip: 'Preview Evidence',
                            onPressed: () => _previewMedia(rawPath),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            tooltip: 'Remove File',
                            onPressed: () => _removeExistingMedia(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 12),

            // Append New Supporting Media Button
            OutlinedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Append New Media (Photos / Videos)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF1E3A8A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_newFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_newFiles.length, (index) {
                final file = _newFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.attachment_rounded,
                      color: Color(0xFF15803D),
                    ),
                    title: Text(
                      file.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF15803D),
                        size: 16,
                      ),
                      onPressed: () => _removeNewFile(index),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 28),

            // Save Changes Submit Button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  final String url;
  final String fileName;

  const _NetworkVideoPreview({required this.url, required this.fileName});

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialization = _controller.initialize().then((_) {
      _controller.setLooping(false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError || !_controller.value.isInitialized) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'This video format could not be played on this device.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _controller.value;
            final durationMs = value.duration.inMilliseconds;
            final positionMs = value.position.inMilliseconds.clamp(
              0,
              durationMs > 0 ? durationMs : 1,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: value.aspectRatio > 0
                      ? value.aspectRatio
                      : 16 / 9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: 34,
                          color: Colors.white,
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          onPressed: () {
                            value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          },
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF60A5FA),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: const Color(0x3360A5FA),
                  ),
                  child: Slider(
                    min: 0,
                    max: durationMs > 0 ? durationMs.toDouble() : 1,
                    value: positionMs.toDouble(),
                    onChanged: (value) => _controller.seekTo(
                      Duration(milliseconds: value.round()),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
