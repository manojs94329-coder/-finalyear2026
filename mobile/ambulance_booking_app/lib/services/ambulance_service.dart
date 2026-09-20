import 'api_service.dart';

class AmbulanceService {
  final ApiService _apiService = ApiService();

  Future<dynamic> getAvailableAmbulances() => _apiService.get("/ambulances/available");

  Future<dynamic> getAmbulance(int ambulanceId) => _apiService.get("/ambulances/$ambulanceId");

  Future<dynamic> updateLocation({required int ambulanceId, required double latitude, required double longitude}) {
    return _apiService.put("/ambulances/$ambulanceId/location", {"latitude": latitude, "longitude": longitude});
  }

  Future<dynamic> updateStatus(int ambulanceId, String status) {
    return _apiService.put("/ambulances/$ambulanceId/status?status=$status", {});
  }
}
