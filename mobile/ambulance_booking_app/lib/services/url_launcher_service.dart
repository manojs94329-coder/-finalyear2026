// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';
import 'dart:js' as js;

class UrlLauncherService {
  static void openUrl(String url) {
    if (kIsWeb) {
      try {
        js.context.callMethod('open', [url, '_blank']);
      } catch (e) {
        debugPrint("Error opening URL: $e");
      }
    } else {
      debugPrint("Native URL Open: $url");
    }
  }

  static String getGoogleMapsRouteUrl({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    return "https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving";
  }

  static String getGoogleMapsPointUrl(double lat, double lng) {
    return "https://maps.google.com/?q=$lat,$lng";
  }
}
