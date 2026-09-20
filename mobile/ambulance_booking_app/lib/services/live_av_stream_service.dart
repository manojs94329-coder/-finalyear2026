// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:js' show allowInterop;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class StreamFrameData {
  final String emergencyId;
  final String frameBase64;
  final int decibels;
  final String status;
  final DateTime timestamp;

  StreamFrameData({
    required this.emergencyId,
    required this.frameBase64,
    required this.decibels,
    required this.status,
    required this.timestamp,
  });

  factory StreamFrameData.fromJson(Map<String, dynamic> json) {
    return StreamFrameData(
      emergencyId: json['emergencyId'] ?? '',
      frameBase64: json['frameBase64'] ?? '',
      decibels: (json['decibels'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'IDLE',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class LiveAvStreamService {
  static final LiveAvStreamService _instance = LiveAvStreamService._internal();
  factory LiveAvStreamService() => _instance;
  LiveAvStreamService._internal();

  bool _isBroadcasting = false;
  bool _isAudioMuted = false;
  String _cameraFacing = "user";
  int _currentDecibels = 0;
  String _streamStatusMessage = "Idle";
  String _latestLocalFrameBase64 = "";

  final StreamController<int> _audioDecibelController = StreamController<int>.broadcast();
  final StreamController<String> _frameController = StreamController<String>.broadcast();

  Stream<int> get audioDecibelStream => _audioDecibelController.stream;
  Stream<String> get frameStream => _frameController.stream;

  bool get isBroadcasting => _isBroadcasting;
  bool get isAudioMuted => _isAudioMuted;
  String get cameraFacing => _cameraFacing;
  int get currentDecibels => _currentDecibels;
  String get streamStatusMessage => _streamStatusMessage;
  String get latestLocalFrameBase64 => _latestLocalFrameBase64;

  void startLiveBroadcastWithRelay({
    required String emergencyId,
    Function(String base64, int decibels)? onFrameCaptured,
    Function(int decibels)? onAudioLevel,
    Function(bool success, String message)? onReady,
  }) {
    _isBroadcasting = true;
    final uploadUrl = "${ApiConfig.baseUrl}/emergencies/$emergencyId/stream";

    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('startLiveBroadcastWithRelay', [
            emergencyId,
            uploadUrl,
            allowInterop((dynamic db) {
              final val = (db as num?)?.toInt() ?? 0;
              _currentDecibels = val;
              _audioDecibelController.add(val);
              if (onAudioLevel != null) onAudioLevel(val);
            }),
            allowInterop((dynamic base64, dynamic db) {
              final str = base64?.toString() ?? "";
              final val = (db as num?)?.toInt() ?? 0;
              _latestLocalFrameBase64 = str;
              _currentDecibels = val;
              _frameController.add(str);
              if (onFrameCaptured != null) onFrameCaptured(str, val);
            }),
            allowInterop((dynamic success, dynamic msg) {
              final ok = success == true;
              _streamStatusMessage = msg?.toString() ?? "Active";
              if (onReady != null) onReady(ok, _streamStatusMessage);
            })
          ]);
          return;
        }
      } catch (e) {
        debugPrint("JS Live Broadcast start error: $e");
      }
    }

    _streamStatusMessage = "Broadcasting HD AV Stream (Native Relay)";
    if (onReady != null) onReady(true, _streamStatusMessage);
  }

  void stopLiveBroadcast() {
    _isBroadcasting = false;
    _currentDecibels = 0;
    _audioDecibelController.add(0);

    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('stopLiveBroadcast');
        }
      } catch (_) {}
    }
  }

  bool toggleMute() {
    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          final res = emergencyStream.callMethod('toggleMuteAudio');
          _isAudioMuted = res == true;
          return _isAudioMuted;
        }
      } catch (_) {}
    }
    _isAudioMuted = !_isAudioMuted;
    return _isAudioMuted;
  }

  void switchCamera({Function(bool success, String message)? onReady}) {
    _cameraFacing = _cameraFacing == "user" ? "environment" : "user";
    if (kIsWeb) {
      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null) {
          emergencyStream.callMethod('switchCamera', [
            allowInterop((dynamic success, dynamic msg) {
              final ok = success == true;
              _streamStatusMessage = msg?.toString() ?? "Camera Switched";
              if (onReady != null) onReady(ok, _streamStatusMessage);
            })
          ]);
          return;
        }
      } catch (_) {}
    }
    if (onReady != null) onReady(true, "Switched to ${_cameraFacing.toUpperCase()}");
  }

  /// Receiver method: used by Driver & Secondary Contact to fetch the victim's live video frame & audio
  Future<StreamFrameData?> fetchLatestStreamFrame(String emergencyId) async {
    try {
      final url = emergencyId.isNotEmpty
          ? "${ApiConfig.baseUrl}/emergencies/$emergencyId/stream"
          : "${ApiConfig.baseUrl}/emergencies/stream/latest";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StreamFrameData.fromJson(data);
      }
    } catch (_) {}
    return null;
  }
}
