import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hospital.dart';

class FacilityReport {
  final String reportId;
  final bool isCloudReport;
  final String reason;
  final String hospitalKey;
  final String hospitalName;
  final String state;
  final String lga;
  final String ward;
  final String phone;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const FacilityReport({
    this.reportId = '',
    this.isCloudReport = false,
    required this.reason,
    required this.hospitalKey,
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
      hospitalKey: hospital.hospitalKey,
      hospitalName: hospital.name,
      state: hospital.state,
      lga: hospital.lga,
      ward: hospital.ward,
      phone: hospital.displayPhone,
      latitude: hospital.latitude,
      longitude: hospital.longitude,
      createdAt: DateTime.now(),
    );
  }

  factory FacilityReport.fromJson(Map<String, dynamic> json) {
    return FacilityReport(
      reportId: json['reportId']?.toString() ?? '',
      isCloudReport: json['isCloudReport'] == true,
      reason: json['reason']?.toString() ?? '',
      hospitalKey: json['hospitalKey']?.toString() ?? '',
      hospitalName: json['hospitalName']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      lga: json['lga']?.toString() ?? '',
      ward: json['ward']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Hospital toHospital() {
    return Hospital(
      name: hospitalName,
      state: state,
      lga: lga,
      ward: ward,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      storedHospitalKey: hospitalKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'isCloudReport': isCloudReport,
      'reason': reason,
      'hospitalKey': hospitalKey,
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
      'Hospital key: $hospitalKey',
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

  Future<List<FacilityReport>> pendingReports() async {
    final cloudReports = enableCloudSubmissions
        ? await _pendingCloudReports()
        : <FacilityReport>[];
    final localReports = await _pendingLocalReports();
    return [...cloudReports, ...localReports];
  }

  Future<List<FacilityReport>> _pendingCloudReports() async {
    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final snapshot = await firestore.collection('facility_reports').get();
      return snapshot.docs
          .map((doc) {
            return FacilityReport.fromJson({
              ...doc.data(),
              'reportId': doc.id,
              'isCloudReport': true,
            });
          })
          .where((report) => report.hospitalName.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<FacilityReport>> _pendingLocalReports() async {
    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList(_pendingReportsKey) ?? [];
    return reports.map((raw) {
      return FacilityReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }).toList();
  }

  Future<void> removePendingReport(int index) async {
    final reports = await pendingReports();
    if (index < 0 || index >= reports.length) return;
    final report = reports[index];
    if (report.isCloudReport && report.reportId.isNotEmpty) {
      try {
        final firestore = _firestore ?? FirebaseFirestore.instance;
        await firestore
            .collection('facility_reports')
            .doc(report.reportId)
            .delete();
        return;
      } catch (_) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final localReports = prefs.getStringList(_pendingReportsKey) ?? [];
    final localIndex =
        index - reports.where((item) => item.isCloudReport).length;
    if (localIndex < 0 || localIndex >= localReports.length) return;
    localReports.removeAt(localIndex);
    await prefs.setStringList(_pendingReportsKey, localReports);
  }
}
