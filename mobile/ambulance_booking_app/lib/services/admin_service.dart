import 'api_service.dart';

class AdminService {
  final ApiService _apiService = ApiService();

  Future<dynamic> getDashboardMetrics() => _apiService.get("/admin/dashboard");

  Future<dynamic> getAllBookings() => _apiService.get("/admin/bookings");

  Future<dynamic> getAmbulances() => _apiService.get("/admin/ambulances");

  Future<dynamic> getPendingAmbulances() => _apiService.get("/admin/pending-ambulances");

  Future<dynamic> getUsers() => _apiService.get("/admin/users");

  Future<dynamic> approveAmbulance(int ambulanceId) =>
      _apiService.put("/admin/approve-ambulance/$ambulanceId", {});

  Future<dynamic> assignAmbulance(int bookingId, int ambulanceId) =>
      _apiService.put("/admin/assign-ambulance", {
        "bookingId": bookingId,
        "ambulanceId": ambulanceId,
      });

  Future<dynamic> overrideAmbulanceStatus(int ambulanceId, String status) =>
      _apiService.put("/admin/ambulance/$ambulanceId/status", {
        "status": status,
      });
}
