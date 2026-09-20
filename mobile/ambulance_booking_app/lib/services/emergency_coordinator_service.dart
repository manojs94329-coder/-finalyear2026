import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'emergency_siren_service.dart';

class EmergencySessionData {
  final String emergencyId;
  final String status;
  final String victimName;
  final String secondaryContactPhone;
  final double latitude;
  final double longitude;
  final int batteryLevel;
  final bool isCriticalBattery;
  final String transmissionPath;
  final String googleMapsUrl;
  final String agoraStreamUrl;
  final String unbookUrl;
  final String? cancellationReason;
  final String? cancelledBy;

  EmergencySessionData({
    required this.emergencyId,
    required this.status,
    required this.victimName,
    required this.secondaryContactPhone,
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    required this.isCriticalBattery,
    required this.transmissionPath,
    required this.googleMapsUrl,
    required this.agoraStreamUrl,
    required this.unbookUrl,
    this.cancellationReason,
    this.cancelledBy,
  });

  factory EmergencySessionData.fromJson(Map<String, dynamic> json) {
    return EmergencySessionData(
      emergencyId: json['emergencyId'] ?? '',
      status: json['status'] ?? 'ACTIVE_EMERGENCY',
      victimName: json['victimName'] ?? '',
      secondaryContactPhone: json['secondaryContactPhone'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 13.0827,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.2707,
      batteryLevel: json['batteryLevel'] ?? 100,
      isCriticalBattery: json['isCriticalBattery'] ?? false,
      transmissionPath: json['transmissionPath'] ?? 'Cellular_Data',
      googleMapsUrl: json['googleMapsUrl'] ?? '',
      agoraStreamUrl: json['agoraStreamUrl'] ?? '',
      unbookUrl: json['unbookUrl'] ?? '',
      cancellationReason: json['cancellationReason'],
      cancelledBy: json['cancelledBy'],
    );
  }
}

class EmergencyCoordinatorService {
  static final EmergencyCoordinatorService _instance = EmergencyCoordinatorService._internal();
  factory EmergencyCoordinatorService() => _instance;
  EmergencyCoordinatorService._internal();

  final EmergencySirenService _sirenService = EmergencySirenService();

  // SharedPreferences Keys
  static const String _keyContactName = 'emergency_contact_name';
  static const String _keyContactPhone = 'emergency_contact_phone';
  static const String _keyContactRelation = 'emergency_contact_relation';

  // Battery and rate-limiting
  int _batteryLevel = 14; // Default simulated critical battery to demonstrate warning
  DateTime? _lastBatteryNotificationTime;
  static const Duration _batteryAlertCooldown = Duration(minutes: 10);

  // Satellite connectivity
  bool _isSatelliteHardwareSupported = false;
  String _transmissionPath = "Cellular_Data";

  // Remote listener timer
  Timer? _remotePollTimer;
  String? _activeEmergencyId;

  int get batteryLevel => _batteryLevel;
  bool get isCriticalBattery => _batteryLevel <= 15;
  String get transmissionPath => _transmissionPath;
  bool get isSatelliteHardwareSupported => _isSatelliteHardwareSupported;

  void setBatteryLevel(int level) {
    _batteryLevel = level.clamp(1, 100);
  }

  /// Initialize platform capabilities & satellite support
  Future<void> initPlatformCapabilities() async {
    // Platform-specific satellite check:
    // Android: Check SatelliteManager / hardware availability
    // iOS: Check Apple Emergency SOS via satellite capability
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Simulate check for Android SatelliteManager (Android 14+ supported hardware)
      _isSatelliteHardwareSupported = true;
      _transmissionPath = "Satellite_SOS";
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // Apple Satellite SOS check
      _isSatelliteHardwareSupported = true;
      _transmissionPath = "Apple_Satellite_SOS";
    } else {
      // Web / fallback: cellular and high-speed data network
      _isSatelliteHardwareSupported = false;
      _transmissionPath = "Cellular_Data_Fallback";
    }
  }

  // ==========================================
  // 1. SharedPreferences Emergency Contact
  // ==========================================

