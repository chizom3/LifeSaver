import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hospital.dart';

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  unavailable,
}

class LocationResult {
  final Position? position;
  final LocationFailure? failure;

  /// True when [position] is the phone's cached fix, not a fresh one.
  final bool isCached;

  const LocationResult.success(this.position, {this.isCached = false})
    : failure = null;

  const LocationResult.failure(this.failure)
    : position = null,
      isCached = false;

  bool get isSuccess => position != null;
}

class LastKnownLocation {
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const LastKnownLocation({
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  bool get isRecent {
    return DateTime.now().difference(savedAt) < const Duration(hours: 24);
  }

  String get mapLink {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}

class LocationService {
  static const String _lastLatitudeKey = 'last_location_latitude';
  static const String _lastLongitudeKey = 'last_location_longitude';
  static const String _lastSavedAtKey = 'last_location_saved_at';

  /// Gets a fresh fix. If [onCachedPosition] is given, the phone's cached
  /// fix (if any) is reported first so callers can show something at once.
  /// When the fresh fix times out, the cached fix is returned instead.
  Future<LocationResult> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 30),
    void Function(Position position)? onCachedPosition,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationFailure.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        LocationFailure.permissionDeniedForever,
      );
    }

    final cached = await _cachedDevicePosition();
    if (cached != null) onCachedPosition?.call(cached);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
      await saveLastKnownLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return LocationResult.success(position);
    } on TimeoutException {
      if (cached != null) return LocationResult.success(cached, isCached: true);
      return const LocationResult.failure(LocationFailure.timedOut);
    } catch (_) {
      if (cached != null) return LocationResult.success(cached, isCached: true);
      return const LocationResult.failure(LocationFailure.unavailable);
    }
  }

  /// The OS's most recent fix, available instantly when the phone has one.
  Future<Position?> _cachedDevicePosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null; // Unsupported on web, or no cached fix.
    }
  }

  void updateHospitalDistances(List<Hospital> hospitals, Position position) {
    updateHospitalDistancesFromCoordinates(
      hospitals,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  void updateHospitalDistancesFromCoordinates(
    List<Hospital> hospitals, {
    required double latitude,
    required double longitude,
  }) {
    for (final hospital in hospitals) {
      if (hospital.latitude != 0.0 && hospital.longitude != 0.0) {
        hospital.distanceInMeters = Geolocator.distanceBetween(
          latitude,
          longitude,
          hospital.latitude,
          hospital.longitude,
        );
      }
    }
  }

  Future<void> saveLastKnownLocation({
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatitudeKey, latitude);
    await prefs.setDouble(_lastLongitudeKey, longitude);
    await prefs.setString(_lastSavedAtKey, DateTime.now().toIso8601String());
  }

  Future<LastKnownLocation?> loadLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble(_lastLatitudeKey);
    final longitude = prefs.getDouble(_lastLongitudeKey);
    final savedAtValue = prefs.getString(_lastSavedAtKey);

    if (latitude == null || longitude == null || savedAtValue == null) {
      return null;
    }

    final savedAt = DateTime.tryParse(savedAtValue);
    if (savedAt == null) return null;

    final location = LastKnownLocation(
      latitude: latitude,
      longitude: longitude,
      savedAt: savedAt,
    );

    return location.isRecent ? location : null;
  }
}
