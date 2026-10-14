// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:js' show allowInterop;
import 'package:geolocator/geolocator.dart';

class LiveLocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isSuccess;
  final String? errorMessage;

  LiveLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isSuccess,
    this.errorMessage,
  });
}

class WebGeolocationService {
  static final WebGeolocationService _instance = WebGeolocationService._internal();
  factory WebGeolocationService() => _instance;
  WebGeolocationService._internal();

  /// Fetches live coordinates.
  /// On Web, calls the JavaScript `window.fetchLiveLocation` or `navigator.geolocation.getCurrentPosition`
  /// to prompt the browser permission and acquire coordinates.
  /// On Mobile/Native, calls Geolocator.
  Future<LiveLocationResult> fetchLiveLocation() async {
    if (kIsWeb) {
      final completer = Completer<LiveLocationResult>();

      try {
        final emergencyStream = js.context['EmergencyStream'];
        if (emergencyStream != null && emergencyStream['fetchLiveLocation'] != null) {
          emergencyStream.callMethod('fetchLiveLocation', [
            null, // map instance if standalone JS map, or handled in Dart canvas
            allowInterop((dynamic res) {
              final lat = (res['latitude'] as num?)?.toDouble() ?? 13.0827;
              final lng = (res['longitude'] as num?)?.toDouble() ?? 80.2707;
              final acc = (res['accuracy'] as num?)?.toDouble() ?? 10.0;
              if (!completer.isCompleted) {
                completer.complete(LiveLocationResult(
                  latitude: lat,
                  longitude: lng,
                  accuracy: acc,
                  isSuccess: true,
                ));
              }
            }),
            allowInterop((dynamic err) {
              if (!completer.isCompleted) {
                completer.complete(LiveLocationResult(
                  latitude: 13.0827,
                  longitude: 80.2707,
                  accuracy: 50.0,
                  isSuccess: false,
                  errorMessage: "Location permission denied or timed out.",
                ));
              }
            }),
          ]);
        } else {
          // Fallback to Geolocator
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          return LiveLocationResult(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            isSuccess: true,
          );
        }

        return await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => LiveLocationResult(
            latitude: 13.0827,
            longitude: 80.2707,
            accuracy: 50.0,
            isSuccess: false,
            errorMessage: "Location request timed out.",
          ),
        );
      } catch (e) {
        // Fallback
        try {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          return LiveLocationResult(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            isSuccess: true,
          );
        } catch (_) {
          return LiveLocationResult(
            latitude: 13.0827,
            longitude: 80.2707,
            accuracy: 50.0,
            isSuccess: false,
            errorMessage: e.toString(),
          );
        }
      }
    } else {
      // Mobile platform
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        return LiveLocationResult(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          isSuccess: true,
        );
      } catch (e) {
        return LiveLocationResult(
          latitude: 13.0827,
          longitude: 80.2707,
          accuracy: 50.0,
          isSuccess: false,
          errorMessage: e.toString(),
        );
      }
    }
  }
}
