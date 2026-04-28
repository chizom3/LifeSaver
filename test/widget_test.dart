import 'package:flutter_test/flutter_test.dart';
import 'package:medimap/hospital.dart';
import 'package:medimap/repositories/hospital_repository.dart';
import 'package:medimap/services/favorites_service.dart';
import 'package:medimap/services/report_service.dart';
import 'package:medimap/services/sos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Hospital parses facility data and formats distance', () {
    final hospital = Hospital.fromJson({
      'data-facility_name': 'First Line Clinics',
      'data-state': 'Ogun',
      'data-lga': 'Ado Odo/Ota',
      'data-ward': 'Ota 2',
      'data-latitude': '6.69553',
      'data-longitude': '3.23143',
      'data-phone_number': '0807-971-7504',
    });

    hospital.distanceInMeters = 1250;

    expect(hospital.name, 'First Line Clinics');
    expect(hospital.state, 'Ogun');
    expect(hospital.lga, 'Ado Odo/Ota');
    expect(hospital.ward, 'Ota 2');
    expect(hospital.latitude, 6.69553);
    expect(hospital.longitude, 3.23143);
    expect(hospital.phone, '0807-971-7504');
    expect(hospital.distanceText, '1.3 km');
  });

  test('SosService includes medical ID details in message', () {
    final service = SosService();

    final message = service.buildMessage(
      mapLink: 'https://maps.example/location',
      name: 'Ada',
      age: '35',
      blood: 'O+',
      address: '12 Marina Road',
      conditions: 'Asthma',
      medications: 'Inhaler',
      preferredHospital: 'First Line Clinics',
      note: 'Penicillin allergy',
    );

    expect(message, contains('EMERGENCY! I need help.'));
    expect(message, contains('Name: Ada'));
    expect(message, contains('Age: 35'));
    expect(message, contains('Blood type: O+'));
    expect(message, contains('Address: 12 Marina Road'));
    expect(message, contains('Known conditions: Asthma'));
    expect(message, contains('Current medications: Inhaler'));
    expect(message, contains('Preferred hospital: First Line Clinics'));
    expect(message, contains('Medical notes: Penicillin allergy'));
    expect(message, contains('My location: https://maps.example/location'));
  });

  test('SosService can label last known location', () {
    final service = SosService();

    final message = service.buildMessage(
      mapLink: 'https://maps.example/last',
      name: '',
      blood: '',
      note: '',
      locationLabel: 'My last known location',
    );

    expect(
      message,
      contains('My last known location: https://maps.example/last'),
    );
  });

  test('HospitalRepository filters favorites and sorts alphabetically', () {
    final repository = HospitalRepository();
    final alpha = Hospital(
      name: 'Alpha Clinic',
      state: 'Lagos',
      lga: 'Ikeja',
      ward: 'Ward A',
      latitude: 6.1,
      longitude: 3.1,
      phone: '0801',
      distanceInMeters: 3000,
    );
    final beta = Hospital(
      name: 'Beta Hospital',
      state: 'Lagos',
      lga: 'Surulere',
      ward: 'Ward B',
      latitude: 6.2,
      longitude: 3.2,
      phone: '0802',
      distanceInMeters: 1000,
    );

    final results = repository.filterHospitals(
      [beta, alpha],
      HospitalFilterCriteria(
        query: '',
        state: 'Lagos',
        lga: null,
        favoritesOnly: true,
        favoriteIds: {repository.hospitalId(alpha)},
        radiusKm: null,
        sortMode: 'az',
      ),
    );

    expect(results, [alpha]);
  });

  test('HospitalRepository filters by radius and nearest sort', () {
    final repository = HospitalRepository();
    final near = Hospital(
      name: 'Near Hospital',
      state: 'Ogun',
      lga: 'Ota',
      ward: 'Ward A',
      latitude: 6.1,
      longitude: 3.1,
      phone: '0801',
      distanceInMeters: 1000,
    );
    final far = Hospital(
      name: 'Far Hospital',
      state: 'Ogun',
      lga: 'Ota',
      ward: 'Ward B',
      latitude: 6.2,
      longitude: 3.2,
      phone: '0802',
      distanceInMeters: 12000,
    );

    final results = repository.filterHospitals(
      [far, near],
      const HospitalFilterCriteria(
        query: '',
        state: null,
        lga: null,
        favoritesOnly: false,
        favoriteIds: {},
        radiusKm: 5,
        sortMode: 'nearest',
      ),
    );

    expect(results, [near]);
  });

  test(
    'HospitalRepository uses spatial index for coordinate radius filtering',
    () {
      final repository = HospitalRepository();
      final near = Hospital(
        name: 'Nearby Clinic',
        state: 'Lagos',
        lga: 'Ikeja',
        ward: 'Ward A',
        latitude: 6.6018,
        longitude: 3.3515,
        phone: '0801',
      );
      final far = Hospital(
        name: 'Far Clinic',
        state: 'Lagos',
        lga: 'Epe',
        ward: 'Ward B',
        latitude: 6.5833,
        longitude: 3.9833,
        phone: '0802',
      );
      repository.buildIndexes([far, near]);

      final results = repository.filterHospitals(
        [far, near],
        const HospitalFilterCriteria(
          query: '',
          state: null,
          lga: null,
          favoritesOnly: false,
          favoriteIds: {},
          radiusKm: 5,
          sortMode: 'nearest',
          currentLatitude: 6.6018,
          currentLongitude: 3.3515,
        ),
      );

      expect(results, [near]);
    },
  );

  test('FavoritesService persists favorite ids', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FavoritesService();

    await service.saveFavoriteIds({'one', 'two'});

    expect(await service.loadFavoriteIds(), {'one', 'two'});
  });

  test('ReportService stores pending facility reports', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ReportService();
    final hospital = Hospital(
      name: 'Report Hospital',
      state: 'Lagos',
      lga: 'Ikeja',
      ward: 'Ward C',
      latitude: 6.4,
      longitude: 3.4,
      phone: '0803',
    );

    await service.savePendingReport(
      FacilityReport.fromHospital(
        hospital: hospital,
        reason: 'Wrong phone number',
      ),
    );

    expect(await service.pendingReportCount(), 1);
  });

  test('ReportService defaults to local report fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ReportService();
    final hospital = Hospital(
      name: 'Fallback Hospital',
      state: 'Lagos',
      lga: 'Ikeja',
      ward: 'Ward D',
      latitude: 6.45,
      longitude: 3.39,
      phone: '0804',
    );

    final submitted = await service.submitReport(
      FacilityReport.fromHospital(hospital: hospital, reason: 'Wrong location'),
    );

    expect(submitted, isFalse);
    expect(service.submissionModeDescription, contains('Firebase is optional'));
    expect(await service.pendingReportCount(), 1);
  });
}
