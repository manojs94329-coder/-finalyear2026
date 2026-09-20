import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<dynamic> login(String phoneOrEmail, String password, String role) {
    return _apiService.post("/auth/login", {
      "phoneOrEmail": phoneOrEmail,
      "password": password,
      "role": role,
    });
  }

  Future<dynamic> registerUser({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    String? bloodGroup,
    String? medicalDetails,
    String? emergencyContact,
  }) {
    return _apiService.post("/auth/register-user", {
      "fullName": fullName,
      "phoneNumber": phoneNumber,
      "email": email,
      "password": password,
      "bloodGroup": bloodGroup ?? "",
      "medicalDetails": medicalDetails ?? "",
      "emergencyContact": emergencyContact ?? "",
    });
  }

  Future<dynamic> registerDriver({
    required String driverName,
    required String driverPhone,
    required String email,
    required String password,
    required String vehicleNumber,
    required String ambulanceType,
    double latitude = 13.0827,
    double longitude = 80.2707,
  }) {
    return _apiService.post("/auth/register-ambulance", {
      "driverName": driverName,
      "driverPhone": driverPhone,
      "email": email,
      "password": password,
      "vehicleNumber": vehicleNumber,
      "ambulanceType": ambulanceType,
      "currentLatitude": latitude,
      "currentLongitude": longitude,
    });
  }

  Future<dynamic> registerAdmin({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _apiService.post("/auth/register-admin", {
      "fullName": fullName,
      "email": email,
      "password": password,
    });
  }
}
