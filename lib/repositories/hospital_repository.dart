import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../hospital.dart';
import '../services/hospital_update_service.dart';

class HospitalFilterCriteria {
  final String query;
  final String? state;
  final String? lga;
  final bool favoritesOnly;
  final Set<String> favoriteIds;
  final double? radiusKm;
  final String sortMode;
  final double? currentLatitude;
  final double? currentLongitude;

  const HospitalFilterCriteria({
    required this.query,
    required this.state,
    required this.lga,
    required this.favoritesOnly,
    required this.favoriteIds,
    required this.radiusKm,
    required this.sortMode,
    this.currentLatitude,
    this.currentLongitude,
  });
}

class HospitalRepository {
  static const double _spatialBucketSizeDegrees = 0.25;
  final Map<String, List<Hospital>> _spatialIndex = {};
  final Map<Hospital, String> _searchIndex = {};

  Future<List<Hospital>> loadHospitals() async {
    final response = await rootBundle.loadString('assets/data/hospitals.json');
    final data = json.decode(response) as List<dynamic>;
    final hospitals = data.map((json) {
      return Hospital.fromJson(json as Map<String, dynamic>);
    }).toList();
    buildIndexes(hospitals);
    return hospitals;
  }

  List<Hospital> applyUpdates(
    List<Hospital> hospitals,
    List<HospitalUpdate> updates,
  ) {
    if (updates.isEmpty) {
      buildIndexes(hospitals);
      return hospitals;
    }

    final byKey = <String, Hospital>{
      for (final hospital in hospitals) hospital.hospitalKey: hospital,
    };
    final closedKeys = <String>{};

    for (final update in updates.where((update) => update.approved)) {
      switch (update.action) {
        case HospitalUpdateAction.add:
          byKey[update.hospitalKey] = update.toHospital();
          closedKeys.remove(update.hospitalKey);
        case HospitalUpdateAction.update:
          final existing = byKey[update.hospitalKey];
          if (existing != null) {
            byKey[update.hospitalKey] = update.applyTo(existing);
          } else {
            byKey[update.hospitalKey] = update.toHospital();
          }
          closedKeys.remove(update.hospitalKey);
        case HospitalUpdateAction.close:
          closedKeys.add(update.hospitalKey);
      }
    }

    final merged = byKey.entries
        .where((entry) => !closedKeys.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    buildIndexes(merged);
    return merged;
  }

  void buildIndexes(List<Hospital> hospitals) {
    _spatialIndex.clear();
    _searchIndex.clear();

    for (final hospital in hospitals) {
      _searchIndex[hospital] = [
        hospital.name,
        hospital.state,
        hospital.lga,
        hospital.ward,
        hospital.physicalLocation,
        hospital.facilityLevel,
        hospital.ownership,
        hospital.operationStatus,
        hospital.licenseStatus,
        hospital.registrationStatus,
      ].join(' ').toLowerCase();

      if (hospital.latitude == 0.0 && hospital.longitude == 0.0) continue;
      final key = _bucketKey(hospital.latitude, hospital.longitude);
      _spatialIndex.putIfAbsent(key, () => []).add(hospital);
    }
  }

  List<String> stateOptions(List<Hospital> hospitals) {
    final states = hospitals
        .map((hospital) => hospital.state.trim())
        .where((state) => state.isNotEmpty)
        .toSet()
        .toList();
    states.sort();
    return states;
  }

  List<String> lgaOptions(List<Hospital> hospitals, String? selectedState) {
    final lgas = hospitals
        .where((hospital) {
          return selectedState == null ||
              hospital.state.trim() == selectedState;
        })
        .map((hospital) => hospital.lga.trim())
        .where((lga) => lga.isNotEmpty)
        .toSet()
        .toList();
    lgas.sort();
    return lgas;
  }

  List<Hospital> filterHospitals(
    List<Hospital> hospitals,
    HospitalFilterCriteria criteria,
  ) {
    final query = criteria.query.trim().toLowerCase();

    final candidates = _candidateHospitals(hospitals, criteria);
    final distances = <Hospital, double>{};

    double? distanceFor(Hospital hospital) {
      final existingDistance = hospital.distanceInMeters;
      if (existingDistance != null) return existingDistance;
      if (criteria.currentLatitude == null ||
          criteria.currentLongitude == null ||
          (hospital.latitude == 0.0 && hospital.longitude == 0.0)) {
        return null;
      }

      return distances.putIfAbsent(hospital, () {
        return _distanceMeters(
          criteria.currentLatitude!,
          criteria.currentLongitude!,
          hospital.latitude,
          hospital.longitude,
        );
      });
    }

    final results = candidates.where((hospital) {
      final distance = distanceFor(hospital);
      final matchesState =
          criteria.state == null || hospital.state.trim() == criteria.state;
      final matchesLga =
          criteria.lga == null || hospital.lga.trim() == criteria.lga;
      final matchesFavorite =
          !criteria.favoritesOnly ||
          criteria.favoriteIds.contains(hospitalId(hospital));
      final matchesRadius =
          criteria.radiusKm == null ||
          (distance != null && distance <= criteria.radiusKm! * 1000);
      final matchesQuery =
          query.isEmpty ||
          (_searchIndex[hospital] ??
                  '${hospital.name} ${hospital.state} ${hospital.lga} ${hospital.ward} ${hospital.facilityLevel} ${hospital.ownership}'
                      .toLowerCase())
              .contains(query);

      return matchesState &&
          matchesLga &&
          matchesFavorite &&
          matchesRadius &&
          matchesQuery;
    }).toList();

    results.sort((a, b) {
      if (criteria.sortMode == 'az') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }

      final distanceA = distanceFor(a);
      final distanceB = distanceFor(b);
      if (distanceA == null) return 1;
      if (distanceB == null) return -1;
      return distanceA.compareTo(distanceB);
    });

    return results;
  }

