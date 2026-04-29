class Hospital {
  final String name;
  final String state;
  final String lga;
  final String ward;
  final double latitude;
  final double longitude;
  final String phone;
  final String id;
  final String uniqueId;
  final String physicalLocation;
  final String alternateNumber;
  final String facilityLevel;
  final String licenseStatus;
  final String operationStatus;
  final String operationalDays;
  final String registrationStatus;
  final String ownership;
  final String storedHospitalKey;

  // NEW: A place to store distance (starts as null)
  double? distanceInMeters;

  Hospital({
    required this.name,
    required this.state,
    required this.lga,
    required this.ward,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.id = '',
    this.uniqueId = '',
    this.physicalLocation = '',
    this.alternateNumber = '',
    this.facilityLevel = '',
    this.licenseStatus = '',
    this.operationStatus = '',
    this.operationalDays = '',
    this.registrationStatus = '',
    this.ownership = '',
    this.storedHospitalKey = '',
    this.distanceInMeters,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      name: json['data-facility_name'] ?? 'Unknown Hospital',
      state: json['data-state'] ?? '',
      lga: json['data-lga'] ?? '',
      ward: json['data-ward'] ?? '',
      latitude:
          double.tryParse(json['data-latitude']?.toString() ?? '0') ?? 0.0,
      longitude:
          double.tryParse(json['data-longitude']?.toString() ?? '0') ?? 0.0,
      phone: json['data-phone_number'] ?? 'No phone available',
      id: json['data-id']?.toString() ?? '',
      uniqueId: json['data-unique_id']?.toString() ?? '',
      physicalLocation: json['data-physical_location']?.toString() ?? '',
      alternateNumber: json['data-alternate_number']?.toString() ?? '',
      facilityLevel: json['data-facility_level']?.toString() ?? '',
      licenseStatus: json['data-license_status']?.toString() ?? '',
      operationStatus: json['data-operation_status']?.toString() ?? '',
      operationalDays: json['data-operational_days']?.toString() ?? '',
      registrationStatus: json['data-registration_status']?.toString() ?? '',
      ownership: json['data-ownership']?.toString() ?? '',
      storedHospitalKey: json['hospital_key']?.toString() ?? '',
    );
  }

  Hospital copyWith({
    String? name,
    String? state,
    String? lga,
    String? ward,
    double? latitude,
    double? longitude,
    String? phone,
    String? id,
    String? uniqueId,
    String? physicalLocation,
    String? alternateNumber,
    String? facilityLevel,
    String? licenseStatus,
    String? operationStatus,
    String? operationalDays,
    String? registrationStatus,
    String? ownership,
    String? storedHospitalKey,
    double? distanceInMeters,
  }) {
    return Hospital(
      name: name ?? this.name,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      ward: ward ?? this.ward,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      id: id ?? this.id,
      uniqueId: uniqueId ?? this.uniqueId,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      alternateNumber: alternateNumber ?? this.alternateNumber,
      facilityLevel: facilityLevel ?? this.facilityLevel,
      licenseStatus: licenseStatus ?? this.licenseStatus,
      operationStatus: operationStatus ?? this.operationStatus,
      operationalDays: operationalDays ?? this.operationalDays,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      ownership: ownership ?? this.ownership,
      storedHospitalKey: storedHospitalKey ?? this.storedHospitalKey,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data-id': id,
      'data-unique_id': uniqueId,
      'data-facility_name': name,
      'data-state': state,
      'data-lga': lga,
      'data-ward': ward,
      'data-longitude': longitude.toString(),
      'data-latitude': latitude.toString(),
      'data-physical_location': physicalLocation,
      'data-alternate_number': alternateNumber,
      'data-phone_number': phone,
      'data-facility_level': facilityLevel,
      'data-license_status': licenseStatus,
      'data-operation_status': operationStatus,
      'data-operational_days': operationalDays,
      'data-registration_status': registrationStatus,
      'data-ownership': ownership,
      'hospital_key': hospitalKey,
    };
  }

  // Helper: Get formatted distance (e.g. "1.2 km")
  String get distanceText {
    if (distanceInMeters == null) return "Unknown distance";
    return "${(distanceInMeters! / 1000).toStringAsFixed(1)} km";
  }

  String get facilityTypeText {
    final parts = [
      facilityLevel.trim(),
      ownership.trim(),
    ].where((part) => part.isNotEmpty && part != '0').toList();
    return parts.isEmpty ? 'Health facility' : parts.join(' - ');
  }

  String get operationStatusText {
    final status = operationStatus.trim();
    final days = operationalDays
        .split(',')
        .map((day) => day.trim())
        .where((day) => day.isNotEmpty && day != '0')
        .length;
    final dayText = days == 7
        ? '7 days'
        : days > 0
        ? '$days days/week'
        : '';

    if (status.isEmpty && dayText.isEmpty) return 'Status not confirmed';
    if (status.isEmpty) return dayText;
    if (dayText.isEmpty) return status;
    return '$status - $dayText';
  }

  String get displayPhone {
    final primary = phone.trim();
    if (primary.isNotEmpty && primary.toLowerCase() != 'no phone available') {
      return primary;
    }
    final alternate = alternateNumber.trim();
    if (alternate.isNotEmpty && alternate != '0') return alternate;
    return 'No phone available';
  }

  String get hospitalKey {
    final storedKey = storedHospitalKey.trim();
    if (storedKey.isNotEmpty) return storedKey;
    return [
      _keyPart(uniqueId),
      _keyPart(name),
      _keyPart(state),
      _keyPart(lga),
      latitude.toStringAsFixed(5),
      longitude.toStringAsFixed(5),
    ].join('|');
  }

  static String _keyPart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
