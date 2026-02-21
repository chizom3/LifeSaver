class Hospital {
  final String name;
  final String state;
  final String lga;
  final String ward;
  final double latitude;
  final double longitude;
  final String phone;

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
    );
  }

  // Helper: Get formatted distance (e.g. "1.2 km")
  String get distanceText {
    if (distanceInMeters == null) return "Unknown distance";
    return "${(distanceInMeters! / 1000).toStringAsFixed(1)} km";
  }
}
