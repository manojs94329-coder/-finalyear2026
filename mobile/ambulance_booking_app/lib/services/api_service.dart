import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}$endpoint"),
      headers: {"Content-Type": "application/json"},
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}$endpoint"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}$endpoint"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}$endpoint"),
      headers: {"Content-Type": "application/json"},
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey("message")) {
        throw Exception(decoded["message"]);
      }
      throw Exception(response.body);
    } catch (_) {
      throw Exception(response.body);
    }
  }
}
