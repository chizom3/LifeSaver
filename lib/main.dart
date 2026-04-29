import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hospital.dart';
import 'analytics_service.dart';
import 'package:firebase_core/firebase_core.dart'; // Fixes 'Firebase'
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Fixes 'Crashlytics'
import 'firebase_options.dart'; // Fixes 'DefaultFirebaseOptions'
import 'profile_page.dart';
import 'repositories/first_aid_repository.dart';
import 'repositories/hospital_repository.dart';
import 'services/admin_auth_service.dart';
import 'services/favorites_service.dart';
import 'services/hospital_verification_service.dart';
import 'services/hospital_update_service.dart';
import 'services/location_service.dart';
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

  // ADD THIS: Pass all errors to Crashlytics automatically
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

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
  bool _showOnboarding = false;
  bool _hasAcceptedMedicalDisclaimer = false;
  bool _hasEmergencyContact = false;
  bool _isAdminSignedIn = false;
  final AnalyticsService _analytics = AnalyticsService();
  final AdminAuthService _adminAuthService = AdminAuthService(
    adminEmails: {'admin@medimap.app', 'chizomw@gmail.com'},
  );
  final FavoritesService _favoritesService = FavoritesService();
  final FirstAidRepository _firstAidRepository = FirstAidRepository();
  final HospitalRepository _hospitalRepository = HospitalRepository();
  final HospitalVerificationService _verificationService =
      HospitalVerificationService();
  final HospitalUpdateService _hospitalUpdateService = HospitalUpdateService();
  final LocationService _locationService = LocationService();
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

  @override
  void initState() {
    super.initState();
    _startupWatch.start();
    _initializeData(); // Just call this one function
  }

  @override
  void dispose() {
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
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('contact_phones') ?? [];
    final legacyContact = (prefs.getString('contact') ?? '').trim();
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

  Future<Position?> _getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    final result = await _locationService.getCurrentPosition(
      accuracy: accuracy,
    );

    if (result.isSuccess) {
      if (mounted) {
        setState(() => _hasLocationPermission = true);
      }
      return result.position;
    }

    if (!mounted) return null;
    setState(() => _hasLocationPermission = false);

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
      case LocationFailure.unavailable:
      case null:
        _showMessage("Could not get your current location. Please try again.");
    }

    return null;
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

  List<Hospital> get _filteredHospitals {
    return _hospitalRepository.filterHospitals(
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
  Future<void> _determinePosition() async {
    final position = await _getCurrentPosition();
    if (position == null) {
      final lastKnownLocation = await _locationService.loadLastKnownLocation();
      if (lastKnownLocation != null) {
        _applyLocation(
          LatLng(lastKnownLocation.latitude, lastKnownLocation.longitude),
        );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showMessage("Using your last known location.");
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final location = LatLng(position.latitude, position.longitude);
    _applyLocation(location);
  }

  void _applyLocation(LatLng location) {
    _currentLocation = location;

    _locationService.updateHospitalDistancesFromCoordinates(
      _allHospitals,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    // SORT THE LIST (Nearest first)
    _allHospitals.sort((a, b) {
      if (a.distanceInMeters == null) return 1;
      if (b.distanceInMeters == null) return -1;
      return a.distanceInMeters!.compareTo(b.distanceInMeters!);
    });

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
    _showMessage('Marked as reported by users.');
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
                    _launchReportEmail(hospital: hospital, reason: reason);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchReportEmail({
    required Hospital hospital,
    required String reason,
  }) async {
    final report = FacilityReport.fromHospital(
      hospital: hospital,
      reason: reason,
    );
    final submitted = await _reportService.submitReport(report);

    final uri = Uri(
      scheme: 'mailto',
      path: 'reports@medimap.app',
      queryParameters: {
        'subject': 'MediMap facility correction: ${hospital.name}',
        'body': report.toEmailBody(),
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage(
        submitted
            ? "Report submitted. Email could not open on this device."
            : "Report saved locally. Email could not open on this device.",
      );
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
    final prefs = await SharedPreferences.getInstance();
    final contactNames = prefs.getStringList('contact_names') ?? [];
    final contactRelationships =
        prefs.getStringList('contact_relationships') ?? [];
    var contactPhones = prefs.getStringList('contact_phones') ?? [];
    final legacyContact = _cleanPhoneNumber(prefs.getString('contact') ?? '');
    if (contactPhones.isEmpty && legacyContact.isNotEmpty) {
      contactPhones = [legacyContact];
    }
    final String name = (prefs.getString('name') ?? '').trim();
    final String age = (prefs.getString('age') ?? '').trim();
    final String blood = (prefs.getString('blood') ?? '').trim();
    final String address = (prefs.getString('address') ?? '').trim();
    final String conditions = (prefs.getString('conditions') ?? '').trim();
    final String medications = (prefs.getString('medications') ?? '').trim();
    final String preferredHospital =
        (prefs.getString('preferred_hospital') ?? '').trim();
    final String note = (prefs.getString('note') ?? '').trim();
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

    // Get the high-accuracy position
    final pos = await _getCurrentPosition(accuracy: LocationAccuracy.high);
    final lastKnownLocation = pos == null
        ? await _locationService.loadLastKnownLocation()
        : null;

    if (pos == null && lastKnownLocation == null) return;

    final String mapLink = pos != null
        ? "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}"
        : lastKnownLocation!.mapLink;
    final usingLastKnownLocation = pos == null;
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

    // Encode the message to handle spaces and symbols correctly
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
        title: const Text('MediMap: Find Help'),
        actions: [
          IconButton(
            tooltip: 'Emergency mode',
            icon: const Icon(Icons.emergency, color: Colors.red),
            onPressed: _openEmergencyMode,
          ),
          IconButton(
            tooltip: 'Test SOS',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => _sendSOS(testMode: true),
          ),
          IconButton(
            tooltip: _isAdminSignedIn ? 'Admin dashboard' : 'Admin sign in',
            icon: Icon(
              _isAdminSignedIn
                  ? Icons.admin_panel_settings
                  : Icons.lock_outline,
            ),
            onPressed: _openAdminDashboard,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Safety and privacy',
            onSelected: (value) {
              switch (value) {
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'disclaimer',
                child: Text('Medical disclaimer'),
              ),
              PopupMenuItem(value: 'privacy', child: Text('Privacy policy')),
              PopupMenuItem(value: 'data', child: Text('Hospital data status')),
              PopupMenuItem(value: 'reports', child: Text('Report storage')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _determinePosition,
          ),
          IconButton(icon: const Icon(Icons.person), onPressed: _openMedicalId),
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
                if (_selectedIndex != 1) _buildSearchAndFilters(),
                Expanded(
                  child: switch (_selectedIndex) {
                    0 => _buildList(),
                    1 => _buildFirstAid(),
                    _ => _buildMap(),
                  },
                ),
              ],
            ),

      // 3. FLOATING SOS BUTTON
      // This is likely where the duplicate was. Ensure this block appears ONLY ONCE.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendSOS,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text(
          "SOS Alert",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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

  Widget _buildSearchAndFilters() {
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
        setState(() {
          _searchQuery = value;
        });
        _onFiltersChanged();
      },
      onStateChanged: (value) {
        setState(() {
          _selectedState = value;
          _selectedLga = null;
        });
        _onFiltersChanged();
      },
      onLgaChanged: (value) {
        setState(() {
          _selectedLga = value;
        });
        _onFiltersChanged();
      },
      onFavoritesChanged: (selected) {
        setState(() {
          _showFavoritesOnly = selected;
        });
        _onFiltersChanged();
      },
      onRadiusChanged: (radiusKm) {
        setState(() {
          _selectedRadiusKm = radiusKm;
        });
        _onFiltersChanged();
      },
      onSortModeChanged: (sortMode) {
        setState(() {
          _sortMode = sortMode;
        });
        _onFiltersChanged();
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
        _onFiltersChanged();
      },
      onClearFilters: () {
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
