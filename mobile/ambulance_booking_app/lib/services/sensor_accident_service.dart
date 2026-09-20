// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:js' show allowInterop;

class SensorTelemetry {
  final double x;
  final double y;
  final double z;
  final double gForce;
  final int vibrationLevel; // 0 - 100
  final bool isOverShaking;

  SensorTelemetry({
    required this.x,
    required this.y,
    required this.z,
    required this.gForce,
    required this.vibrationLevel,
    required this.isOverShaking,
  });
}

class SensorAccidentService {
  static final SensorAccidentService _instance = SensorAccidentService._internal();
  factory SensorAccidentService() => _instance;
  SensorAccidentService._internal();

  bool _isArmed = false;
  double _shakeSensitivityThreshold = 7.5; // G-force threshold (7.5G Limit)
  Timer? _simulatedSensorTimer;

  // Stream controllers
  final StreamController<SensorTelemetry> _telemetryController = StreamController<SensorTelemetry>.broadcast();
  final StreamController<Map<String, dynamic>> _crashController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SensorTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>> get crashStream => _crashController.stream;

  bool get isArmed => _isArmed;
  double get sensitivityThreshold => _shakeSensitivityThreshold;

  void setSensitivity(double threshold) {
    _shakeSensitivityThreshold = threshold;
    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream['shakeThreshold'] = threshold;
        }
      } catch (_) {}
    }
  }

  void startMonitoring({
    Function(String reason, double gForce)? onCrash,
    Function(SensorTelemetry telemetry)? onTelemetry,
  }) {
    _isArmed = true;

    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('startMotionSensor', [
            allowInterop((dynamic reason, dynamic gForce) {
              final r = reason?.toString() ?? "Over-Shaking Impact Detected";
              final g = (gForce as num?)?.toDouble() ?? 3.2;
              _crashController.add({'reason': r, 'gForce': g});
              if (onCrash != null) onCrash(r, g);
            }),
            allowInterop((dynamic x, dynamic y, dynamic z, dynamic gForce, dynamic vib) {
              final xVal = (x as num?)?.toDouble() ?? 0.0;
              final yVal = (y as num?)?.toDouble() ?? 0.0;
              final zVal = (z as num?)?.toDouble() ?? 9.8;
              final gVal = (gForce as num?)?.toDouble() ?? 1.0;
              final vibVal = (vib as num?)?.toInt() ?? 0;

              final tel = SensorTelemetry(
                x: xVal,
                y: yVal,
                z: zVal,
                gForce: gVal,
                vibrationLevel: vibVal,
                isOverShaking: gVal >= _shakeSensitivityThreshold || vibVal >= 98,
              );
              _telemetryController.add(tel);
              if (onTelemetry != null) onTelemetry(tel);
            })
          ]);
          return;
        }
      } catch (e) {
        debugPrint("JS sensor hook error: $e");
      }
    }

    // Fallback simulated background telemetry loop
    _simulatedSensorTimer?.cancel();
    _simulatedSensorTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_isArmed) return;
      final tel = SensorTelemetry(
        x: 0.1,
        y: 0.2,
        z: 9.8,
        gForce: 1.02,
        vibrationLevel: 12,
        isOverShaking: false,
      );
      _telemetryController.add(tel);
      if (onTelemetry != null) onTelemetry(tel);
    });
  }

  void stopMonitoring() {
    _isArmed = false;
    _simulatedSensorTimer?.cancel();
    _simulatedSensorTimer = null;

    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('stopMotionSensor');
        }
      } catch (_) {}
    }
  }

  void simulateViolentCrash({double gForce = 8.5}) {
    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('simulateCrashShake', [gForce]);
          return;
        }
      } catch (_) {}
    }

    // Native fallback simulation
    final tel = SensorTelemetry(
      x: 48.5,
      y: 52.2,
      z: 54.8,
      gForce: gForce,
      vibrationLevel: 100,
      isOverShaking: true,
    );
    _telemetryController.add(tel);
    _crashController.add({
      'reason': "Severe Crash Impact Detected (${gForce.toStringAsFixed(1)}G Mobile Sensor Spike - Limit 7.5G Exceeded)",
      'gForce': gForce,
    });
  }
}
