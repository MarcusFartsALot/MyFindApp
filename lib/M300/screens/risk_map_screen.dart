import '../widgets/load_failure_card.dart';
import '../widgets/adaptive_pair.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _RiskLevel { yellow, orange, red }

extension on _RiskLevel {
  String get label => switch (this) {
    _RiskLevel.yellow => 'Yellow',
    _RiskLevel.orange => 'Orange',
    _RiskLevel.red => 'Red',
  };

  Color get color => switch (this) {
    _RiskLevel.yellow => const Color(0xFFEAB308),
    _RiskLevel.orange => const Color(0xFFF97316),
    _RiskLevel.red => const Color(0xFFDC2626),
  };

  double get markerHue => switch (this) {
    _RiskLevel.yellow => BitmapDescriptor.hueYellow,
    _RiskLevel.orange => BitmapDescriptor.hueOrange,
    _RiskLevel.red => BitmapDescriptor.hueRed,
  };
}

// W.P. Kuala Lumpur. Kept locally so displaying the boundary
const _kualaLumpurBoundary = <LatLng>[
  LatLng(3.24432, 101.66725),
  LatLng(3.23577, 101.67329),
  LatLng(3.23086, 101.6723),
  LatLng(3.23134, 101.69724),
  LatLng(3.22639, 101.69736),
  LatLng(3.2266, 101.7021),
  LatLng(3.21977, 101.70265),
  LatLng(3.21826, 101.70899),
  LatLng(3.21927, 101.71045),
  LatLng(3.21596, 101.71488),
  LatLng(3.21843, 101.71758),
  LatLng(3.21769, 101.71528),
  LatLng(3.22113, 101.71596),
  LatLng(3.22128, 101.71855),
  LatLng(3.22435, 101.71872),
  LatLng(3.23023, 101.72403),
  LatLng(3.23217, 101.72416),
  LatLng(3.2314, 101.72502),
  LatLng(3.23641, 101.73033),
  LatLng(3.23485, 101.73219),
  LatLng(3.23527, 101.73941),
  LatLng(3.23664, 101.73981),
  LatLng(3.23145, 101.74373),
  LatLng(3.22587, 101.73951),
  LatLng(3.21878, 101.7384),
  LatLng(3.21746, 101.74158),
  LatLng(3.21243, 101.74585),
  LatLng(3.20601, 101.74748),
  LatLng(3.20575, 101.75045),
  LatLng(3.20345, 101.75106),
  LatLng(3.20359, 101.7538),
  LatLng(3.19969, 101.75657),
  LatLng(3.19142, 101.75872),
  LatLng(3.18837, 101.75785),
  LatLng(3.18803, 101.75545),
  LatLng(3.18747, 101.75676),
  LatLng(3.18322, 101.75532),
  LatLng(3.17876, 101.74859),
  LatLng(3.18123, 101.73274),
  LatLng(3.17979, 101.73359),
  LatLng(3.17608, 101.73182),
  LatLng(3.17545, 101.73473),
  LatLng(3.16784, 101.73457),
  LatLng(3.16775, 101.73904),
  LatLng(3.16554, 101.73924),
  LatLng(3.16406, 101.75058),
  LatLng(3.16159, 101.74819),
  LatLng(3.16079, 101.74999),
  LatLng(3.15646, 101.74679),
  LatLng(3.1526, 101.74639),
  LatLng(3.15359, 101.74043),
  LatLng(3.15106, 101.74115),
  LatLng(3.14746, 101.73856),
  LatLng(3.14645, 101.74003),
  LatLng(3.13988, 101.73538),
  LatLng(3.12716, 101.74084),
  LatLng(3.12193, 101.7393),
  LatLng(3.12049, 101.73742),
  LatLng(3.11636, 101.73804),
  LatLng(3.11274, 101.74126),
  LatLng(3.11262, 101.74383),
  LatLng(3.11436, 101.74447),
  LatLng(3.1137, 101.74736),
  LatLng(3.11286, 101.74678),
  LatLng(3.11023, 101.75184),
  LatLng(3.10748, 101.75368),
  LatLng(3.10421, 101.75045),
  LatLng(3.09993, 101.75232),
  LatLng(3.09509, 101.75104),
  LatLng(3.08908, 101.74507),
  LatLng(3.08516, 101.746),
  LatLng(3.08424, 101.74491),
  LatLng(3.07899, 101.74823),
  LatLng(3.0573, 101.74838),
  LatLng(3.05697, 101.73075),
  LatLng(3.03872, 101.731),
  LatLng(3.0409, 101.72938),
  LatLng(3.03708, 101.72284),
  LatLng(3.03998, 101.72269),
  LatLng(3.04012, 101.72442),
  LatLng(3.04231, 101.72459),
  LatLng(3.0443, 101.72163),
  LatLng(3.05096, 101.72014),
  LatLng(3.05048, 101.71663),
  LatLng(3.05346, 101.7174),
  LatLng(3.05307, 101.71609),
  LatLng(3.05742, 101.71545),
  LatLng(3.05778, 101.71372),
  LatLng(3.05761, 101.71166),
  LatLng(3.05109, 101.70864),
  LatLng(3.05107, 101.7073),
  LatLng(3.05299, 101.7073),
  LatLng(3.05277, 101.70254),
  LatLng(3.05207, 101.69986),
  LatLng(3.04913, 101.69949),
  LatLng(3.04886, 101.69347),
  LatLng(3.04712, 101.69157),
  LatLng(3.04906, 101.68672),
  LatLng(3.04516, 101.67926),
  LatLng(3.04601, 101.67203),
  LatLng(3.04489, 101.66979),
  LatLng(3.04952, 101.66975),
  LatLng(3.04972, 101.65262),
  LatLng(3.05426, 101.65468),
  LatLng(3.05279, 101.66073),
  LatLng(3.06218, 101.66073),
  LatLng(3.0606, 101.65451),
  LatLng(3.06239, 101.65339),
  LatLng(3.06039, 101.64959),
  LatLng(3.06235, 101.64939),
  LatLng(3.06339, 101.65109),
  LatLng(3.06617, 101.64993),
  LatLng(3.06528, 101.6481),
  LatLng(3.07034, 101.65289),
  LatLng(3.07283, 101.65246),
  LatLng(3.07484, 101.64724),
  LatLng(3.08327, 101.66047),
  LatLng(3.08776, 101.6592),
  LatLng(3.08921, 101.66334),
  LatLng(3.09362, 101.66208),
  LatLng(3.09556, 101.65865),
  LatLng(3.11301, 101.65942),
  LatLng(3.11439, 101.65796),
  LatLng(3.11719, 101.65912),
  LatLng(3.11291, 101.65176),
  LatLng(3.12061, 101.64853),
  LatLng(3.12214, 101.64274),
  LatLng(3.1279, 101.647),
  LatLng(3.1301, 101.64671),
  LatLng(3.13505, 101.63475),
  LatLng(3.13349, 101.62879),
  LatLng(3.13964, 101.62847),
  LatLng(3.14787, 101.61812),
  LatLng(3.15534, 101.61347),
  LatLng(3.18028, 101.61745),
  LatLng(3.198, 101.61786),
  LatLng(3.19964, 101.61842),
  LatLng(3.20249, 101.62439),
  LatLng(3.21138, 101.62853),
  LatLng(3.21647, 101.63363),
  LatLng(3.21995, 101.63364),
  LatLng(3.21903, 101.63617),
  LatLng(3.22258, 101.63816),
  LatLng(3.22564, 101.63895),
  LatLng(3.23125, 101.63637),
  LatLng(3.23452, 101.64032),
  LatLng(3.23544, 101.64577),
  LatLng(3.23776, 101.64651),
  LatLng(3.23705, 101.64997),
  LatLng(3.23798, 101.65347),
  LatLng(3.23959, 101.65365),
  LatLng(3.2395, 101.65676),
  LatLng(3.24396, 101.65756),
  LatLng(3.24444, 101.66044),
  LatLng(3.24626, 101.66051),
  LatLng(3.24707, 101.66445),
];

