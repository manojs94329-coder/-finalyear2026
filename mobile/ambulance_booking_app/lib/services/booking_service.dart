import 'api_service.dart';

class BookingService {
  final ApiService _apiService = ApiService();

  Future<dynamic> requestAmbulance({
    required int userId,
    double? pickupLatitude,
    double? pickupLat,
    double? pickupLongitude,
    double? pickupLng,
    String? destinationHospital,
    required String patientCondition,
    double? estimatedPrice,
    String? equipmentAddons,
    int? hospitalId,
    int? estimatedEtaMinutes,
  }) {
    final lat = pickupLatitude ?? pickupLat ?? 13.0827;
    final lng = pickupLongitude ?? pickupLng ?? 80.2707;

    return _apiService.post("/bookings/request", {
      "userId": userId,
      "pickupLatitude": lat,
      "pickupLongitude": lng,
      "destinationHospital": destinationHospital ?? "Nearest Emergency Trauma Center",
      "patientCondition": patientCondition,
      "estimatedPrice": estimatedPrice ?? 650.00,
      "equipmentAddons": equipmentAddons ?? "Oxygen, Stretcher",
      "hospitalId": hospitalId,
      "estimatedEtaMinutes": estimatedEtaMinutes ?? 8,
    });
  }

  Future<dynamic> getBooking(int bookingId) => _apiService.get("/bookings/$bookingId");

  Future<dynamic> getUserBookings(int userId) => _apiService.get("/bookings/user/$userId");

  Future<dynamic> getDriverActiveBooking(int ambulanceId) =>
      _apiService.get("/bookings/driver/$ambulanceId/active");

  Future<dynamic> getDriverHistory(int ambulanceId) =>
      _apiService.get("/bookings/driver/$ambulanceId/history");

  Future<dynamic> acceptBooking(int bookingId) =>
      _apiService.put("/bookings/$bookingId/accept", {});

  Future<dynamic> updateStatus(int bookingId, String status) =>
      _apiService.put("/bookings/$bookingId/status", {"status": status});

  Future<dynamic> completeBooking(int bookingId) =>
      _apiService.put("/bookings/$bookingId/complete", {});

  Future<dynamic> cancelBooking(int bookingId) =>
      _apiService.put("/bookings/$bookingId/cancel", {});

  Future<dynamic> rejectBooking(int bookingId) =>
      _apiService.put("/bookings/$bookingId/reject", {});
}
