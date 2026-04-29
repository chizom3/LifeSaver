import 'package:cloud_firestore/cloud_firestore.dart';

import '../hospital.dart';

enum HospitalUpdateAction { add, update, close }

class HospitalUpdate {
  final String hospitalKey;
  final HospitalUpdateAction action;
  final bool approved;
  final DateTime updatedAt;
  final Map<String, dynamic> fields;

  const HospitalUpdate({
    required this.hospitalKey,
    required this.action,
    required this.approved,
    required this.updatedAt,
    required this.fields,
  });

  factory HospitalUpdate.fromJson(Map<String, dynamic> json) {
    return HospitalUpdate(
      hospitalKey: json['hospitalKey']?.toString() ?? '',
      action: _actionFromString(json['action']?.toString() ?? ''),
      approved: json['approved'] == true,
      updatedAt: _dateFromValue(json['updatedAt']),
      fields: Map<String, dynamic>.from(json['fields'] as Map? ?? const {}),
    );
  }

  factory HospitalUpdate.fromHospital({
    required Hospital hospital,
    required HospitalUpdateAction action,
    bool approved = true,
  }) {
    return HospitalUpdate(
      hospitalKey: hospital.hospitalKey,
      action: action,
      approved: approved,
      updatedAt: DateTime.now(),
      fields: hospital.toJson(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hospitalKey': hospitalKey,
      'action': action.name,
      'approved': approved,
      'updatedAt': updatedAt.toIso8601String(),
      'fields': fields,
    };
  }

  Hospital applyTo(Hospital hospital) {
    return hospital.copyWith(
      name: _stringField('data-facility_name') ?? hospital.name,
      state: _stringField('data-state') ?? hospital.state,
      lga: _stringField('data-lga') ?? hospital.lga,
      ward: _stringField('data-ward') ?? hospital.ward,
      latitude: _doubleField('data-latitude') ?? hospital.latitude,
      longitude: _doubleField('data-longitude') ?? hospital.longitude,
      phone: _stringField('data-phone_number') ?? hospital.phone,
      id: _stringField('data-id') ?? hospital.id,
      uniqueId: _stringField('data-unique_id') ?? hospital.uniqueId,
      physicalLocation:
          _stringField('data-physical_location') ?? hospital.physicalLocation,
      alternateNumber:
          _stringField('data-alternate_number') ?? hospital.alternateNumber,
      facilityLevel:
          _stringField('data-facility_level') ?? hospital.facilityLevel,
      licenseStatus:
          _stringField('data-license_status') ?? hospital.licenseStatus,
      operationStatus:
          _stringField('data-operation_status') ?? hospital.operationStatus,
      operationalDays:
          _stringField('data-operational_days') ?? hospital.operationalDays,
      registrationStatus:
          _stringField('data-registration_status') ??
          hospital.registrationStatus,
      ownership: _stringField('data-ownership') ?? hospital.ownership,
      storedHospitalKey: hospitalKey,
    );
  }

  Hospital toHospital() {
    return Hospital.fromJson({...fields, 'hospital_key': hospitalKey});
  }

  String? _stringField(String key) {
    final value = fields[key];
    if (value == null) return null;
    return value.toString();
  }

  double? _doubleField(String key) {
    final value = fields[key];
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static HospitalUpdateAction _actionFromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'add':
        return HospitalUpdateAction.add;
      case 'close':
        return HospitalUpdateAction.close;
      case 'update':
      default:
        return HospitalUpdateAction.update;
    }
  }

  static DateTime _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}

class HospitalUpdateService {
  static const String collectionName = 'hospital_updates';
  final FirebaseFirestore? _firestore;
  final bool enableCloudUpdates;

  HospitalUpdateService({
    FirebaseFirestore? firestore,
    this.enableCloudUpdates = true,
  }) : _firestore = firestore;

  Future<List<HospitalUpdate>> approvedUpdates() async {
    if (!enableCloudUpdates) return const [];

    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection(collectionName)
          .where('approved', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) {
            return HospitalUpdate.fromJson(doc.data());
          })
          .where((update) {
            return update.hospitalKey.trim().isNotEmpty;
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveApprovedUpdate(HospitalUpdate update) async {
    if (!enableCloudUpdates) return;
    final firestore = _firestore ?? FirebaseFirestore.instance;
    await firestore.collection(collectionName).add({
      ...update.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
