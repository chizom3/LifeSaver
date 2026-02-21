import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
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
  int _selectedIndex = 0; // 0 = Map, 1 = List
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  List<Hospital> _allHospitals = [];
  bool _isLoading = true;
  final AnalyticsService _analytics = AnalyticsService();
  BitmapDescriptor? _hospitalIcon; // <--- Add this

  @override
  void initState() {
    super.initState();
    _initializeData(); // Just call this one function
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        "assets/images/cross.png",
      );
      // We don't strictly need setState here since _loadHospitals calls it later,
      // but keeping it is safe.
      setState(() {
        _hospitalIcon = icon;
      });
    } catch (e) {
      print("Error loading custom icon: $e");
    }
  }

  Future<void> _initializeData() async {
    // 1. Load the Icon FIRST and wait for it
    await _loadCustomMarker();

    // 2. Then load the hospitals (Now they will use the loaded icon)
    await _loadHospitals();

    // 3. Finally get user location
    await _determinePosition();
  }

  // 1. Load Data
  Future<void> _loadHospitals() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/hospitals.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allHospitals = data.map((json) => Hospital.fromJson(json)).toList();
      });
    } catch (e) {
      print("Error loading data: $e");
    }
  }

  // 2. Get Location & Sort List
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();

    // CALCULATE DISTANCE FOR EVERY HOSPITAL
    for (var hospital in _allHospitals) {
      if (hospital.latitude != 0.0 && hospital.longitude != 0.0) {
        hospital.distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          hospital.latitude,
          hospital.longitude,
        );
      }
    }

    // SORT THE LIST (Nearest first)
    _allHospitals.sort((a, b) {
      if (a.distanceInMeters == null) return 1;
      if (b.distanceInMeters == null) return -1;
      return a.distanceInMeters!.compareTo(b.distanceInMeters!);
    });

    // Update Map Markers
    _updateMarkers(position);

    setState(() {
      _isLoading = false;
    });

    // Zoom Map to User
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  // 3. Create Map Markers
  void _updateMarkers(Position userPos) {
    Set<Marker> newMarkers = {};

    // Me
    newMarkers.add(
      Marker(
        markerId: const MarkerId('me'),
        position: LatLng(userPos.latitude, userPos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Hospitals (Only show nearest 50 on map to keep it clean)
    for (var hospital in _allHospitals.take(50)) {
      if (hospital.distanceInMeters == null) continue;

      newMarkers.add(
        Marker(
          markerId: MarkerId(hospital.name),
          position: LatLng(hospital.latitude, hospital.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _showHospitalDetails(hospital),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  // 4. ACTION: Show Details Sheet (Used by both Map and List)
  void _showHospitalDetails(Hospital hospital) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hospital.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                "${hospital.distanceText} • ${hospital.ward}",
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.call),
                      label: const Text("Call"),
                      onPressed: () {
                        _analytics.logCall(hospital.name); // <--- ADD THIS LINE
                        _launchPhone(hospital.phone);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text("Go"),
                      onPressed: () {
                        _analytics.logNavigation(
                          hospital.name,
                        ); // <--- ADD THIS LINE
                        _launchMap(hospital);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helpers for Launcher
  Future<void> _launchPhone(String phone) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(launchUri)) print("Could not launch dialer");
  }

  Future<void> _launchMap(Hospital h) async {
    // Corrected Google Maps Link with 'dir' (Directions)
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${h.latitude},${h.longitude}",
    );
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication))
      print("Could not launch maps");
  }

  Future<void> _sendSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contact = prefs.getString('contact');

    if (contact == null || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please save an Emergency Contact in your Profile first!",
          ),
        ),
      );
      return;
    }

    // Get the high-accuracy position
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // The fixed URL with the $ symbols
    final String mapLink =
        "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";
    final String message = "EMERGENCY! I need help. My location: $mapLink";

    // Encode the message to handle spaces and symbols correctly
    final Uri smsUri = Uri.parse(
      "sms:$contact?body=${Uri.encodeComponent(message)}",
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      print("Could not launch SMS. You might be on a computer.");
    }
  }

  // 5. THE UI BUILDER
  // Inside _MainScreenState class...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. TOP BAR
      appBar: AppBar(
        title: const Text('MediMap: Find Help'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _determinePosition,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),

      // 2. CENTER CONTENT
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_selectedIndex == 0 ? _buildMap() : _buildList()),

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
          _analytics.logViewSwitch(index == 0 ? "Map" : "List");
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map View',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'List View',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  // View A: The Map
  Widget _buildMap() {
    return GoogleMap(
      // Keep this static just for the first 0.5 seconds
      initialCameraPosition: const CameraPosition(
        target: LatLng(6.5244, 3.3792), // Default to Lagos
        zoom: 12,
      ),
      markers: _markers,

      // THIS IS KEY: Shows the blue dot on the map
      myLocationEnabled: true,
      myLocationButtonEnabled: true,

      onMapCreated: (controller) {
        _controller = controller;
        // If we already have the location, move there immediately
        if (!_isLoading && _allHospitals.isNotEmpty) {
          _determinePosition(); // Trigger the move
        }
      },
    );
  }

  // View B: The Sorted List
  Widget _buildList() {
    // 1. Wrap everything in RefreshIndicator
    return RefreshIndicator(
      onRefresh: _determinePosition, // This calls your GPS function when pulled
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(), // Important: Lets you pull even if the list is short
        itemCount: _allHospitals.length,
        itemBuilder: (context, index) {
          final hospital = _allHospitals[index];

          // Only show hospitals with valid distances
          if (hospital.distanceInMeters == null) return const SizedBox.shrink();

          // 2. Your Original Card Design is preserved here:
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              title: Text(
                hospital.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(hospital.ward),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hospital.distanceText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                ],
              ),
              onTap: () => _showHospitalDetails(hospital),
            ),
          );
        },
      ),
    );
  }
}
