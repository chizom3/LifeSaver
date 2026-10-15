import 'dart:async';

import 'package:flutter/foundation.dart' show PlatformDispatcher, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hospital.dart';
import 'analytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'profile_page.dart';
import 'repositories/first_aid_repository.dart';
import 'repositories/hospital_repository.dart';
import 'services/admin_auth_service.dart';
import 'services/favorites_service.dart';
import 'services/hospital_verification_service.dart';
import 'services/hospital_update_service.dart';
import 'services/location_service.dart';
import 'services/medical_id_store.dart';
import 'services/report_service.dart';
import 'services/sos_service.dart';
import 'widgets/admin_dashboard_page.dart';
import 'widgets/admin_login_page.dart';
import 'widgets/emergency_mode_page.dart';
import 'widgets/first_aid_page.dart';
import 'widgets/hospital_detail_sheet.dart';
import 'widgets/hospital_list_view.dart';
import 'widgets/hospital_map_view.dart';
import 'widgets/hospital_search_filters.dart';
import 'widgets/medical_disclaimer_page.dart';
import 'widgets/onboarding_page.dart';
import 'widgets/privacy_policy_page.dart';
import 'widgets/sos_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics has no web implementation.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediMap',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // STATE VARIABLES
  int _selectedIndex = 0; // 0 = Hospitals, 1 = First Aid, 2 = Optional map
  List<Hospital> _allHospitals = [];
  LatLng? _currentLocation;
  String? _selectedHospitalId;
  bool _isLoading = true;
  bool _hospitalLoadFailed = false;
  bool _hasLocationPermission = false;
  // Why the last location request failed; null while searching or after
  // success. Drives the banner above the hospital list.
  LocationFailure? _locationFailure;
  bool _showOnboarding = false;
  bool _hasAcceptedMedicalDisclaimer = false;
  bool _hasEmergencyContact = false;
  bool _isAdminSignedIn = false;
  bool _showSearchFilters = false;
  final AnalyticsService _analytics = AnalyticsService();
  final AdminAuthService _adminAuthService = AdminAuthService();
  final FavoritesService _favoritesService = FavoritesService();
  final FirstAidRepository _firstAidRepository = FirstAidRepository();
  final HospitalRepository _hospitalRepository = HospitalRepository();
  final HospitalVerificationService _verificationService =
      HospitalVerificationService();
  final HospitalUpdateService _hospitalUpdateService = HospitalUpdateService();
  final LocationService _locationService = LocationService();
  final MedicalIdStore _medicalIdStore = MedicalIdStore();
  final ReportService _reportService = ReportService(
    enableCloudSubmissions: true,
  );
  final SosService _sosService = SosService();
  BitmapDescriptor? _hospitalIcon;
  final TextEditingController _searchController = TextEditingController();
  final Stopwatch _startupWatch = Stopwatch();
  String _searchQuery = '';
  String? _selectedState;
  String? _selectedLga;
  bool _showFavoritesOnly = false;
  bool _usingCloudHospitalUpdates = false;
  int _cloudHospitalUpdateCount = 0;
  double? _selectedRadiusKm;
  String _sortMode = 'nearest';
  Set<String> _favoriteHospitalIds = {};
  int _visibleHospitalCount = 100;
  Timer? _searchDebounce;
  Future<void>? _locationRequest;
  bool _sosInProgress = false;

  @override
  void initState() {
    super.initState();
    _startupWatch.start();
    _initializeData(); // Just call this one function
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        "assets/images/cross.png",
      );
      if (!mounted) return;
      setState(() {
        _hospitalIcon = icon;
      });
    } catch (e) {
      debugPrint("Error loading custom icon: $e");
    }
  }

  Future<void> _initializeData() async {
    final initWatch = Stopwatch()..start();
    await _loadOnboardingState();
    _isAdminSignedIn = await _adminAuthService.isCurrentUserAdmin();

    // 1. Load the Icon FIRST and wait for it
    await _loadCustomMarker();

    // 2. Then load the hospitals (Now they will use the loaded icon)
    await _loadHospitals();

    await _loadFavorites();
    await _loadMedicalIdStatus();

    // 3. Finally get user location
    await _determinePosition();
    initWatch.stop();
    _startupWatch.stop();
    debugPrint(
      'MediMap startup: init=${initWatch.elapsedMilliseconds}ms total=${_startupWatch.elapsedMilliseconds}ms hospitals=${_allHospitals.length}',
    );
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !(prefs.getBool('has_seen_onboarding') ?? false);
      _hasAcceptedMedicalDisclaimer =
          prefs.getBool('accepted_medical_disclaimer') ?? false;
    });
  }

  Future<void> _acceptMedicalDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accepted_medical_disclaimer', true);
    if (!mounted) return;
    setState(() {
      _hasAcceptedMedicalDisclaimer = true;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  Future<void> _openMedicalIdFromOnboarding() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    await _loadMedicalIdStatus();
    await _finishOnboarding();
  }

  Future<void> _openMedicalId() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    await _loadMedicalIdStatus();
  }

  Future<void> _loadFavorites() async {
    final favoriteIds = await _favoritesService.loadFavoriteIds();
    if (!mounted) return;
    setState(() {
      _favoriteHospitalIds = favoriteIds;
    });
  }

  Future<void> _loadMedicalIdStatus() async {
    final snapshot = await _medicalIdStore.load();
    final contacts = snapshot.list('contact_phones');
    final legacyContact = snapshot.string('contact').trim();
    if (!mounted) return;
    setState(() {
      _hasEmergencyContact =
          contacts.any((contact) {
            return _cleanPhoneNumber(contact).isNotEmpty;
          }) ||
          _cleanPhoneNumber(legacyContact).isNotEmpty;
    });
  }

  // 1. Load Data
  Future<void> _loadHospitals() async {
    try {
      final watch = Stopwatch()..start();
      final localHospitals = await _hospitalRepository.loadHospitals();
      final cloudUpdates = await _hospitalUpdateService.approvedUpdates();
      final hospitals = _hospitalRepository.applyUpdates(
        localHospitals,
        cloudUpdates,
      );
      watch.stop();
      debugPrint(
        'MediMap data: loaded ${hospitals.length} hospitals with ${cloudUpdates.length} cloud updates in ${watch.elapsedMilliseconds}ms',
      );
      if (!mounted) return;
      setState(() {
        _allHospitals = hospitals;
        _cloudHospitalUpdateCount = cloudUpdates.length;
        _usingCloudHospitalUpdates = cloudUpdates.isNotEmpty;
        _hospitalLoadFailed = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hospitalLoadFailed = true;
      });
      _showMessage("Could not load hospital data. Please restart the app.");
    }
  }

  Future<LocationResult> _getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 30),
    void Function(Position position)? onCachedPosition,
  }) async {
    final result = await _locationService.getCurrentPosition(
      accuracy: accuracy,
      timeLimit: timeLimit,
      onCachedPosition: onCachedPosition,
    );

    // Timeouts mean permission is fine; only service/permission problems
    // should hide the map's my-location layer.
    final permissionOk =
        result.isSuccess ||
        result.failure == LocationFailure.timedOut ||
        result.failure == LocationFailure.unavailable;
    if (mounted) setState(() => _hasLocationPermission = permissionOk);
    if (result.isSuccess || !mounted) return result;

    switch (result.failure) {
      case LocationFailure.serviceDisabled:
        _showMessage(
          "Please turn on location services to find nearby hospitals.",
        );
      case LocationFailure.permissionDenied:
        _showMessage(
          "Location permission is needed to sort hospitals by distance.",
        );
      case LocationFailure.permissionDeniedForever:
        _showMessage(
          "Location permission is blocked. Enable it from your phone settings.",
        );
      case LocationFailure.timedOut:
        _showMessage(
          "Couldn't get a GPS fix. Try near a window, then tap Retry.",
        );
      case LocationFailure.unavailable:
      case null:
        _showMessage("Could not get your current location. Please try again.");
    }

    return result;
  }

  String? get _locationNotice {
    if (_currentLocation != null) return null;
    return switch (_locationFailure) {
      null => 'Finding your location...',
      LocationFailure.serviceDisabled =>
        'Location is off on your phone. Turn it on to see the nearest hospitals.',
      LocationFailure.permissionDenied =>
        'Location permission is needed to sort hospitals by distance.',
      LocationFailure.permissionDeniedForever =>
        'Location permission is blocked. Enable it in your phone settings.',
      LocationFailure.timedOut =>
        "Couldn't get a GPS fix yet. Try near a window, then tap Retry.",
      LocationFailure.unavailable => "Couldn't get your location. Tap Retry.",
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanPhoneNumber(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase().contains('no phone')) {
      return '';
    }

    final hasLeadingPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
  }

  String _hospitalId(Hospital hospital) {
    return _hospitalRepository.hospitalId(hospital);
  }

  bool _isFavorite(Hospital hospital) {
    return _favoritesService.isFavorite(hospital, _favoriteHospitalIds);
  }

  Future<void> _toggleFavorite(Hospital hospital) async {
    final id = _hospitalId(hospital);
    final updatedFavorites = Set<String>.from(_favoriteHospitalIds);
    final wasFavorite = updatedFavorites.contains(id);

    if (wasFavorite) {
      updatedFavorites.remove(id);
    } else {
      updatedFavorites.add(id);
    }

    await _favoritesService.saveFavoriteIds(updatedFavorites);

    if (!mounted) return;
    setState(() {
      _favoriteHospitalIds = updatedFavorites;
    });
    _onFiltersChanged();
    _showMessage(
      wasFavorite ? "Removed from saved hospitals." : "Saved hospital.",
    );
  }

  List<String> get _stateOptions {
    return _hospitalRepository.stateOptions(_allHospitals);
  }

  List<String> get _lgaOptions {
    return _hospitalRepository.lgaOptions(_allHospitals, _selectedState);
  }

  // Filtering ~38k hospitals is expensive and the getter is read several
  // times per build, so cache the result until an input changes.
  List<Hospital>? _filteredCache;
  Object? _filteredCacheKey;

  List<Hospital> get _filteredHospitals {
    final key = (
      _allHospitals,
      _searchQuery,
      _selectedState,
      _selectedLga,
      _showFavoritesOnly,
      _favoriteHospitalIds,
      _selectedRadiusKm,
      _sortMode,
      _currentLocation,
    );
    if (_filteredCache != null && key == _filteredCacheKey) {
      return _filteredCache!;
    }
    _filteredCacheKey = key;
    return _filteredCache = _hospitalRepository.filterHospitals(
      _allHospitals,
      HospitalFilterCriteria(
        query: _searchQuery,
        state: _selectedState,
        lga: _selectedLga,
        favoritesOnly: _showFavoritesOnly,
        favoriteIds: _favoriteHospitalIds,
        radiusKm: _selectedRadiusKm,
        sortMode: _sortMode,
        currentLatitude: _currentLocation?.latitude,
        currentLongitude: _currentLocation?.longitude,
      ),
    );
  }

  void _onFiltersChanged() {
    _visibleHospitalCount = 100;
  }

  // 2. Get Location & Sort List
  // Startup, the map, and refresh can all ask at once; share one request.
  Future<void> _determinePosition() {
    return _locationRequest ??= _determinePositionNow().whenComplete(() {
      _locationRequest = null;
    });
  }

  Future<void> _determinePositionNow() async {
    if (mounted) setState(() => _locationFailure = null);

    // Show distances from the phone's cached fix right away, then refine.
    final result = await _getCurrentPosition(
      onCachedPosition: (cached) {
        _applyLocation(LatLng(cached.latitude, cached.longitude));
      },
    );
    if (!mounted) return;

    final position = result.position;
    if (position != null) {
      _applyLocation(LatLng(position.latitude, position.longitude));
    } else if (_currentLocation == null) {
      final saved = await _locationService.loadLastKnownLocation();
      if (saved != null) {
        _applyLocation(LatLng(saved.latitude, saved.longitude));
        _showMessage("Using your last known location.");
      }
    }

    if (!mounted) return;
    setState(() {
      _locationFailure = result.failure;
      _isLoading = false;
    });
  }

  void _applyLocation(LatLng location) {
    _currentLocation = location;

    _locationService.updateHospitalDistancesFromCoordinates(
      _allHospitals,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    // Distances changed in place; force the filtered list to re-sort.
    _filteredCache = null;

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showHospitalDetails(Hospital hospital) async {
    _analytics.logHospitalView(hospital.name, hospital.state);
    final cleanedPhone = _cleanPhoneNumber(hospital.displayPhone);
    final hospitalId = _hospitalId(hospital);
    final status = await _verificationService.statusFor(hospitalId);
    if (!mounted) return;

    showHospitalDetailSheet(
      context: context,
      hospital: hospital,
      isFavorite: _isFavorite(hospital),
      canCall: cleanedPhone.isNotEmpty,
      phoneText: cleanedPhone.isEmpty
          ? 'No phone available'
          : hospital.displayPhone,
      onToggleFavorite: () => _toggleFavorite(hospital),
      onCall: () {
        _analytics.logCall(hospital.name);
        _launchPhone(hospital.displayPhone);
      },
      onDirections: () {
        _analytics.logNavigation(hospital.name);
        _launchMap(hospital);
      },
      onReportInfo: () {
        Navigator.pop(context);
        _showReportInfoSheet(hospital);
      },
      verificationStatus: status,
      onMarkCorrect: () => _markHospitalCorrect(hospital),
      onMarkIncorrect: () => _markHospitalIncorrect(hospital),
    );
  }

  Future<void> _markHospitalCorrect(Hospital hospital) async {
    await _verificationService.markCorrect(_hospitalId(hospital));
    _showMessage('Thanks. Marked this hospital info as correct.');
  }

  Future<void> _markHospitalIncorrect(Hospital hospital) async {
    await _verificationService.markIncorrect(_hospitalId(hospital));
    _showMessage('Marked this hospital info as wrong.');
    _showReportInfoSheet(hospital);
  }

  Future<void> _showReportInfoSheet(Hospital hospital) {
    const reasons = [
      'Wrong phone number',
      'Wrong location',
      'Facility is closed',
      'Duplicate facility',
      'Other correction',
    ];

    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Report wrong info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(hospital.name, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              for (final reason in reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.report_outlined),
                  title: Text(reason),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _submitReport(hospital: hospital, reason: reason);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _promptReportDetails(String reason) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(reason),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'What should be corrected? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Send report'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReport({
    required Hospital hospital,
    required String reason,
  }) async {
    final details = await _promptReportDetails(reason);
    if (details == null) return;

    final report = FacilityReport.fromHospital(
      hospital: hospital,
      reason: reason,
      details: details,
    );
    final submitted = await _reportService.submitReport(report);
    if (submitted) {
      _showMessage("Report submitted. Thank you.");
      return;
    }

    // Cloud submission failed: the report is saved locally, and email is
    // offered as a backup channel.
    final uri = Uri(
      scheme: 'mailto',
      path: 'reports@medimap.app',
      query: encodeQueryParameters({
        'subject': 'MediMap facility correction: ${hospital.name}',
        'body': report.toEmailBody(),
      }),
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage("Report saved locally. Email could not open on this device.");
    }
  }

  // Helpers for Launcher
  Future<void> _launchPhone(String phone) async {
    final cleanedPhone = _cleanPhoneNumber(phone);
    if (cleanedPhone.isEmpty) {
      _showMessage("This hospital does not have a valid phone number.");
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: cleanedPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showMessage("Could not open the phone dialer on this device.");
    }
  }

  Future<void> _launchMap(Hospital h) async {
    // Corrected Google Maps Link with 'dir' (Directions)
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${h.latitude},${h.longitude}",
    );
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      _showMessage("Could not open maps on this device.");
    }
  }

  Future<void> _sendSOS({bool testMode = false}) async {
    // Ignore repeat taps while an SOS flow is already open.
    if (_sosInProgress) return;
    _sosInProgress = true;
    try {
      await _runSos(testMode: testMode);
    } finally {
      _sosInProgress = false;
    }
  }

  Future<void> _runSos({required bool testMode}) async {
    final snapshot = await _medicalIdStore.load();
    final contactNames = snapshot.list('contact_names');
    final contactRelationships =
        snapshot.list('contact_relationships');
    var contactPhones = snapshot.list('contact_phones');
    final legacyContact = _cleanPhoneNumber(snapshot.string('contact'));
    if (contactPhones.isEmpty && legacyContact.isNotEmpty) {
      contactPhones = [legacyContact];
    }
    final String name = (snapshot.string('name')).trim();
    final String age = (snapshot.string('age')).trim();
    final String blood = (snapshot.string('blood')).trim();
    final String address = (snapshot.string('address')).trim();
    final String conditions = (snapshot.string('conditions')).trim();
    final String medications = (snapshot.string('medications')).trim();
    final String preferredHospital =
        (snapshot.string('preferred_hospital')).trim();
    final String note = (snapshot.string('note')).trim();
    final contacts = <EmergencyContact>[];

    for (var index = 0; index < contactPhones.length; index++) {
      final phone = _cleanPhoneNumber(contactPhones[index]);
      if (phone.isEmpty) continue;
      contacts.add(
        EmergencyContact(
          name: index < contactNames.length ? contactNames[index].trim() : '',
          phone: phone,
          relationship: index < contactRelationships.length
              ? contactRelationships[index].trim()
              : '',
        ),
      );
    }

    if (contacts.isEmpty) {
      _showMessage(
        "Please save an emergency contact in your Medical ID first.",
      );
      return;
    }

    if (!mounted) return;
    final selectedContacts = contacts.length == 1
        ? [contacts.first]
        : await showContactPickerSheet(context: context, contacts: contacts);
    if (selectedContacts == null || selectedContacts.isEmpty) return;

    // Don't keep the user waiting on GPS: fall back to last known location.
    _showMessage("Getting your location...");
    final result = await _getCurrentPosition(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    final pos = result.position;
    final lastKnownLocation = pos == null
        ? await _locationService.loadLastKnownLocation()
        : null;

    if (pos == null && lastKnownLocation == null) return;

    final String mapLink = pos != null
        ? "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}"
        : lastKnownLocation!.mapLink;
    // A cached fix may be minutes old, so label it honestly in the SMS.
    final usingLastKnownLocation = pos == null || result.isCached;
    final String message = _sosService.buildMessage(
      mapLink: mapLink,
      name: name,
      age: age,
      blood: blood,
      address: address,
      conditions: conditions,
      medications: medications,
      preferredHospital: preferredHospital,
      note: note,
      locationLabel: usingLastKnownLocation
          ? 'My last known location'
          : 'My location',
    );

    if (!mounted) return;
    if (usingLastKnownLocation) {
      _showMessage("Using your last known location for SOS.");
    }
    final confirmedMessage = await showSosConfirmationSheet(
      context: context,
      contact: selectedContacts
          .map((contact) => contact.displayName)
          .join(', '),
      message: testMode ? '[TEST SOS - DO NOT SEND]\n\n$message' : message,
      onEmergencyCall: () => _launchPhone('112'),
    );

    if (confirmedMessage == null) return;

    if (testMode) {
      _showMessage('Test SOS complete. No SMS was opened or sent.');
      return;
    }

    final Uri smsUri = _sosService.smsUri(
      contact: selectedContacts.map((contact) => contact.phone).join(','),
      message: confirmedMessage,
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      _showMessage("Could not open SMS on this device.");
    }
  }

  // 5. THE UI BUILDER
  // Inside _MainScreenState class...

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingPage(
        onFinish: _finishOnboarding,
        onOpenMedicalId: _openMedicalIdFromOnboarding,
      );
    }

    if (!_hasAcceptedMedicalDisclaimer) {
      return MedicalDisclaimerPage(
        requiresAcceptance: true,
        onAccepted: _acceptMedicalDisclaimer,
      );
    }

    return Scaffold(
      // 1. TOP BAR
      appBar: AppBar(
        title: const Text('MediMap'),
        actions: [
          IconButton(
            tooltip: 'Emergency mode',
            icon: const Icon(Icons.emergency, color: Colors.red),
            onPressed: _openEmergencyMode,
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'medical_id':
                  _openMedicalId();
                case 'refresh':
                  _determinePosition();
                case 'test_sos':
                  _sendSOS(testMode: true);
                case 'admin':
                  _openAdminDashboard();
                case 'disclaimer':
                  _openMedicalDisclaimer();
                case 'privacy':
                  _openPrivacyPolicy();
                case 'data':
                  _showHospitalDataStatus();
                case 'reports':
                  _showReportSubmissionInfo();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'medical_id',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Medical ID'),
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh location'),
                ),
              ),
              const PopupMenuItem(
                value: 'test_sos',
                child: ListTile(
                  leading: Icon(Icons.fact_check_outlined),
                  title: Text('Test SOS'),
                ),
              ),
              PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  leading: Icon(
                    _isAdminSignedIn
                        ? Icons.admin_panel_settings
                        : Icons.lock_outline,
                  ),
                  title: Text(
                    _isAdminSignedIn ? 'Admin dashboard' : 'Admin sign in',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'disclaimer',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Medical disclaimer'),
                ),
              ),
              const PopupMenuItem(
                value: 'privacy',
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy policy'),
                ),
              ),
              const PopupMenuItem(
                value: 'data',
                child: ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Hospital data status'),
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: ListTile(
                  leading: Icon(Icons.assignment_outlined),
                  title: Text('Report storage'),
                ),
              ),
            ],
          ),
        ],
      ),

      // 2. CENTER CONTENT
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hospitalLoadFailed
          ? _buildHospitalDataError()
          : Column(
              children: [
                if (!_hasEmergencyContact) _buildMedicalIdPrompt(),
                Expanded(child: _buildMainContent()),
              ],
            ),

      // 3. FLOATING SOS BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: _sendSOS,
        backgroundColor: Colors.red,
        tooltip: 'SOS Alert',
        child: const Icon(Icons.sos, color: Colors.white),
      ),

      // 4. BOTTOM NAVIGATION
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
          _analytics.logViewSwitch(switch (index) {
            0 => "Hospitals",
            1 => "First Aid",
            _ => "Map",
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: 'Hospitals',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'First Aid',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHospitalDataError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Hospital data could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check the app installation and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () async {
                setState(() => _isLoading = true);
                await _loadHospitals();
                await _determinePosition();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openMedicalDisclaimer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicalDisclaimerPage()),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  }

  void _showReportSubmissionInfo() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Storage'),
          content: Text(_reportService.submissionModeDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showHospitalDataStatus() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final message = _usingCloudHospitalUpdates
            ? 'Using offline hospital data plus $_cloudHospitalUpdateCount approved Firebase update(s).'
            : 'Using offline hospital data. No approved Firebase updates were applied.';
        return AlertDialog(
          title: const Text('Hospital Data'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openEmergencyMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return EmergencyModePage(
            onCallEmergency: () => _launchPhone('112'),
            onSendSos: _sendSOS,
            onOpenFirstAid: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 1;
              });
            },
            onFindNearestHospital: () {
              Navigator.pop(context);
              _showNearestHospitalsFromEmergency();
            },
          );
        },
      ),
    );
  }

  void _showNearestHospitalsFromEmergency() {
    setState(() {
      _selectedIndex = 0;
      _sortMode = 'nearest';
      _showFavoritesOnly = false;
      _selectedRadiusKm ??= 25;
    });
    _onFiltersChanged();

    if (_currentLocation == null) {
      _determinePosition();
      _showMessage('Finding your location for nearest hospitals.');
      return;
    }

    _showMessage(
      'Showing nearest hospitals. Tap Directions to open Google Maps.',
    );
  }

  Future<void> _openAdminDashboard() async {
    final isAdmin = await _adminAuthService.isCurrentUserAdmin(
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() => _isAdminSignedIn = isAdmin);

    if (!isAdmin) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) {
            return AdminLoginPage(
              authService: _adminAuthService,
              onSignedIn: () {
                setState(() => _isAdminSignedIn = true);
                _openAdminDashboard();
              },
            );
          },
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return AdminDashboardPage(
            authService: _adminAuthService,
            reportService: _reportService,
            verificationService: _verificationService,
            updateService: _hospitalUpdateService,
          );
        },
      ),
    );
    if (!mounted) return;
    final stillAdmin = await _adminAuthService.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() => _isAdminSignedIn = stillAdmin);
  }

  Widget _buildSearchAndFilters({VoidCallback? onSheetChanged}) {
    return HospitalSearchFilters(
      searchController: _searchController,
      searchQuery: _searchQuery,
      states: _stateOptions,
      lgas: _lgaOptions,
      selectedState: _selectedState,
      selectedLga: _selectedLga,
      showFavoritesOnly: _showFavoritesOnly,
      favoriteCount: _favoriteHospitalIds.length,
      selectedRadiusKm: _selectedRadiusKm,
      sortMode: _sortMode,
      resultCount: _filteredHospitals.length,
      onSearchChanged: (value) {
        // Filtering ~38k hospitals per keystroke is wasteful; wait for a pause.
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          setState(() {
            _searchQuery = value;
          });
          _onFiltersChanged();
          onSheetChanged?.call();
        });
      },
      onStateChanged: (value) {
        setState(() {
          _selectedState = value;
          _selectedLga = null;
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onLgaChanged: (value) {
        setState(() {
          _selectedLga = value;
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onFavoritesChanged: (selected) {
        setState(() {
          _showFavoritesOnly = selected;
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onRadiusChanged: (radiusKm) {
        setState(() {
          _selectedRadiusKm = radiusKm;
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onSortModeChanged: (sortMode) {
        setState(() {
          _sortMode = sortMode;
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onClearSearch: () {
        _searchDebounce?.cancel();
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
      onClearFilters: () {
        _searchDebounce?.cancel();
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedState = null;
          _selectedLga = null;
          _showFavoritesOnly = false;
          _selectedRadiusKm = null;
          _sortMode = 'nearest';
        });
        _onFiltersChanged();
        onSheetChanged?.call();
      },
    );
  }

  Widget _buildMainContent() {
    if (_selectedIndex == 1) {
      return _buildFirstAid();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 900;
        final content = _selectedIndex == 0 ? _buildList() : _buildMap();

        if (useColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: _showSearchFilters ? 360 : 0,
                child: _showSearchFilters
                    ? SingleChildScrollView(child: _buildSearchAndFilters())
                    : const SizedBox.shrink(),
              ),
              if (_showSearchFilters) const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _buildResultsToolbar(useColumns: true),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildResultsToolbar(useColumns: false),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildResultsToolbar({required bool useColumns}) {
    final filtersAreOpen = useColumns && _showSearchFilters;

    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              icon: Icon(
                filtersAreOpen
                    ? Icons.filter_alt_off
                    : Icons.manage_search,
              ),
              label: Text(filtersAreOpen ? 'Hide filters' : 'Search'),
              onPressed: () {
                if (useColumns) {
                  setState(() => _showSearchFilters = !_showSearchFilters);
                  return;
                }
                _openSearchFiltersSheet();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _filteredHospitals.length == 1
                    ? '1 facility'
                    : '${_filteredHospitals.length} facilities',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _sortMode == 'az' ? 'A-Z' : 'Nearest',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.42,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                      child: Row(
                        children: [
                          Text(
                            'Search and filters',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                        ),
                        children: [
                          _buildSearchAndFilters(
                            // Debounced search can fire after the sheet closes.
                            onSheetChanged: () {
                              if (context.mounted) setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMedicalIdPrompt() {
    return Material(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            const Icon(Icons.medical_information, color: Colors.red),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Add an emergency contact so SOS is ready when needed.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _openMedicalId, child: const Text('Set up')),
          ],
        ),
      ),
    );
  }

  // Optional map preview
  Widget _buildMap() {
    return HospitalMapView(
      hospitals: _filteredHospitals,
      currentLocation: _currentLocation,
      selectedHospitalId: _selectedHospitalId,
      hasLocationPermission: _hasLocationPermission,
      hospitalIcon: _hospitalIcon,
      hospitalId: _hospitalId,
      isFavorite: _isFavorite,
      onHospitalSelected: (hospital) {
        setState(() => _selectedHospitalId = _hospitalId(hospital));
        _showHospitalDetails(hospital);
      },
      onLocationRefreshRequested: () {
        if (!_isLoading && _allHospitals.isNotEmpty) {
          _determinePosition();
        }
      },
      onMessage: _showMessage,
    );
  }

  // Main hospital search and directions view
  Widget _buildList() {
    return HospitalListView(
      hospitals: _filteredHospitals,
      visibleHospitalCount: _visibleHospitalCount,
      isFavorite: _isFavorite,
      canCall: (hospital) =>
          _cleanPhoneNumber(hospital.displayPhone).isNotEmpty,
      onHospitalSelected: _showHospitalDetails,
      onToggleFavorite: _toggleFavorite,
      onCall: (hospital) {
        _analytics.logCall(hospital.name);
        _launchPhone(hospital.displayPhone);
      },
      onDirections: (hospital) {
        _analytics.logNavigation(hospital.name);
        _launchMap(hospital);
      },
      onRefreshLocation: _determinePosition,
      locationNotice: _locationNotice,
      isFindingLocation: _currentLocation == null && _locationFailure == null,
      onShowMore: () {
        setState(() {
          _visibleHospitalCount += 100;
        });
      },
    );
  }

  Widget _buildFirstAid() {
    return FirstAidPage(
      repository: _firstAidRepository,
      onCallEmergency: () => _launchPhone('112'),
      onFindHospitals: () {
        setState(() {
          _selectedIndex = 0;
        });
      },
    );
  }
}
