import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin.startsWith("http")) {
        return "$origin/api";
      }
      return "/api";
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:5000/api";
    }
    return "http://localhost:5000/api";
  }
}
