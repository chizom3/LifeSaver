import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // 1. Log when a user views a specific hospital
  Future<void> logHospitalView(String hospitalName, String state) async {
    await _analytics.logEvent(
      name: 'view_hospital',
      parameters: {'hospital_name': hospitalName, 'state': state},
    );
  }

  // 2. Log when they click "Call"
  Future<void> logCall(String hospitalName) async {
    await _analytics.logEvent(
      name: 'call_hospital',
      parameters: {'hospital_name': hospitalName},
    );
  }

  // 3. Log when they click "Go" (Navigation)
  Future<void> logNavigation(String hospitalName) async {
    await _analytics.logEvent(
      name: 'navigate_hospital',
      parameters: {'hospital_name': hospitalName},
    );
  }

  // 4. Log which view they prefer (Map vs List)
  Future<void> logViewSwitch(String viewName) async {
    await _analytics.logEvent(
      name: 'switch_view',
      parameters: {
        'view_mode': viewName, // "Map" or "List"
      },
    );
  }
}
