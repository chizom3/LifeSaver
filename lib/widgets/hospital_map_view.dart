import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../hospital.dart';
import '../services/maps_script_loader.dart';

class HospitalMapView extends StatefulWidget {
  final List<Hospital> hospitals;
  final LatLng? currentLocation;
  final String? selectedHospitalId;
  final bool hasLocationPermission;
  final BitmapDescriptor? hospitalIcon;
  final String Function(Hospital hospital) hospitalId;
  final bool Function(Hospital hospital) isFavorite;
  final ValueChanged<Hospital> onHospitalSelected;
  final VoidCallback onLocationRefreshRequested;
  final ValueChanged<String> onMessage;

  const HospitalMapView({
    super.key,
    required this.hospitals,
    required this.currentLocation,
    required this.selectedHospitalId,
    required this.hasLocationPermission,
    required this.hospitalIcon,
    required this.hospitalId,
    required this.isFavorite,
    required this.onHospitalSelected,
    required this.onLocationRefreshRequested,
    required this.onMessage,
  });

  @override
  State<HospitalMapView> createState() => _HospitalMapViewState();
}

class _HospitalMapViewState extends State<HospitalMapView> {
  GoogleMapController? _controller;
  double _mapZoom = 12;
  LatLng? _lastAnimatedLocation;
  // On web the Maps script is fetched only once this tab is opened.
  Future<void> _mapsReady = ensureMapsScriptLoaded();

  @override
  void didUpdateWidget(covariant HospitalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = widget.currentLocation;
    if (location == null || _controller == null) return;
    if (_lastAnimatedLocation?.latitude == location.latitude &&
        _lastAnimatedLocation?.longitude == location.longitude) {
      return;
    }

    _lastAnimatedLocation = location;
    _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _mapsReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildLoadError();
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildMap();
      },
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "The map couldn't load. Check your connection; the hospital "
              'list still works without it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              onPressed: () {
                setState(() => _mapsReady = ensureMapsScriptLoaded());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(6.5244, 3.3792),
            zoom: 12,
          ),
          markers: _buildMarkers(),
          myLocationEnabled: widget.hasLocationPermission,
          myLocationButtonEnabled: widget.hasLocationPermission,
          onMapCreated: (controller) {
            _controller = controller;
            widget.onLocationRefreshRequested();
          },
          onCameraMove: (position) {
            _mapZoom = position.zoom;
          },
          onCameraIdle: () {
            if (mounted) setState(() {});
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'fit_results',
            tooltip: 'Fit map to results',
            onPressed: _fitMapToResults,
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    final hospitalMarkers = _clusterHospitals(
      widget.hospitals
          .where(_hasCoordinates)
          .take(250)
          .toList(),
    ).map(_buildHospitalOrClusterMarker);

    final userLocation = widget.currentLocation;
    if (userLocation == null) return hospitalMarkers.toSet();

    return {
      ...hospitalMarkers,
      Marker(
        markerId: const MarkerId('me'),
        position: userLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
  }

  Marker _buildHospitalOrClusterMarker(_HospitalCluster cluster) {
    if (cluster.hospitals.length > 1) {
      return Marker(
        markerId: MarkerId('cluster_${cluster.id}'),
        position: cluster.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: '${cluster.hospitals.length} facilities nearby',
          snippet: 'Zoom in or narrow filters',
        ),
        onTap: () {
          _controller?.animateCamera(
            CameraUpdate.newLatLngZoom(cluster.location, _mapZoom + 2),
          );
        },
      );
    }

    final hospital = cluster.hospitals.first;
    final hospitalId = widget.hospitalId(hospital);
    final isFavorite = widget.isFavorite(hospital);
    final isSelected = hospitalId == widget.selectedHospitalId;

    return Marker(
      markerId: MarkerId(hospitalId),
      position: LatLng(hospital.latitude, hospital.longitude),
      icon: isSelected
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
          : isFavorite
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow)
          : (widget.hospitalIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      onTap: () => widget.onHospitalSelected(hospital),
    );
  }

  List<_HospitalCluster> _clusterHospitals(List<Hospital> hospitals) {
    if (_mapZoom >= 14) {
      return hospitals.map((hospital) {
        return _HospitalCluster(
          id: widget.hospitalId(hospital),
          hospitals: [hospital],
          location: LatLng(hospital.latitude, hospital.longitude),
        );
      }).toList();
    }

    final bucketSize = _clusterBucketSizeDegrees();
    final buckets = <String, List<Hospital>>{};

    for (final hospital in hospitals) {
      final latBucket = (hospital.latitude / bucketSize).floor();
      final lngBucket = (hospital.longitude / bucketSize).floor();
      buckets.putIfAbsent('$latBucket:$lngBucket', () => []).add(hospital);
    }

    return buckets.entries.map((entry) {
      final bucketHospitals = entry.value;
      final latitude =
          bucketHospitals.fold<double>(
            0,
            (sum, hospital) => sum + hospital.latitude,
          ) /
          bucketHospitals.length;
      final longitude =
          bucketHospitals.fold<double>(
            0,
            (sum, hospital) => sum + hospital.longitude,
          ) /
          bucketHospitals.length;

      return _HospitalCluster(
        id: entry.key,
        hospitals: bucketHospitals,
        location: LatLng(latitude, longitude),
      );
    }).toList();
  }

  // Plot by coordinates, not distance, so the map still works without a
  // location fix.
  static bool _hasCoordinates(Hospital hospital) {
    return hospital.latitude != 0.0 || hospital.longitude != 0.0;
  }

  double _clusterBucketSizeDegrees() {
    if (_mapZoom >= 12) return 0.03;
    if (_mapZoom >= 10) return 0.08;
    if (_mapZoom >= 8) return 0.18;
    return 0.35;
  }

  void _fitMapToResults() {
    final hospitals = widget.hospitals
        .where(_hasCoordinates)
        .take(80)
        .toList();

    if (_controller == null || hospitals.isEmpty) {
      widget.onMessage("No map results to fit.");
      return;
    }

    var minLat = hospitals.first.latitude;
    var maxLat = hospitals.first.latitude;
    var minLng = hospitals.first.longitude;
    var maxLng = hospitals.first.longitude;

    for (final hospital in hospitals) {
      if (hospital.latitude < minLat) minLat = hospital.latitude;
      if (hospital.latitude > maxLat) maxLat = hospital.latitude;
      if (hospital.longitude < minLng) minLng = hospital.longitude;
      if (hospital.longitude > maxLng) maxLng = hospital.longitude;
    }

    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }
}

class _HospitalCluster {
  final String id;
  final List<Hospital> hospitals;
  final LatLng location;

  const _HospitalCluster({
    required this.id,
    required this.hospitals,
    required this.location,
  });
}