  String hospitalId(Hospital hospital) {
    return hospital.hospitalKey;
  }

  Iterable<Hospital> _candidateHospitals(
    List<Hospital> hospitals,
    HospitalFilterCriteria criteria,
  ) {
    if (criteria.radiusKm == null ||
        criteria.currentLatitude == null ||
        criteria.currentLongitude == null ||
        _spatialIndex.isEmpty) {
      return hospitals;
    }

    final latitude = criteria.currentLatitude!;
    final longitude = criteria.currentLongitude!;
    final latDelta = criteria.radiusKm! / 111.0;
    final cosLatitude = math.cos(latitude * math.pi / 180).abs();
    final lngDelta = cosLatitude < 0.01
        ? 180.0
        : criteria.radiusKm! / (111.0 * cosLatitude);

    final minLatBucket = _bucket(latitude - latDelta);
    final maxLatBucket = _bucket(latitude + latDelta);
    final minLngBucket = _bucket(longitude - lngDelta);
    final maxLngBucket = _bucket(longitude + lngDelta);

    final candidates = <Hospital>{};
    for (var latBucket = minLatBucket; latBucket <= maxLatBucket; latBucket++) {
      for (
        var lngBucket = minLngBucket;
        lngBucket <= maxLngBucket;
        lngBucket++
      ) {
        candidates.addAll(_spatialIndex['$latBucket:$lngBucket'] ?? const []);
      }
    }

    return candidates;
  }

  String _bucketKey(double latitude, double longitude) {
    return '${_bucket(latitude)}:${_bucket(longitude)}';
  }

  int _bucket(double value) {
    return (value / _spatialBucketSizeDegrees).floor();
  }

  double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final deltaLatitude = _degreesToRadians(endLatitude - startLatitude);
    final deltaLongitude = _degreesToRadians(endLongitude - startLongitude);
    final startLatitudeRadians = _degreesToRadians(startLatitude);
    final endLatitudeRadians = _degreesToRadians(endLatitude);

    final a =
        math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.sin(deltaLongitude / 2) *
            math.sin(deltaLongitude / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
