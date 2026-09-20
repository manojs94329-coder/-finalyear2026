import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/emergency_remote_unbook_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmbulanceBookingApp());
}

class AmbulanceBookingApp extends StatelessWidget {
  const AmbulanceBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if opened via emergency unbooking link
    String? emergencyId;
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('id')) {
        emergencyId = uri.queryParameters['id'];
      } else if (uri.fragment.contains('emergency-unbook')) {
        final fragUri = Uri.parse('http://dummy/?${uri.fragment.split('?').last}');
        emergencyId = fragUri.queryParameters['id'];
      }
    } catch (_) {}

    return MaterialApp(
      title: 'Emergency Response & Ambulance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: (emergencyId != null && emergencyId.isNotEmpty)
          ? EmergencyRemoteUnbookScreen(emergencyId: emergencyId)
          : const LoginScreen(),
    );
  }
}
