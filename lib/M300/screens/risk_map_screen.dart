import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  double get radiusMeters => switch (this) {
    _RiskLevel.yellow => 150,
    _RiskLevel.orange => 300,
    _RiskLevel.red => 500,
  };
}

// W.P. Kuala Lumpur. Kept locally so displaying the boundary
const _kualaLumpurBoundary = <LatLng>[
  LatLng(3.24432, 101.66725), LatLng(3.23577, 101.67329),
  LatLng(3.23086, 101.6723), LatLng(3.23134, 101.69724),
  LatLng(3.22639, 101.69736), LatLng(3.2266, 101.7021),
  LatLng(3.21977, 101.70265), LatLng(3.21826, 101.70899),
  LatLng(3.21927, 101.71045), LatLng(3.21596, 101.71488),
  LatLng(3.21843, 101.71758), LatLng(3.21769, 101.71528),
  LatLng(3.22113, 101.71596), LatLng(3.22128, 101.71855),
  LatLng(3.22435, 101.71872), LatLng(3.23023, 101.72403),
  LatLng(3.23217, 101.72416), LatLng(3.2314, 101.72502),
  LatLng(3.23641, 101.73033), LatLng(3.23485, 101.73219),
  LatLng(3.23527, 101.73941), LatLng(3.23664, 101.73981),
  LatLng(3.23145, 101.74373), LatLng(3.22587, 101.73951),
  LatLng(3.21878, 101.7384), LatLng(3.21746, 101.74158),
  LatLng(3.21243, 101.74585), LatLng(3.20601, 101.74748),
  LatLng(3.20575, 101.75045), LatLng(3.20345, 101.75106),
  LatLng(3.20359, 101.7538), LatLng(3.19969, 101.75657),
  LatLng(3.19142, 101.75872), LatLng(3.18837, 101.75785),
  LatLng(3.18803, 101.75545), LatLng(3.18747, 101.75676),
  LatLng(3.18322, 101.75532), LatLng(3.17876, 101.74859),
  LatLng(3.18123, 101.73274), LatLng(3.17979, 101.73359),
  LatLng(3.17608, 101.73182), LatLng(3.17545, 101.73473),
  LatLng(3.16784, 101.73457), LatLng(3.16775, 101.73904),
  LatLng(3.16554, 101.73924), LatLng(3.16406, 101.75058),
  LatLng(3.16159, 101.74819), LatLng(3.16079, 101.74999),
  LatLng(3.15646, 101.74679), LatLng(3.1526, 101.74639),
  LatLng(3.15359, 101.74043), LatLng(3.15106, 101.74115),
  LatLng(3.14746, 101.73856), LatLng(3.14645, 101.74003),
  LatLng(3.13988, 101.73538), LatLng(3.12716, 101.74084),
  LatLng(3.12193, 101.7393), LatLng(3.12049, 101.73742),
  LatLng(3.11636, 101.73804), LatLng(3.11274, 101.74126),
  LatLng(3.11262, 101.74383), LatLng(3.11436, 101.74447),
  LatLng(3.1137, 101.74736), LatLng(3.11286, 101.74678),
  LatLng(3.11023, 101.75184), LatLng(3.10748, 101.75368),
  LatLng(3.10421, 101.75045), LatLng(3.09993, 101.75232),
  LatLng(3.09509, 101.75104), LatLng(3.08908, 101.74507),
  LatLng(3.08516, 101.746), LatLng(3.08424, 101.74491),
  LatLng(3.07899, 101.74823), LatLng(3.0573, 101.74838),
  LatLng(3.05697, 101.73075), LatLng(3.03872, 101.731),
  LatLng(3.0409, 101.72938), LatLng(3.03708, 101.72284),
  LatLng(3.03998, 101.72269), LatLng(3.04012, 101.72442),
  LatLng(3.04231, 101.72459), LatLng(3.0443, 101.72163),
  LatLng(3.05096, 101.72014), LatLng(3.05048, 101.71663),
  LatLng(3.05346, 101.7174), LatLng(3.05307, 101.71609),
  LatLng(3.05742, 101.71545), LatLng(3.05778, 101.71372),
  LatLng(3.05761, 101.71166), LatLng(3.05109, 101.70864),
  LatLng(3.05107, 101.7073), LatLng(3.05299, 101.7073),
  LatLng(3.05277, 101.70254), LatLng(3.05207, 101.69986),
  LatLng(3.04913, 101.69949), LatLng(3.04886, 101.69347),
  LatLng(3.04712, 101.69157), LatLng(3.04906, 101.68672),
  LatLng(3.04516, 101.67926), LatLng(3.04601, 101.67203),
  LatLng(3.04489, 101.66979), LatLng(3.04952, 101.66975),
  LatLng(3.04972, 101.65262), LatLng(3.05426, 101.65468),
  LatLng(3.05279, 101.66073), LatLng(3.06218, 101.66073),
  LatLng(3.0606, 101.65451), LatLng(3.06239, 101.65339),
  LatLng(3.06039, 101.64959), LatLng(3.06235, 101.64939),
  LatLng(3.06339, 101.65109), LatLng(3.06617, 101.64993),
  LatLng(3.06528, 101.6481), LatLng(3.07034, 101.65289),
  LatLng(3.07283, 101.65246), LatLng(3.07484, 101.64724),
  LatLng(3.08327, 101.66047), LatLng(3.08776, 101.6592),
  LatLng(3.08921, 101.66334), LatLng(3.09362, 101.66208),
  LatLng(3.09556, 101.65865), LatLng(3.11301, 101.65942),
  LatLng(3.11439, 101.65796), LatLng(3.11719, 101.65912),
  LatLng(3.11291, 101.65176), LatLng(3.12061, 101.64853),
  LatLng(3.12214, 101.64274), LatLng(3.1279, 101.647),
  LatLng(3.1301, 101.64671), LatLng(3.13505, 101.63475),
  LatLng(3.13349, 101.62879), LatLng(3.13964, 101.62847),
  LatLng(3.14787, 101.61812), LatLng(3.15534, 101.61347),
  LatLng(3.18028, 101.61745), LatLng(3.198, 101.61786),
  LatLng(3.19964, 101.61842), LatLng(3.20249, 101.62439),
  LatLng(3.21138, 101.62853), LatLng(3.21647, 101.63363),
  LatLng(3.21995, 101.63364), LatLng(3.21903, 101.63617),
  LatLng(3.22258, 101.63816), LatLng(3.22564, 101.63895),
  LatLng(3.23125, 101.63637), LatLng(3.23452, 101.64032),
  LatLng(3.23544, 101.64577), LatLng(3.23776, 101.64651),
  LatLng(3.23705, 101.64997), LatLng(3.23798, 101.65347),
  LatLng(3.23959, 101.65365), LatLng(3.2395, 101.65676),
  LatLng(3.24396, 101.65756), LatLng(3.24444, 101.66044),
  LatLng(3.24626, 101.66051), LatLng(3.24707, 101.66445),
];

