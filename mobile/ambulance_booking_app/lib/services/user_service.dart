import 'api_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  Future<dynamic> getUserProfile(int userId) => _apiService.get("/users/$userId");

  Future<dynamic> updateUserProfile(int userId, Map<String, dynamic> data) =>
      _apiService.put("/users/$userId", data);
}
