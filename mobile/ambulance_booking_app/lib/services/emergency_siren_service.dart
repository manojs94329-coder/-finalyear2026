import 'dart:async';
import 'package:flutter/services.dart';
import 'siren/siren_stub.dart' if (dart.library.html) 'siren/siren_web.dart';

class EmergencySirenService {
  static final EmergencySirenService _instance = EmergencySirenService._internal();
  factory EmergencySirenService() => _instance;
  EmergencySirenService._internal();

  final PlatformSirenPlayer _platformPlayer = getPlatformSirenPlayer();
  Timer? _nativePulseTimer;
  bool _isSirenActive = false;
  bool _isMuted = false;

  bool get isSirenActive => _isSirenActive;
  bool get isMuted => _isMuted;

  Future<void> startSiren() async {
    _isSirenActive = true;
    if (_isMuted) return;

    try {
      _platformPlayer.start();
    } catch (_) {}

    _nativePulseTimer?.cancel();
    _triggerAcousticAndHapticPulse();
    _nativePulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_isSirenActive || _isMuted) return;
      _triggerAcousticAndHapticPulse();
    });
  }

  void _triggerAcousticAndHapticPulse() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> stopAndRelease() async {
    _isSirenActive = false;
    _nativePulseTimer?.cancel();
    _nativePulseTimer = null;

    try {
      _platformPlayer.stop();
    } catch (_) {}
  }

  Future<void> stopSiren() => stopAndRelease();

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _nativePulseTimer?.cancel();
      _nativePulseTimer = null;
      try {
        _platformPlayer.stop();
      } catch (_) {}
    } else if (_isSirenActive) {
      await startSiren();
    }
  }
}