bool _isInsideKualaLumpur(double latitude, double longitude) {
  var inside = false;
  for (
    var i = 0, j = _kualaLumpurBoundary.length - 1;
    i < _kualaLumpurBoundary.length;
    j = i++
  ) {
    final current = _kualaLumpurBoundary[i];
    final previous = _kualaLumpurBoundary[j];
    final crossesLatitude =
        (current.latitude > latitude) != (previous.latitude > latitude);
    if (!crossesLatitude) continue;
    final edgeLongitude =
        (previous.longitude - current.longitude) *
            (latitude - current.latitude) /
            (previous.latitude - current.latitude) +
        current.longitude;
    if (longitude < edgeLongitude) inside = !inside;
  }
  return inside;
}

class RiskMapScreen extends StatefulWidget {
  const RiskMapScreen({super.key});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  static const _klCenter = LatLng(3.1390, 101.6869);
  static final _klBounds = LatLngBounds(
    southwest: LatLng(3.02, 101.58),
    northeast: LatLng(3.28, 101.78),
  );

  final _supabase = Supabase.instance.client;
  final _locationSearchController = TextEditingController();
  bool _searchExpanded = false;
  Timer? _locationSearchDebounce;
  Timer? _riskRefreshDebounce;
  RealtimeChannel? _riskReportsChannel;
  GoogleMapController? _mapController;
  List<_RiskReport> _validatedReports = const [];
  List<_RiskZone> _zones = const [];
  Map<_RiskLevel, BytesMapBitmap> _zoneImages = const {};
  Map<String, BitmapDescriptor> _zoneMarkerImages = const {};
  LatLng? _searchedLocation;
  BitmapDescriptor? _searchedLocationMarker;
  String? _searchedLocationLabel;
  List<_LocationSuggestion> _locationSuggestions = const [];
  _RiskLevel? _selectedRisk;
  bool _searchingLocation = false;
  bool _loadingLocationSuggestions = false;
  bool _suggestionSearchCompleted = false;
  int _suggestionRequestId = 0;
  bool _loading = true;
  bool _fetchingRisk = false;
  bool _refreshFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareZoneImages();
    _loadRiskData();
    _listenForRiskReportChanges();
  }

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _riskRefreshDebounce?.cancel();
    final riskReportsChannel = _riskReportsChannel;
    if (riskReportsChannel != null) {
      _supabase.removeChannel(riskReportsChannel);
    }
    _locationSearchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenForRiskReportChanges() {
    _riskReportsChannel = _supabase
        .channel('m300-public-risk-map')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incident_reports',
          callback: (_) {
            _riskRefreshDebounce?.cancel();
            _riskRefreshDebounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _loadRiskData(showLoading: false);
            });
          },
        )
        .subscribe();
  }

  Future<void> _searchLocation() async {
    final query = _locationSearchController.text.trim();
    if (query.isEmpty || _searchingLocation) return;
    _locationSearchDebounce?.cancel();
    _suggestionRequestId++;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchingLocation = true;
      _locationSuggestions = const [];
      _loadingLocationSuggestions = false;
      _suggestionSearchCompleted = false;
    });

    try {
      // Local results are refined with a Kuala Lumpur-qualified query.
      final matches = await _findSearchLocations(
        query,
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (matches.isEmpty) {
        _showSearchMessage('No matching location was found.');
        return;
      }

      final result = matches.first;
      final target = LatLng(result.latitude, result.longitude);
      final marker = await _createSearchMarker(query);
      if (!mounted) return;
      setState(() {
        _searchedLocation = target;
        _searchedLocationMarker = marker;
        _searchedLocationLabel = query;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15.5),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showSearchMessage(
        error.code == 'IO_ERROR'
            ? 'Location search is temporarily unavailable.'
            : 'Could not search for that location.',
      );
    } catch (_) {
      if (mounted) _showSearchMessage('Could not search for that location.');
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  void _showSearchMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearLocationSearch({
    bool clearText = true,
    bool resetCamera = true,
    bool dismissKeyboard = true,
  }) {
    _locationSearchDebounce?.cancel();
    _suggestionRequestId++;
    if (clearText) _locationSearchController.clear();
    if (dismissKeyboard) FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() {
        _searchedLocation = null;
        _searchedLocationMarker = null;
        _searchedLocationLabel = null;
        _locationSuggestions = const [];
        _loadingLocationSuggestions = false;
        _suggestionSearchCompleted = false;
      });
    }
    if (resetCamera) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(_klBounds, 28),
      );
    }
  }

  void _scheduleLocationSuggestions(String value) {
    _locationSearchDebounce?.cancel();
    final query = value.trim();
    final requestId = ++_suggestionRequestId;

    if (query.length < 2) {
      setState(() {
        _locationSuggestions = const [];
        _loadingLocationSuggestions = false;
        _suggestionSearchCompleted = false;
      });
      return;
    }

    setState(() {
      _loadingLocationSuggestions = true;
      _suggestionSearchCompleted = false;
    });
    _locationSearchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _loadLocationSuggestions(query, requestId),
    );
  }

  Future<void> _loadLocationSuggestions(String query, int requestId) async {
    try {
      final localMatches = await _findSearchLocations(
        query,
      ).timeout(const Duration(seconds: 12));
      final suggestions = <_LocationSuggestion>[];
      final seen = <String>{};

      for (final location in localMatches.take(5)) {
        String label = query;
        try {
          final placemarks = await Geocoding()
              .placemarkFromCoordinates(location.latitude, location.longitude)
              .timeout(const Duration(seconds: 2));
          if (placemarks.isNotEmpty) {
            final address = _formatPlacemark(placemarks.first, fallback: query);
            label = address.toLowerCase().contains(query.toLowerCase())
                ? address
                : '$query, $address';
          }
        } catch (_) {
          // The coordinates are still useful if reverse geocoding is
          // unavailable for a particular result.
        }
        final key = label.toLowerCase();
        if (seen.add(key)) {
          suggestions.add(
            _LocationSuggestion(
              label: label,
              position: LatLng(location.latitude, location.longitude),
            ),
          );
        }
      }

      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _locationSuggestions = suggestions;
        _loadingLocationSuggestions = false;
        _suggestionSearchCompleted = true;
      });
    } catch (_) {
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _locationSuggestions = const [];
        _loadingLocationSuggestions = false;
        _suggestionSearchCompleted = true;
      });
    }
  }

  Future<List<Location>> _findSearchLocations(String query) async {
    final geocoder = Geocoding();
    final rawMatches = await geocoder.locationFromAddress(query);
    final rawLocal = rawMatches
        .where(
          (location) =>
              _isInsideKualaLumpur(location.latitude, location.longitude),
        )
        .toList();

    final alreadyQualified = query.toLowerCase().contains('kuala lumpur');
    final qualifiedMatches = alreadyQualified || rawLocal.isEmpty
        ? const <Location>[]
        : await geocoder.locationFromAddress('$query, Kuala Lumpur, Malaysia');
    final ordered = [...qualifiedMatches, ...rawMatches];
    final results = <Location>[];
    final seen = <String>{};
    for (final location in ordered) {
      final key =
          '${location.latitude.toStringAsFixed(5)},'
          '${location.longitude.toStringAsFixed(5)}';
      if (seen.add(key)) results.add(location);
    }
    return results;
  }

  String _formatPlacemark(Placemark placemark, {required String fallback}) {
    final values = [
      placemark.name,
      placemark.street,
      placemark.subLocality,
      placemark.locality,
      placemark.postalCode,
    ];
    final parts = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final part = value?.trim() ?? '';
      if (part.isNotEmpty && seen.add(part.toLowerCase())) parts.add(part);
    }
    return parts.isEmpty ? fallback : parts.join(', ');
  }

  Future<void> _selectLocationSuggestion(_LocationSuggestion suggestion) async {
    _locationSearchDebounce?.cancel();
    _suggestionRequestId++;
    _locationSearchController.text = suggestion.label;
    FocusManager.instance.primaryFocus?.unfocus();
    final marker = await _createSearchMarker(suggestion.shortLabel);
    if (!mounted) return;
    setState(() {
      _searchedLocation = suggestion.position;
      _searchedLocationMarker = marker;
      _searchedLocationLabel = suggestion.label;
      _locationSuggestions = const [];
      _loadingLocationSuggestions = false;
      _suggestionSearchCompleted = false;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: suggestion.position, zoom: 15.5),
      ),
    );
  }

  Future<void> _prepareZoneImages() async {
    final entries = await Future.wait(
      _RiskLevel.values.map((risk) async {
        return MapEntry(risk, await _createZoneImage(risk.color));
      }),
    );
    if (!mounted) return;
    setState(() => _zoneImages = Map.fromEntries(entries));
  }

  Future<BytesMapBitmap> _createZoneImage(Color color) async {
    const size = 192;
    const center = Offset(size / 2, size / 2);
    const radius = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: 0.78),
          color.withValues(alpha: 0.48),
          color.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        const [0, 0.28, 0.7, 1],
      );
    canvas.drawCircle(center, radius, paint);
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Could not create risk-zone image.');
    }
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      bitmapScaling: MapBitmapScaling.none,
    );
  }

  Future<void> _loadRiskData({bool showLoading = true}) async {
    if (_fetchingRisk) return;
    _fetchingRisk = true;
    if (mounted && showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Only non-sensitive fields required for the public risk view are read.
      final data = await _supabase
          .from('incident_reports')
          .select(
            'id,ticket_id,category,location,address,latitude,longitude,'
            'urgency_level,status,created_at',
          )
          .eq('status', 'Validated')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      final reports = List<Map<String, dynamic>>.from(
        data,
      ).map(_RiskReport.fromJson).toList(growable: false);
      final zones = _buildZones(reports.where((report) => report.isInKl));
      final markerEntries = await Future.wait(
        zones.map((zone) async {
          return MapEntry(zone.id, await _createZoneMarker(zone));
        }),
      );

      if (!mounted) return;
      setState(() {
        _error = null;
        _refreshFailed = false;
        _validatedReports = reports;
        _zones = zones;
        _zoneMarkerImages = Map.fromEntries(markerEntries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _error =
              'Could not reach the service. Check Wi-Fi or mobile data and try again.';
          _loading = false;
        });
      }
      if (!showLoading) setState(() => _refreshFailed = true);
    } finally {
      _fetchingRisk = false;
    }
  }

  List<_RiskZone> _buildZones(Iterable<_RiskReport> reports) {
    final groups = <String, List<_RiskReport>>{};
    for (final report in reports) {
      final key =
          '${report.latitude!.toStringAsFixed(5)},${report.longitude!.toStringAsFixed(5)}';
      groups.putIfAbsent(key, () => []).add(report);
    }

    return groups.values
        .map((group) {
          final count = group.length;
          final risk = count >= 10
              ? _RiskLevel.red
              : count >= 5
              ? _RiskLevel.orange
              : _RiskLevel.yellow;
          final first = group.first;
          return _RiskZone(
            id: first.id,
            name: first.location.isEmpty ? 'Pinned location' : first.location,
            position: LatLng(first.latitude!, first.longitude!),
            count: count,
            risk: risk,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  List<_RiskZone> get _visibleZones => _selectedRisk == null
      ? _zones
      : _zones.where((zone) => zone.risk == _selectedRisk).toList();

  int get _insideKlCount =>
      _validatedReports.where((report) => report.isInKl).length;

  int get _outsideKlCount =>
      _validatedReports.where((report) => report.isOutsideKl).length;

  int _reportCountFor(_RiskLevel level) => _zones
      .where((zone) => zone.risk == level)
      .fold(0, (total, zone) => total + zone.count);

  Set<GroundOverlay> _buildZoneOverlays() {
    return _visibleZones
        .map((zone) {
          final image = _zoneImages[zone.risk];
          if (image == null) return null;

          // Start at 300 m and add 75 m for each repeated report at the same
          // pin. The cap prevents dense zones from covering most of the city.
          final radiusMeters = (300 + ((zone.count - 1) * 75)).clamp(300, 1200);
          final diameterMeters = radiusMeters * 2.0;
          return GroundOverlay.fromPosition(
            groundOverlayId: GroundOverlayId('risk-zone-${zone.id}'),
            image: image,
            position: zone.position,
            width: diameterMeters,
            height: diameterMeters,
            clickable: false,
            zIndex: 1,
          );
        })
        .whereType<GroundOverlay>()
        .toSet();
  }

  Set<Marker> _buildMarkers() {
    final markers = _visibleZones.map((zone) {
      return Marker(
        markerId: MarkerId('risk-marker-${zone.id}'),
        position: zone.position,
        icon:
            _zoneMarkerImages[zone.id] ??
            BitmapDescriptor.defaultMarkerWithHue(zone.risk.markerHue),
        anchor: const Offset(0.5, 1),
        infoWindow: InfoWindow(
          title: '${zone.name} · ${zone.risk.label} zone',
          snippet:
              '${zone.count} validated report${zone.count == 1 ? '' : 's'}',
        ),
      );
    }).toSet();

    final searchedLocation = _searchedLocation;
    if (searchedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('searched-location'),
          position: searchedLocation,
          icon:
              _searchedLocationMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.8625),
          zIndexInt: 10,
          infoWindow: InfoWindow(
            title: _searchedLocationLabel ?? 'Searched location',
          ),
        ),
      );
    }
    return markers;
  }

  Future<BitmapDescriptor> _createZoneMarker(_RiskZone zone) async {
    const width = 88;
    const height = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // A compact count badge with a precise anchor, not a stock map pin.
    final pointer = Path()
      ..moveTo(34, 73)
      ..lineTo(44, 92)
      ..lineTo(54, 73)
      ..close();
    canvas.drawPath(pointer, Paint()..color = zone.risk.color);
    canvas.drawCircle(const Offset(44, 42), 38, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(44, 42),
      33,
      Paint()..color = zone.risk.color,
    );
    final ink = zone.risk == _RiskLevel.yellow
        ? const Color(0xFF422006)
        : Colors.white;
    final count = TextPainter(
      text: TextSpan(
        text: '${zone.count}',
        style: TextStyle(
          color: ink,
          fontSize: zone.count > 999 ? 19 : 27,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 62);
    count.paint(canvas, Offset(44 - count.width / 2, 18));
    final caption = TextPainter(
      text: TextSpan(
        text: zone.count == 1 ? 'REPORT' : 'REPORTS',
        style: TextStyle(
          color: ink,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    caption.paint(canvas, Offset(44 - caption.width / 2, 51));
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not create zone marker.');
    return BytesMapBitmap(
      bytes.buffer.asUint8List(),
      bitmapScaling: MapBitmapScaling.auto,
      width: 64,
    );
  }

  Future<BitmapDescriptor> _createSearchMarker(String query) async {
    final label = TextPainter(
      text: TextSpan(
        text: query,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 190);
    final width = (label.width + 40).ceil();
    const height = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, width - 4, 42),
      const Radius.circular(14),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF243C91));
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    label.paint(
      canvas,
      Offset((width - label.width) / 2, 23 - label.height / 2),
    );
    canvas.drawLine(
      Offset(width / 2, 44),
      Offset(width / 2, 67),
      Paint()
        ..color = const Color(0xFF243C91)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(Offset(width / 2, 69), 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(width / 2, 69),
      6,
      Paint()..color = const Color(0xFF243C91),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not create search marker.');
    return BytesMapBitmap(
      bytes.buffer.asUint8List(),
      bitmapScaling: MapBitmapScaling.auto,
      width: width.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: _buildHeader(),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                )
              : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildErrorCard(),
                )
              : _buildMapExperience(),
        ),
      ],
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF243C91), Color(0xFF365AB0)],
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_outlined, size: 23, color: Colors.white),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KUALA LUMPUR ONLY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Zones show validated incident reports.',
                style: TextStyle(color: Color(0xFFE2E8FF), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Inside KL',
                '$_insideKlCount',
                Icons.location_city_outlined,
                const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Out of zone',
                '$_outsideKlCount',
                Icons.wrong_location_outlined,
                const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only validated reports inside the Kuala Lumpur boundary are shown as risk zones.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBreakdown() {
    final yellow = _reportCountFor(_RiskLevel.yellow);
    final orange = _reportCountFor(_RiskLevel.orange);
    final red = _reportCountFor(_RiskLevel.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validated report distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          AdaptivePair(
            first: SizedBox.square(
              dimension: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(112),
                    painter: _RiskDonutPainter(
                      yellow: yellow,
                      orange: orange,
                      red: red,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_insideKlCount',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'IN KL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            second: Column(
              children: [
                _legendRow(_RiskLevel.red, red, '10+ per zone'),
                _legendRow(_RiskLevel.orange, orange, '5–9 per zone'),
                _legendRow(_RiskLevel.yellow, yellow, '1–4 per zone'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(_RiskLevel risk, int reports, String range) {
    final zoneCount = _zones.where((zone) => zone.risk == risk).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: risk.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${risk.label} · $reports reports',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '$zoneCount zones · $range',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapExperience() {
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _klCenter,
              zoom: 11.2,
            ),
            onMapCreated: (controller) => _mapController = controller,
            minMaxZoomPreference: const MinMaxZoomPreference(2, 19),
            markers: _buildMarkers(),
            groundOverlays: _buildZoneOverlays(),
            polygons: {
              Polygon(
                polygonId: const PolygonId('kuala-lumpur-boundary'),
                points: _kualaLumpurBoundary,
                fillColor: const Color(0xFFDC2626).withValues(alpha: 0.018),
                strokeColor: const Color(0xFFDC2626).withValues(alpha: 0.72),
                strokeWidth: 2,
              ),
            },
            padding: const EdgeInsets.only(bottom: 72),
            compassEnabled: true,
            zoomControlsEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          child: child,
                        ),
                      ),
                      child: _searchExpanded
                          ? _buildLocationSearch()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF243C91),
                                  ),
                                  onPressed: () =>
                                      setState(() => _searchExpanded = true),
                                  icon: const Icon(Icons.search_rounded),
                                  label: const Text('Find a place'),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildMapFilters(),
              if (_searchExpanded) _buildLocationSuggestions(),
            ],
          ),
        ),
        Positioned(right: 10, bottom: 78, child: _buildMapButtons()),
        if (_refreshFailed)
          Positioned(
            left: 12,
            right: 12,
            bottom: 70,
            child: Material(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: const Text('Could not refresh · showing earlier data'),
                trailing: IconButton(
                  tooltip: 'Retry refresh',
                  onPressed: () => _loadRiskData(showLoading: false),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF243C91),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              onPressed: _showInsights,
              icon: const Icon(Icons.insights_rounded, size: 20),
              label: Text('Insights · $_insideKlCount reports in KL'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapFilters() {
    return SizedBox(
      height: 48,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterChip('All', null),
              ..._RiskLevel.values.map(
                (risk) => _filterChip(
                  '${risk.label} ${switch (risk) {
                    _RiskLevel.yellow => '1–4',
                    _RiskLevel.orange => '5–9',
                    _RiskLevel.red => '10+',
                  }}',
                  risk,
                ),
              ),
              _buildBoundaryLabel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSearch() {
    final query = _locationSearchController.text.trim();

    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 50,
        child: TextField(
          controller: _locationSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchLocation(),
          onChanged: (value) {
            final changedFromResult =
                _searchedLocation != null &&
                _searchedLocationLabel?.toLowerCase() !=
                    value.trim().toLowerCase();
            if (value.trim().isEmpty) {
              _clearLocationSearch(clearText: false);
            } else if (changedFromResult) {
              _clearLocationSearch(
                clearText: false,
                resetCamera: false,
                dismissKeyboard: false,
              );
            }
            _scheduleLocationSuggestions(value);
          },
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Search a place or address',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            prefixIcon: IconButton(
              tooltip: 'Close search',
              onPressed: () {
                FocusScope.of(context).unfocus();
                _clearLocationSearch();
                setState(() => _searchExpanded = false);
              },
              icon: const Icon(Icons.close_rounded, color: Color(0xFF243C91)),
            ),
            suffixIcon: _searchingLocation
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Search location',
                    onPressed: query.isEmpty ? null : _searchLocation,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF243C91),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSuggestions() {
    final query = _locationSearchController.text.trim();
    final shouldShow =
        query.length >= 2 &&
        (_loadingLocationSuggestions ||
            _locationSuggestions.isNotEmpty ||
            _suggestionSearchCompleted);
    if (!shouldShow) return const SizedBox.shrink();

    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 265),
        child: _loadingLocationSuggestions
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 13),
                    Text(
                      'Searching locations…',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              )
            : _locationSuggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 17, vertical: 15),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 21,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No matching location found',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 5),
                shrinkWrap: true,
                itemCount: _locationSuggestions.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 56,
                  color: Color(0xFFE2E8F0),
                ),
                itemBuilder: (context, index) {
                  final suggestion = _locationSuggestions[index];
                  return InkWell(
                    onTap: () => _selectLocationSuggestion(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEFF6FF),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 19,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.shortLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (suggestion.details.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    suggestion.details,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.25,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.north_west_rounded,
                            size: 17,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBoundaryLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Material(
        color: Colors.white.withValues(alpha: 0.76),
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                child: Divider(color: Color(0xFFDC2626), thickness: 2),
              ),
              SizedBox(width: 4),
              Text(
                'KL boundary',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapButtons() {
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: const Color(0xFF334155)),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Icons.add_rounded,
            'Zoom in',
            () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
          ),
          const SizedBox(width: 30, child: Divider(height: 1)),
          button(
            Icons.remove_rounded,
            'Zoom out',
            () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
          ),
          const SizedBox(width: 30, child: Divider(height: 1)),
          button(
            Icons.center_focus_strong_rounded,
            'Reset map',
            () => _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(_klBounds, 28),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInsights() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Community risk insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Swipe down to return to the map',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _metricCard(
                'Total validated reports',
                '${_validatedReports.length}',
                Icons.verified_outlined,
                const Color(0xFF243C91),
              ),
              const SizedBox(height: 12),
              _buildSummaryGrid(),
              const SizedBox(height: 14),
              _buildRiskBreakdown(),
              const SizedBox(height: 12),
              const Text(
                'Numbers on the map show validated reports per zone, not a prediction of danger.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, _RiskLevel? risk) {
    final selected = _selectedRisk == risk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: ChoiceChip(
        avatar: selected
            ? Icon(
                Icons.check_rounded,
                size: 15,
                color: risk == _RiskLevel.yellow
                    ? const Color(0xFF422006)
                    : Colors.white,
              )
            : null,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: Colors.white.withValues(alpha: 0.76),
        selectedColor: (risk?.color ?? const Color(0xFF1E3A8A)).withValues(
          alpha: 0.84,
        ),
        elevation: 0,
        pressElevation: 6,
        shadowColor: Colors.black26,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        visualDensity: VisualDensity.compact,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.82),
          ),
        ),
        labelStyle: TextStyle(
          color: selected && risk == _RiskLevel.yellow
              ? const Color(0xFF422006)
              : selected
              ? Colors.white
              : const Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _selectedRisk = risk),
      ),
    );
  }

  Widget _buildErrorCard() => LoadFailureCard(onRetry: _loadRiskData);
}

class _LocationSuggestion {
  final String label;
  final LatLng position;

  const _LocationSuggestion({required this.label, required this.position});

  String get shortLabel => label.split(',').first.trim();

  String get details {
    final separator = label.indexOf(',');
    return separator == -1 ? '' : label.substring(separator + 1).trim();
  }
}

class _RiskReport {
  final String id;
  final String location;
  final double? latitude;
  final double? longitude;

  const _RiskReport({
    required this.id,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  factory _RiskReport.fromJson(Map<String, dynamic> json) {
    return _RiskReport(
      id: json['id'] as String? ?? '',
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isInKl =>
      hasCoordinates && _isInsideKualaLumpur(latitude!, longitude!);

  bool get isOutsideKl => hasCoordinates && !isInKl;
}

class _RiskZone {
  final String id;
  final String name;
  final LatLng position;
  final int count;
  final _RiskLevel risk;

  const _RiskZone({
    required this.id,
    required this.name,
    required this.position,
    required this.count,
    required this.risk,
  });
}

class _RiskDonutPainter extends CustomPainter {
  final int yellow;
  final int orange;
  final int red;

  const _RiskDonutPainter({
    required this.yellow,
    required this.orange,
    required this.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = yellow + orange + red;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      paint.color = const Color(0xFFE2E8F0);
      canvas.drawArc(rect.deflate(10), 0, math.pi * 2, false, paint);
      return;
    }

    var start = -math.pi / 2;
    for (final segment in [
      (value: yellow, color: _RiskLevel.yellow.color),
      (value: orange, color: _RiskLevel.orange.color),
      (value: red, color: _RiskLevel.red.color),
    ]) {
      if (segment.value == 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      paint.color = segment.color;
      canvas.drawArc(rect.deflate(10), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RiskDonutPainter oldDelegate) =>
      yellow != oldDelegate.yellow ||
      orange != oldDelegate.orange ||
      red != oldDelegate.red;
}
