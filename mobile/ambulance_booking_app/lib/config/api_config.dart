import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String cloudTunnelUrl = "https://playlist-lips-meetings-sweet.trycloudflare.com/api";

  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin.startsWith("http")) {
        return "$origin/api";
      }
      return "/api";
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return cloudTunnelUrl;
    }
    return "http://localhost:5000/api";
  }

  static List<String> get fallbackBaseUrls => [
        baseUrl,
        cloudTunnelUrl,
        "http://10.0.2.2:5000/api",
        "http://localhost:5000/api",
      ];
}
