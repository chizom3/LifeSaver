import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hospital.dart';

class FacilityReport {
  final String reason;
  final String hospitalName;
  final String state;
  final String lga;
  final String ward;
  final String phone;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const FacilityReport({
    required this.reason,
    required this.hospitalName,
    required this.state,
    required this.lga,
    required this.ward,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory FacilityReport.fromHospital({
    required Hospital hospital,
    required String reason,
  }) {
    return FacilityReport(
      reason: reason,
      hospitalName: hospital.name,
      state: hospital.state,
      lga: hospital.lga,
      ward: hospital.ward,
      phone: hospital.phone,
      latitude: hospital.latitude,
      longitude: hospital.longitude,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'hospitalName': hospitalName,
      'state': state,
      'lga': lga,
      'ward': ward,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String toEmailBody() {
    return [
      'Correction type: $reason',
      '',
      'Hospital: $hospitalName',
      'State: $state',
      'LGA: $lga',
      'Ward: $ward',
      'Phone: $phone',
      'Coordinates: $latitude, $longitude',
      'Created at: ${createdAt.toIso8601String()}',
      '',
      'Correction details:',
    ].join('\n');
  }
}

class ReportService {
  static const String _pendingReportsKey = 'pending_facility_reports';
  final FirebaseFirestore? _firestore;
  final bool enableCloudSubmissions;

  ReportService({
    FirebaseFirestore? firestore,
    this.enableCloudSubmissions = false,
  }) : _firestore = firestore;

  String get submissionModeDescription {
    return enableCloudSubmissions
        ? 'Reports are sent to Firebase when available, with local fallback.'
        : 'Reports are saved locally and prepared for email. Firebase is optional.';
  }

  Future<bool> submitReport(FacilityReport report) async {
    if (!enableCloudSubmissions) {
      await savePendingReport(report);
      return false;
    }

    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await firestore.collection('facility_reports').add(report.toJson());
      return true;
    } catch (_) {
      await savePendingReport(report);
      return false;
    }
  }

  Future<void> savePendingReport(FacilityReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList(_pendingReportsKey) ?? [];
    reports.add(jsonEncode(report.toJson()));
    await prefs.setStringList(_pendingReportsKey, reports);
  }

  Future<int> pendingReportCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingReportsKey) ?? []).length;
  }
}