bool _isInsideKualaLumpur(double latitude, double longitude) {
  var inside = false;
  for (var i = 0, j = _kualaLumpurBoundary.length - 1;
      i < _kualaLumpurBoundary.length;
      j = i++) {
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
  GoogleMapController? _mapController;
  List<_RiskReport> _validatedReports = const [];
  List<_RiskZone> _zones = const [];
  _RiskLevel? _selectedRisk;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRiskData();
  }

  Future<void> _loadRiskData() async {
    if (mounted) {
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
          .order('created_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(
        data,
      ).map(_RiskReport.fromJson).toList(growable: false);
      final zones = _buildZones(reports.where((report) => report.isInKl));

      if (!mounted) return;
      setState(() {
        _validatedReports = reports;
        _zones = zones;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load validated risk data. Pull down to retry.';
        _loading = false;
      });
      debugPrint('Risk map load error: $error');
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

  Set<Circle> _buildCircles() => _visibleZones.map((zone) {
    return Circle(
      circleId: CircleId('risk-circle-${zone.id}'),
      center: zone.position,
      radius: zone.risk.radiusMeters,
      strokeColor: zone.risk.color,
      strokeWidth: 2,
      fillColor: zone.risk.color.withValues(alpha: 0.22),
    );
  }).toSet();

  Set<Marker> _buildMarkers() => _visibleZones.map((zone) {
    return Marker(
      markerId: MarkerId('risk-marker-${zone.id}'),
      position: zone.position,
      icon: BitmapDescriptor.defaultMarkerWithHue(zone.risk.markerHue),
      infoWindow: InfoWindow(
        title: '${zone.name} · ${zone.risk.label} zone',
        snippet: '${zone.count} validated report${zone.count == 1 ? '' : 's'}',
      ),
    );
  }).toSet();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRiskData,
      color: const Color(0xFF1E3A8A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          if (_error != null)
            _buildErrorCard()
          else ...[
            _buildSummaryGrid(),
            const SizedBox(height: 14),
            _buildRiskBreakdown(),
            const SizedBox(height: 14),
            _buildMapCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.map_outlined, color: Color(0xFF1E3A8A)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kuala Lumpur Risk Map',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Community safety patterns from validated reports only.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'VALIDATED',
            style: TextStyle(
              color: Color(0xFF15803D),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        _metricCard(
          'Total validated reports',
          '${_validatedReports.length}',
          Icons.verified_outlined,
          const Color(0xFF1E3A8A),
          wide: true,
        ),
        const SizedBox(height: 10),
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

  Widget _metricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool wide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          if (wide)
            const Icon(Icons.trending_up_rounded, color: Color(0xFF94A3B8)),
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
          Row(
            children: [
              SizedBox.square(
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
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _legendRow(_RiskLevel.red, red, '10+ per zone'),
                    _legendRow(_RiskLevel.orange, orange, '5–9 per zone'),
                    _legendRow(_RiskLevel.yellow, yellow, '1–4 per zone'),
                  ],
                ),
              ),
            ],
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

  Widget _buildMapCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_outlined,
                  size: 18,
                  color: Color(0xFF1E3A8A),
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Interactive risk zones',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Reset map',
                  onPressed: () => _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(_klBounds, 28),
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 330,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _klCenter,
                zoom: 11.2,
              ),
              onMapCreated: (controller) => _mapController = controller,
              cameraTargetBounds: CameraTargetBounds(_klBounds),
              minMaxZoomPreference: const MinMaxZoomPreference(10.5, 19),
              markers: _buildMarkers(),
              circles: _buildCircles(),
              polygons: {
                Polygon(
                  polygonId: const PolygonId('kuala-lumpur-boundary'),
                  points: _kualaLumpurBoundary,
                  fillColor: const Color(0xFFDC2626).withValues(alpha: 0.025),
                  strokeColor: const Color(0xFFDC2626).withValues(alpha: 0.78),
                  strokeWidth: 2,
                ),
              },
              compassEnabled: true,
              zoomControlsEnabled: true,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              children: [
                _filterChip('All', null),
                ..._RiskLevel.values.map(
                  (risk) => _filterChip(risk.label, risk),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 11),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Divider(color: Color(0xFFDC2626), thickness: 2),
                ),
                SizedBox(width: 7),
                Text(
                  'Kuala Lumpur administrative boundary',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _RiskLevel? risk) {
    final selected = _selectedRisk == risk;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: risk?.color ?? const Color(0xFF1E3A8A),
        labelStyle: TextStyle(
          color: selected && risk == _RiskLevel.yellow
              ? const Color(0xFF422006)
              : selected
              ? Colors.white
              : const Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) => setState(() => _selectedRisk = risk),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626)),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
          ),
          TextButton(onPressed: _loadRiskData, child: const Text('Try Again')),
        ],
      ),
    );
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