  Future<Map<String, String>> loadEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyContactName) ?? 'Secondary Emergency Contact';
    final phone = prefs.getString(_keyContactPhone) ?? '9876543210';
    final relation = prefs.getString(_keyContactRelation) ?? 'Family / Guardian';
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }

  Future<void> saveEmergencyContact({
    required String name,
    required String phone,
    String relation = 'Family / Guardian',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyContactName, name.trim());
    await prefs.setString(_keyContactPhone, phone.trim());
    await prefs.setString(_keyContactRelation, relation.trim());
  }

  // ==========================================
  // 2. Battery Monitoring & Rate Limiting
  // ==========================================

  bool shouldTriggerBatteryAlert() {
    if (!isCriticalBattery) return false;
    if (_lastBatteryNotificationTime == null) return true;
    final elapsed = DateTime.now().difference(_lastBatteryNotificationTime!);
    return elapsed >= _batteryAlertCooldown;
  }

  Future<bool> sendBatteryWarning(String emergencyId) async {
    if (!shouldTriggerBatteryAlert()) return false;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergencies/$emergencyId/battery-warning'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'batteryLevel': _batteryLevel}),
      );
      if (response.statusCode == 200) {
        _lastBatteryNotificationTime = DateTime.now();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ==========================================
  // 3. Emergency Creation & SMS Formatting
  // ==========================================

  Future<EmergencySessionData?> createEmergencySession({
    required int userId,
    required String victimName,
    required String victimPhone,
    required String contactName,
    required String contactPhone,
    required double lat,
    required double lng,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'victimName': victimName,
        'phoneNumber': victimPhone,
        'secondaryContactName': contactName,
        'secondaryContactPhone': contactPhone,
        'latitude': lat,
        'longitude': lng,
        'batteryLevel': _batteryLevel,
        'transmissionPath': _transmissionPath,
        'baseUrl': ApiConfig.baseUrl.replaceAll('/api', ''),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergencies'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = EmergencySessionData.fromJson(data);
        _activeEmergencyId = session.emergencyId;
        return session;
      }
    } catch (e) {
      debugPrint('Error creating emergency session: $e');
    }
    return null;
  }

  String formatEmergencySmsBody({
    required String victimName,
    required double lat,
    required double lng,
    required String mapsUrl,
    required String agoraUrl,
    required String unbookUrl,
  }) {
    return '🚨 EMERGENCY CRASH DETECTED!\n'
        'Victim: $victimName\n'
        'Battery: $_batteryLevel% ${isCriticalBattery ? "[CRITICAL LOW BATTERY]" : ""}\n'
        'Path: $_transmissionPath\n'
        '📍 Live GPS: $mapsUrl\n'
        '📹 Live Audio/Video Stream: $agoraUrl\n'
        '🛑 Remote Cancel / Unbook (False Alarm): $unbookUrl\n'
        'Automated Emergency Response System.';
  }

  // ==========================================
  // 4. Remote Status Listening & Unbooking
  // ==========================================

  void startRemoteStatusListener(
    String emergencyId, {
    required Function(String status, String? reason) onRemoteCancelled,
  }) {
    _remotePollTimer?.cancel();
    _activeEmergencyId = emergencyId;

    _remotePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/emergencies/$emergencyId'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'] as String? ?? '';
          if (status == 'CANCELLED_BY_SECONDARY_USER' || status == 'CANCELLED_BY_USER') {
            timer.cancel();
            _remotePollTimer = null;
            // IMMEDIATELY STOP SIREN AND RELEASE RESOURCES
            await _sirenService.stopAndRelease();
            onRemoteCancelled(status, data['cancellationReason']);
          }
        }
      } catch (_) {}
    });
  }

  void stopRemoteStatusListener() {
    _remotePollTimer?.cancel();
    _remotePollTimer = null;
    _activeEmergencyId = null;
  }

  Future<bool> cancelEmergencyRemotely({
    required String emergencyId,
    required String cancelledBy,
    String reason = 'False alarm confirmed by secondary contact',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergencies/$emergencyId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cancelledBy': cancelledBy,
          'reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<EmergencySessionData?> fetchEmergencySession(String emergencyId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/emergencies/$emergencyId'),
      );
      if (response.statusCode == 200) {
        return EmergencySessionData.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }
}
