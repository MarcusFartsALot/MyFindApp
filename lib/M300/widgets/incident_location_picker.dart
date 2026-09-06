import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class IncidentLocationPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  final bool hasInitialPin;
  final bool myLocationEnabled;

  const IncidentLocationPickerPage({
    super.key,
    required this.initialLocation,
    required this.hasInitialPin,
    required this.myLocationEnabled,
  });

  @override
  State<IncidentLocationPickerPage> createState() =>
      _IncidentLocationPickerPageState();
}

class _IncidentLocationPickerPageState
    extends State<IncidentLocationPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final Geocoding _geocoding = Geocoding();

  GoogleMapController? _mapController;
  late LatLng _pickedLocation;
  late bool _hasPin;
  bool _searching = false;
  bool _closing = false;
  int _searchGeneration = 0;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _hasPin = widget.hasInitialPin;
  }

  @override
  void dispose() {
    _closing = true;
    _searchGeneration++;
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool _canApplySearchResult(int generation) {
    return mounted && !_closing && generation == _searchGeneration;
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching || _closing) return;

    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final matches = await _geocoding.locationFromAddress(query);
      if (!_canApplySearchResult(generation)) return;

      if (matches.isEmpty) {
        setState(() => _searchError = 'No matching location found.');
        return;
      }

      final result = matches.first;
      final location = LatLng(result.latitude, result.longitude);
      setState(() {
        _pickedLocation = location;
        _hasPin = true;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 16),
        ),
      );
    } on PlatformException catch (error) {
      if (!_canApplySearchResult(generation)) return;
      setState(() {
        _searchError = error.code == 'IO_ERROR'
            ? 'Location search is temporarily unavailable. You can still tap the map.'
            : 'Could not search for that location.';
      });
    } catch (_) {
      if (!_canApplySearchResult(generation)) return;
      setState(() => _searchError = 'Could not search for that location.');
    } finally {
      if (_canApplySearchResult(generation)) {
        setState(() => _searching = false);
      }
    }
  }

  void _finish([LatLng? result]) {
    if (_closing) return;
    _closing = true;
    _searchGeneration++;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Incident location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
          onPressed: _finish,
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              if (_closing || !mounted) {
                controller.dispose();
                return;
              }
              _mapController = controller;
            },
            onTap: (point) {
              if (_closing) return;
              _searchGeneration++;
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _searching = false;
                _pickedLocation = point;
                _hasPin = true;
                _searchError = null;
              });
            },
            markers: _hasPin
                ? {
                    Marker(
                      markerId: const MarkerId('incident-location-picker'),
                      position: _pickedLocation,
                      draggable: true,
                      onDragEnd: (point) {
                        _searchGeneration++;
                        setState(() {
                          _pickedLocation = point;
                          _searching = false;
                          _searchError = null;
                        });
                      },
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  }
                : const <Marker>{},
            compassEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: widget.myLocationEnabled,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 86, bottom: 180),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    _searchGeneration++;
                    setState(() {
                      _searching = false;
                      _searchError = null;
                    });
                  },
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchLocation(),
                  decoration: InputDecoration(
                    hintText: 'Search address or landmark',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF1E3A8A),
                    ),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Search location',
                            onPressed: _searchLocation,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          if (_searchError != null)
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
                    _searchError!,
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        Expanded(
                          child: Text(
                            'Tap map to update pin position',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasPin
                          ? '${_pickedLocation.latitude.toStringAsFixed(5)}, ${_pickedLocation.longitude.toStringAsFixed(5)}\nCheck the pin marks where the incident happened.'
                          : 'Search for a place or tap the map to select a pin.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _hasPin && !_searching
                            ? () => _finish(_pickedLocation)
                            : null,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Confirm location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
